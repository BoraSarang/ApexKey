import Foundation
import Carbon.HIToolbox
import Combine

/// Carbon RegisterEventHotKey 기반 글로벌 핫키 서비스
///
/// 메인 런루프에 이벤트 핸들러를 1회 설치하고,
/// hotkey signature → binding ID 매핑으로 콜백을 Combine으로 전달한다.
final class HotKeyService {
    private var hotKeyRefs: [UUID: EventHotKeyRef] = [:]
    private var idBySignature: [UInt32: UUID] = [:]
    private var comboByID: [UUID: HotKeyCombo] = [:]
    private var nextSignature: UInt32 = 1
    private var eventHandlerRef: EventHandlerRef?

    static let shared = HotKeyService()

    /// 등록된 단축키가 눌렸을 때 (binding ID 전달)
    let hotKeyPressed = PassthroughSubject<UUID, Never>()

    // Swift 클로저를 C 함수 포인터로 전달하기 위한 저장 프로퍼티 (해제 방지)
    private var callbackProc: EventHandlerUPP?

    private init() {
        installEventHandler()
    }

    private func installEventHandler() {
        var eventSpec = [EventTypeSpec]()
        eventSpec.append(EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                       eventKind: UInt32(kEventHotKeyPressed)))

        let proc: EventHandlerUPP = { _, event, _ -> OSStatus in
            // 전역 뽑기 — HotKeyService.shared 직접 참조
            let service = HotKeyService.shared
            var hotKeyID = EventHotKeyID()
            let size = MemoryLayout.size(ofValue: hotKeyID)
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID), nil,
                                           size, nil, &hotKeyID)
            guard status == noErr else { return status }
            // 등록 시 idBySignature[hotKeyID.signature] = bindingID로 저장하므로 동일 키로 조회
            if let bindingID = service.idBySignature[hotKeyID.signature] {
                service.hotKeyPressed.send(bindingID)
            }
            return noErr
        }
        callbackProc = proc

        let status = InstallEventHandler(GetApplicationEventTarget(), proc,
                                         eventSpec.count, eventSpec, nil, &eventHandlerRef)
        if status != noErr {
            Logger.error("E-MAC-HTSVC-2001", "InstallEventHandler 실패 (status=\(status))")
        }
    }

    /// 단축키 등록 (이미 같은 ID로 등록된 게 있으면 해제 후 재등록)
    @discardableResult
    func register(_ bindingID: UUID, combo: HotKeyCombo) -> Bool {
        guard !combo.isEmpty else { return false }
        unregister(bindingID)

        var hotKeyID = EventHotKeyID(signature: nextSignature, id: UInt32(bindingID.hashValue & 0xFFFF))
        nextSignature &+= 1

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(combo.keyCode,
                                         OptionBits(combo.modifiers),
                                         hotKeyID,
                                         GetApplicationEventTarget(),
                                         0,
                                         &ref)
        guard status == noErr, let ref else {
            Logger.error("E-MAC-HTKEY-1001", "RegisterEventHotKey 실패 (status=\(status), combo=\(combo.displayString))")
            return false
        }

        hotKeyRefs[bindingID] = ref
        idBySignature[hotKeyID.signature] = bindingID
        comboByID[bindingID] = combo
        Logger.info("HotKeyService", "등록: \(combo.displayString)")
        return true
    }

    /// 단축키 해제
    func unregister(_ bindingID: UUID) {
        guard let ref = hotKeyRefs.removeValue(forKey: bindingID) else { return }
        UnregisterEventHotKey(ref)
        if let found = idBySignature.first(where: { $0.value == bindingID }) {
            idBySignature.removeValue(forKey: found.key)
        }
        comboByID.removeValue(forKey: bindingID)
    }

    /// 현재 등록된 모든 콤보 (중복 감지용)
    func registeredCombos(excluding bindingID: UUID) -> [HotKeyCombo] {
        comboByID.filter { $0.key != bindingID }.map { $0.value }
    }

    /// 임시 등록 후 즉시 해제하여 해당 조합이 현재 시스템에서 등록 가능한지 확인
    /// - Returns: 등록 가능하면 true (ApexKey 내부 중복 포함 여부는 호출부의 registeredCombos로 판단)
    func isComboAvailable(_ combo: HotKeyCombo) -> Bool {
        guard !combo.isEmpty else { return false }
        // 일회성 고유 signature — 프로브/실등록 시그니처 충돌·선점 경합 완화 (P1)
        var hotKeyID = EventHotKeyID(signature: nextSignature, id: 0x4170)
        nextSignature &+= 1
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(combo.keyCode,
                                         OptionBits(combo.modifiers),
                                         hotKeyID,
                                         GetApplicationEventTarget(),
                                         0, &ref)
        if status == noErr, let ref {
            UnregisterEventHotKey(ref)
            return true
        }
        Logger.info("HotKeyService", "시스템 등록 불가: \(combo.displayString) (status=\(status))")
        return false
    }

    // MARK: - 테스트 레지스트리 (임시 등록)

    private var testID: UUID?

    /// 테스트용 임시 등록 시작. 성공 시 등록된 testID 반환, 실패 시 nil.
    func beginTest(_ combo: HotKeyCombo) -> UUID? {
        endTest() // 이전 테스트 등록 누수 방지 (P1)
        guard !combo.isEmpty else { return nil }
        let id = UUID()
        guard register(id, combo: combo) else { return nil }
        testID = id
        return id
    }

    /// 테스트 등록 해제
    func endTest() {
        guard let id = testID else { return }
        unregister(id)
        testID = nil
    }

    /// 전부 해제
    func unregisterAll() {
        let allIDs = Array(hotKeyRefs.keys)
        allIDs.forEach { unregister($0) }
    }
}
