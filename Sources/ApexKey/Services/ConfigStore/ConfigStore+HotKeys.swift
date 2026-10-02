import Foundation
import SwiftData
import AppKit
import Combine

/// ConfigStore 영역 분할 (R-10) — 동일 클래스 extension, public API 동결.
extension ConfigStore {
    /// 핫키 적용 결과 (E-MAC-HTKEY-1003)
    ///
    /// 핫키 저장은 여러 경로에서 **조용히 거부**될 수 있었다. 중복 조합, 빈 조합,
    /// 저장소 사용 불가, Carbon OS 등록 실패. 사용자에게 전달하려면 반환값이 필요하므로
    /// 모든 적용 경로가 이 결과를 돌려준다.
    enum HotKeyApplyResult {
        case applied
        case duplicateCombo
        case invalidCombo
        case appNotFound
        case storeUnavailable
        /// Carbon 핫키 등록 실패 (OS가 이미 다른 앱에 배정했을 수 있음)
        case hotKeyRegistrationFailed

        var succeeded: Bool { self == .applied }

        /// 사용자에게 보여줄 메시지 (nil이면 성공)
        var errorMessage: String? {
            switch self {
            case .applied: return nil
            case .duplicateCombo: return "toast.reason.hotkey_duplicate".localized
            case .invalidCombo: return "toast.reason.key_invalid".localized
            case .appNotFound: return "toast.reason.app_missing".localized
            case .storeUnavailable: return "toast.reason.hotkey_save_failed".localized
            case .hotKeyRegistrationFailed: return "toast.reason.hotkey_register_failed".localized
            }
        }
    }

    /// ⇧⌥A 패널 토글 핫키 변경 (재등록)
    @discardableResult
    func setPanelToggleHotkey(_ combo: HotKeyCombo) -> HotKeyApplyResult {
        guard !combo.isEmpty else { return .invalidCombo }
        if isDuplicate(combo: combo, excluding: panelToggleID) {
            Logger.error("E-MAC-HTKEY-1002", "패널 토글 핫키 중복으로 변경 거부: \(combo.displayString)")
            return .duplicateCombo
        }
        hotKeyService.unregister(panelToggleID)
        toggleHotkey = combo
        Self.saveHotkey(combo, forKey: PrefKeys.panelToggleHotkey)
        guard hotKeyService.register(panelToggleID, combo: combo) else {
            Logger.error("E-MAC-HTKEY-1004", "Carbon 핫키 등록 실패 (OS 선점 가능): \(combo.displayString)")
            return .hotKeyRegistrationFailed
        }
        Logger.info("ConfigStore", "[HOTKEY] 패널 토글 핫키 변경: \(combo.displayString)")
        return .applied
    }

    /// ⌘⌥K 명령 팔레트 핫키 변경 (재등록)
    @discardableResult
    func setPaletteHotkey(_ combo: HotKeyCombo) -> HotKeyApplyResult {
        guard !combo.isEmpty else { return .invalidCombo }
        if isDuplicate(combo: combo, excluding: paletteID) {
            Logger.error("E-MAC-HTKEY-1002", "팔레트 핫키 중복으로 변경 거부: \(combo.displayString)")
            return .duplicateCombo
        }
        hotKeyService.unregister(paletteID)
        paletteHotkey = combo
        Self.saveHotkey(combo, forKey: PrefKeys.paletteHotkey)
        guard hotKeyService.register(paletteID, combo: combo) else {
            Logger.error("E-MAC-HTKEY-1004", "Carbon 핫키 등록 실패 (OS 선점 가능): \(combo.displayString)")
            return .hotKeyRegistrationFailed
        }
        Logger.info("ConfigStore", "[HOTKEY] 명령 팔레트 핫키 변경: \(combo.displayString)")
        return .applied
    }

    /// ⇧⌥S Menu HUD 핫키 변경 (재등록)
    @discardableResult
    func setMenuHUDHotkey(_ combo: HotKeyCombo) -> HotKeyApplyResult {
        guard !combo.isEmpty else { return .invalidCombo }
        if isDuplicate(combo: combo, excluding: menuHUDID) {
            Logger.error("E-MAC-HTKEY-1002", "Menu HUD 핫키 중복으로 변경 거부: \(combo.displayString)")
            return .duplicateCombo
        }
        hotKeyService.unregister(menuHUDID)
        menuHUDHotkey = combo
        Self.saveHotkey(combo, forKey: PrefKeys.menuHUDHotkey)
        guard hotKeyService.register(menuHUDID, combo: combo) else {
            Logger.error("E-MAC-HTKEY-1004", "Carbon 핫키 등록 실패 (OS 선점 가능): \(combo.displayString)")
            return .hotKeyRegistrationFailed
        }
        Logger.info("ConfigStore", "[HOTKEY] Menu HUD 핫키 변경: \(combo.displayString)")
        return .applied
    }

