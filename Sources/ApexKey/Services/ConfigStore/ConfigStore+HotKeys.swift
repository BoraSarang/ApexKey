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

    func registerAllBindings() {
        // 등록 실패는 조용히 넘어가지 않고 집계 로그 (재부팅 후 타 앱 선점 등)
        var failed = 0
        bindings.forEach {
            if !hotKeyService.register($0.id, combo: $0.combo) { failed += 1 }
        }
        shortcuts.forEach { shortcut in
            if !shortcut.combo.isEmpty,
               !hotKeyService.register(shortcut.id, combo: shortcut.combo) {
                failed += 1
            }
        }
        if failed > 0 {
            Logger.error("E-MAC-HTKEY-1001", "핫키 \(failed)건 미등록 (타 앱 선점 가능) — 해당 단축키 재설정 필요")
        }
    }

    func handleHotKey(_ bindingID: UUID) {
        // 동작(단축어) 실행 단축키 먼저 확인
        if let shortcut = shortcuts.first(where: { $0.id == bindingID }) {
            Logger.info("ConfigStore", "[HOTKEY] 동작 실행: \(shortcut.name)")
            lastExecutedBindingID = bindingID
            executeShortcutStats(shortcut)
            return
        }
        guard let binding = bindings.first(where: { $0.id == bindingID }) else {
            Logger.info("ConfigStore", "[HOTKEY] 미등록 binding 감지: \(bindingID.uuidString)")
            return
        }
        lastExecutedBindingID = bindingID
        let frontBundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        Logger.info("ConfigStore", "[HOTKEY] 핫키 감지: \(binding.combo.displayString) (\(binding.actionType.displayName))")
        if actionExecutor.shouldExecute(binding, frontmostBundleID: frontBundle) {
            let result = actionExecutor.executeWithDetail(binding)
            notifyToast(title: toastTitle(for: binding), result: result)
        } else {
            Logger.info("ConfigStore", "[HOTKEY] 실행 조건 미충족: activeApp=\(frontBundle ?? "nil")")
        }
    }

    /// 단축어 실행 + 실행 통계 갱신 (성공 시에만) + 결과 토스트
    /// () -> Void 형태로 호출 시점을 지정
    func executeShortcutStats(_ shortcut: ShortcutItem) {
        let result = actionExecutor.executeWithDetail(shortcut)
        if result.success, let idx = shortcuts.firstIndex(where: { $0.id == shortcut.id }) {
            shortcuts[idx].lastRunAt = Date()
            shortcuts[idx].runCount += 1
            syncShortcut(shortcuts[idx])
        }
        notifyToast(title: shortcut.name, result: result)
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
            let result = actionExecutor.executeWithDetail(binding)
            notifyToast(title: toastTitle(for: binding), result: result)
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
            let result = actionExecutor.executeWithDetail(binding)
            notifyToast(title: toastTitle(for: binding), result: result)
            Logger.info("ConfigStore", "[Palette] 실행: \(binding.title) (success=\(result.success))")
        } else {
            Logger.info("ConfigStore", "[Palette] 실행 조건 미충족: activeApp=\(frontBundle ?? "nil")")
        }
        showPalette = false
    }
}
