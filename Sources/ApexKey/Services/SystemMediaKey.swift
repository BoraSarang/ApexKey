import AppKit
import ApplicationServices
import CoreGraphics

/// 시스템 미디어 키(볼륨 업/다운/음소거) 주입.
///
/// macOS의 볼륨 HUD는 **볼륨 값 변경이 아니라 하드웨어 미디어 키 이벤트**에 반응한다.
/// CoreAudio(`SystemVolume.set`)로 값을 바꾸면 HUD가 뜨지 않는다
/// (2026-11-15 실측: CoreAudio +5% → HUD 없음 / `NX_SYSDEFINED` 주입 → 1/16 스텝 변경 + HUD 표시).
///
/// 비공개 프레임워크 없이 `NSEvent.otherEvent(.systemDefined, subtype: 8)`의 `cgEvent`를
/// `.cghidEventTap`에 post하면 시스템이 볼륨 변경과 HUD를 함께 처리한다.
/// 접근성 권한이 없으면 `CGEvent.post`는 오류 없이 무시되므로 호출 전에 확인한다.
enum SystemMediaKey: Int32, CaseIterable {
    // IOKit `NX_KEYTYPE_*` (hidsystem/ev_keymap.h)
    case soundUp = 0
    case soundDown = 1
    case mute = 7

    /// `NX_SUBTYPE_AUX_CONTROL_BUTTONS`
    static let subtype: Int16 = 8
    static let keyDownState: Int32 = 0x0A
    static let keyUpState: Int32 = 0x0B

    /// `NX_SYSDEFINED`의 `data1` 인코딩 — 상위 16비트 키, 그 아래 8비트 상태.
    static func data1(key: Int32, isDown: Bool) -> Int {
        Int((key << 16) | ((isDown ? keyDownState : keyUpState) << 8))
    }

    /// 키 다운+업을 시스템에 주입. 접근성 권한이 없거나 이벤트 생성에 실패하면 false.
    @discardableResult
    static func post(_ key: SystemMediaKey) -> Bool {
        guard AXIsProcessTrusted() else {
            Logger.info("SystemMediaKey", "접근성 권한 없음 — 미디어 키 주입 생략")
            return false
        }
        guard post(key, isDown: true) else { return false }
        _ = post(key, isDown: false)
        return true
    }

    private static func post(_ key: SystemMediaKey, isDown: Bool) -> Bool {
        guard let event = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            subtype: subtype,
            data1: data1(key: key.rawValue, isDown: isDown),
            data2: -1
        ), let cgEvent = event.cgEvent else {
            Logger.error("E-MAC-SYS-8013", "미디어 키 이벤트 생성 실패: \(key)")
            return false
        }
        cgEvent.post(tap: .cghidEventTap)
        return true
    }
}