    /// ⌘⇧V 클립보드 팔레트 핫키 변경 (재등록)
    @discardableResult
    func setClipboardHotkey(_ combo: HotKeyCombo) -> HotKeyApplyResult {
        guard !combo.isEmpty else { return .invalidCombo }
        if isDuplicate(combo: combo, excluding: clipboardID) {
            Logger.error("E-MAC-HTKEY-1002", "클립보드 핫키 중복으로 변경 거부: \(combo.displayString)")
            return .duplicateCombo
        }
        hotKeyService.unregister(clipboardID)
        clipboardHotkey = combo
        Self.saveHotkey(combo, forKey: PrefKeys.clipboardHotkey)
        guard hotKeyService.register(clipboardID, combo: combo) else {
            Logger.error("E-MAC-HTKEY-1004", "Carbon 핫키 등록 실패 (OS 선점 가능): \(combo.displayString)")
            return .hotKeyRegistrationFailed
        }
        Logger.info("ConfigStore", "[HOTKEY] 클립보드 핫키 변경: \(combo.displayString)")
        return .applied
    }

    /// ⇧⌥D Instant Send 핫키 변경 (재등록)
    @discardableResult
    func setSendHotkey(_ combo: HotKeyCombo) -> HotKeyApplyResult {
        guard !combo.isEmpty else { return .invalidCombo }
        if isDuplicate(combo: combo, excluding: sendID) {
            Logger.error("E-MAC-HTKEY-1002", "Instant Send 핫키 중복으로 변경 거부: \(combo.displayString)")
            return .duplicateCombo
        }
        hotKeyService.unregister(sendID)
        sendHotkey = combo
        Self.saveHotkey(combo, forKey: PrefKeys.sendHotkey)
        guard hotKeyService.register(sendID, combo: combo) else {
            Logger.error("E-MAC-HTKEY-1004", "Carbon 핫키 등록 실패 (OS 선점 가능): \(combo.displayString)")
            return .hotKeyRegistrationFailed
        }
        Logger.info("ConfigStore", "[HOTKEY] Instant Send 핫키 변경: \(combo.displayString)")
        return .applied
    }

    /// Instant Send 발화 — 선택 캡처(백그라운드) 후 전송 팔레트 표시.
    /// 선택이 없으면 토스트로 안내하고 팔레트를 열지 않는다.
    func fireInstantSend() {
        runOffMainThread(
            { InstantSend.capture() },
            onFinish: { [weak self] payload in
                guard let self else { return }
                guard let payload else {
                    self.notifyToast(title: "palette.send.empty".localized, result: (false, "palette.send.empty_hint".localized))
                    return
                }
                self.sendPayload = payload
                self.paletteMode = .send
                self.showPalette = true
                Logger.info("ConfigStore", "[SEND] 선택 캡처: \(payload.text.count)자 (\(payload.sourceApp))")
            }
        )
    }

    /// 워크플로우 실행 + 외부 입력 주입 (Instant Send 전송용).
    func executeShortcutWithInput(_ shortcut: ShortcutItem, input: VariableValue) {
        runOffMainThread(
            { [actionExecutor] in actionExecutor.executeWithDetail(shortcut, input: input) },
            onFinish: { [weak self] result in
                guard let self else { return }
                if result.success, let idx = self.shortcuts.firstIndex(where: { $0.id == shortcut.id }) {
                    self.shortcuts[idx].lastRunAt = Date()
                    self.shortcuts[idx].runCount += 1
                    self.syncShortcut(self.shortcuts[idx])
                }
                self.notifyToast(title: shortcut.name, result: result)
            }
        )
    }

    func registerAllBindings() {
        // 등록 실패는 조용히 넘어가지 않고 집계 로그 (재부팅 후 타 앱 선점 등).
        // 같은 조합의 공유 항목은 첫 소유자만 Carbon 등록한다.
        var failed = 0
        var seen = Set<String>()
        bindings.forEach {
            let key = HotKeyConflict.comboKey($0.combo)
            guard !seen.contains(key) else { return }
            if !hotKeyService.register($0.id, combo: $0.combo) { failed += 1 } else { seen.insert(key) }
        }
        shortcuts.forEach { shortcut in
            if shortcut.combo.isEmpty { return }
            let key = HotKeyConflict.comboKey(shortcut.combo)
            guard !seen.contains(key) else { return }
            if !hotKeyService.register(shortcut.id, combo: shortcut.combo) {
                failed += 1
            } else {
                seen.insert(key)
            }
        }
        if failed > 0 {
            Logger.error("E-MAC-HTKEY-1001", "핫키 \(failed)건 미등록 (타 앱 선점 가능) — 해당 단축키 재설정 필요")
        }
    }

    /// 소유자 ID로 조합을 찾아 공유 후보를 해결한다.
    /// 1건이면 바로 실행, 여러 건이면 고정(pin)→바로 실행, 없으면 Conflict palette 표시.
    func handleHotKey(_ bindingID: UUID) {
        if let combo = comboForEntry(id: bindingID) {
            let targets = HotKeyConflict.targets(matching: combo, shortcuts: shortcuts, bindings: bindings)
            let resolution = HotKeyConflict.resolve(
                targets: targets,
                preferredID: HotKeyConflict.preferredID(for: combo, defaults: defaults)
            )
            switch resolution {
            case .run(let target):
                runConflictTarget(target)
                return
            case .choose(let list):
                Logger.info("ConfigStore", "[HOTKEY] 공유 단축키 \(list.count)건 — 선택 패널: \(combo.displayString)")
                (NSApp.delegate as? AppDelegate)?.showConflictPanel(combo: combo, targets: list)
                return
            case .none:
                break
            }
        }
        Logger.info("ConfigStore", "[HOTKEY] 미등록 binding 감지: \(bindingID.uuidString)")
    }

    private func comboForEntry(id: UUID) -> HotKeyCombo? {
        if let s = shortcuts.first(where: { $0.id == id }), !s.combo.isEmpty { return s.combo }
        return bindings.first(where: { $0.id == id })?.combo
    }

    /// Conflict 선택지 실행 — 기존 handleHotKey 분기를 그대로 옮겼다.
    func runConflictTarget(_ target: HotKeyConflict.Target) {
        switch target.kind {
        case .shortcut:
            guard let shortcut = target.shortcut,
                  let current = shortcuts.first(where: { $0.id == shortcut.id }) else { return }
            Logger.info("ConfigStore", "[HOTKEY] 동작 실행: \(current.name)")
            lastExecutedBindingID = current.id
            executeShortcutStats(current)
        case .binding:
            guard let stub = target.binding,
                  let binding = bindings.first(where: { $0.id == stub.id }) else { return }
            lastExecutedBindingID = binding.id
            let frontBundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            Logger.info("ConfigStore", "[HOTKEY] 핫키 감지: \(binding.combo.displayString) (\(binding.actionType.displayName))")
            if actionExecutor.shouldExecute(binding, frontmostBundleID: frontBundle) {
                // E-MAC-ACT-3006: 실행은 백그라운드. 스크립트·셸 단축키가 수십 초 걸려도
                // 메뉴바·패널이 멈추지 않는다. 제목은 여기서 확정해 캡처한다 —
                // 바인딩은 값 타입이라 실행 중 배열이 바뀌어도 안전하다.
                let title = toastTitle(for: binding)
                runOffMainThread(
                    { [actionExecutor] in actionExecutor.executeWithDetail(binding) },
                    onFinish: { [weak self] result in
                        self?.notifyToast(title: title, result: result)
                    }
                )
            } else {
                Logger.info("ConfigStore", "[HOTKEY] 실행 조건 미충족: activeApp=\(frontBundle ?? "nil")")
            }
        }
    }

    /// 실행을 백그라운드로 넘기고 결과로 후속 처리를 메인에서 돌린다 (E-MAC-ACT-3006)
    ///
    /// 이전에는 핫키 콜백(메인 스레드)에서 동기 실행해 `wait 60초` 같은 단계 하나면
    /// UI가 60초 정지했다. `Process.waitUntilExit`·`pauseUntilInput`도 같았다.
    ///
    /// 큐는 `ExecutionEngine.executionQueue`(직렬)다. 전역 공유이므로 단계 테스트도
    /// 같은 큐를 쓴다 — `.global`로 돌리면 실행이 겹쳐 사이보그 모드 상태가 뒤섞인다.
    ///
    /// - Parameters:
    ///   - work: **메인 밖에서** 실행할 작업. `ShortcutItem`·`HotKeyBinding`은 값 타입이라
    ///     캡처 시점에 스냅샷이 결정된다 — 실행 중 사용자가 편집해도 이번 실행엔 영향 없다.
    ///   - onFinish: **메인에서** 실행할 후속 처리(통계 갱신·토스트·저장).
    ///     MainActor 상태(`shortcuts`·`bindings`)를 만지므로 반드시 메인이어야 한다.
    func runOffMainThread<T: Sendable>(
        _ work: @escaping @Sendable () -> T,
        onFinish: @escaping @MainActor (T) -> Void
    ) {
        ExecutionEngine.executionQueue.async {
            let result = work()
            DispatchQueue.main.async { onFinish(result) }
        }
    }

    /// 단축어 실행 + 실행 통계 갱신 (성공 시에만) + 결과 토스트
    ///
    /// E-MAC-ACT-3006: 실행은 백그라운드, 통계·토스트는 메인.
    /// 호출부(핫키·팔레트·반복)는 MainActor이라 반환 시점이 사라져 콜백으로 넘어간다.
    func executeShortcutStats(_ shortcut: ShortcutItem) {
        runOffMainThread(
            { [actionExecutor] in actionExecutor.executeWithDetail(shortcut) },
            onFinish: { [weak self] result in
                guard let self else { return }
                if result.success, let idx = self.shortcuts.firstIndex(where: { $0.id == shortcut.id }) {
                    self.shortcuts[idx].lastRunAt = Date()
                    self.shortcuts[idx].runCount += 1
                    self.syncShortcut(self.shortcuts[idx])
                }
                self.notifyToast(title: shortcut.name, result: result)
            }
        )
    }

    /// 실행 결과 토스트 (메인 스레드에서 AppDelegate로 전달)
    private func notifyToast(title: String, result: (success: Bool, message: String?)) {
        let displayTitle = title.isEmpty ? "ui.run".localized : title
        DispatchQueue.main.async {
            (NSApp.delegate as? AppDelegate)?.showToast(
                title: displayTitle,
                message: result.message,
                success: result.success
            )
        }
    }

    private func toastTitle(for binding: HotKeyBinding) -> String {
        if !binding.title.isEmpty { return binding.title }
        // 시스템 바인딩(구 저장분 title="")은 액션명으로 표시
        if binding.actionType == .system,
           let type = SystemActionType(rawValue: binding.target) {
            return type.displayName
        }
        return binding.actionType.displayName
    }

    /// 마지막으로 실행된 바인딩을 반복 실행 (⌘⇧↩)
    func repeatLastBinding() {
        guard let lastID = lastExecutedBindingID else {
            Logger.info("ConfigStore", "[REPEAT] 실행된 바인딩 없음")
            return
        }
        if let shortcut = shortcuts.first(where: { $0.id == lastID }) {
            executeShortcutStats(shortcut)
            Logger.info("ConfigStore", "[REPEAT] 반복 실행: \(shortcut.name)")
            return
        }
        guard let binding = bindings.first(where: { $0.id == lastID }) else {
            Logger.info("ConfigStore", "[REPEAT] 바인딩을 찾을 수 없음: \(lastID.uuidString)")
            return
        }
        let frontBundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if actionExecutor.shouldExecute(binding, frontmostBundleID: frontBundle) {
            // E-MAC-ACT-3006: 반복 실행도 백그라운드로
            let title = toastTitle(for: binding)
            runOffMainThread(
                { [actionExecutor] in actionExecutor.executeWithDetail(binding) },
                onFinish: { [weak self] result in
                    self?.notifyToast(title: title, result: result)
                }
            )
            Logger.info("ConfigStore", "[REPEAT] 반복 실행: \(binding.combo.displayString)")
        } else {
            Logger.info("ConfigStore", "[REPEAT] 반복 실행 조건 미충합")
        }
    }

    /// 명령 팔레트에서 바인딩 실행
    func executeBinding(_ binding: HotKeyBinding) {
        lastExecutedBindingID = binding.id
        let frontBundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if actionExecutor.shouldExecute(binding, frontmostBundleID: frontBundle) {
            // E-MAC-ACT-3006: 팔레트 실행도 백그라운드로.
            // 팔레트는 닫히는 즉시이므로 결과와 무관하게 UI 상태는 바로 갱신된다.
            let title = toastTitle(for: binding)
            runOffMainThread(
                { [actionExecutor] in actionExecutor.executeWithDetail(binding) },
                onFinish: { [weak self] result in
                    self?.notifyToast(title: title, result: result)
                }
            )
            Logger.info("ConfigStore", "[Palette] 실행: \(binding.title)")
        } else {
            Logger.info("ConfigStore", "[Palette] 실행 조건 미충족: activeApp=\(frontBundle ?? "nil")")
        }
        showPalette = false
    }
}
