import Foundation
import SwiftData
import AppKit
import Combine

/// ConfigStore 영역 분할 (R-10) — 동일 클래스 extension, public API 동결.
extension ConfigStore {
    /// ⇧⌥A 패널 토글 핫키 변경 (재등록)
    func setPanelToggleHotkey(_ combo: HotKeyCombo) {
        guard !combo.isEmpty else { return }
        toggleHotkey = combo
        _ = hotKeyService.register(panelToggleID, combo: combo)
        Logger.info("ConfigStore", "[HOTKEY] 패널 토글 핫키 변경: \(combo.displayString)")
    }

    /// ⌘⌥K 명령 팔레트 핫키 변경 (재등록)
    func setPaletteHotkey(_ combo: HotKeyCombo) {
        guard !combo.isEmpty else { return }
        paletteHotkey = combo
        _ = hotKeyService.register(paletteID, combo: combo)
        Logger.info("ConfigStore", "[HOTKEY] 명령 팔레트 핫키 변경: \(combo.displayString)")
    }

    /// ⇧⌥S Menu HUD 핫키 변경 (재등록)
    func setMenuHUDHotkey(_ combo: HotKeyCombo) {
        guard !combo.isEmpty else { return }
        menuHUDHotkey = combo
        _ = hotKeyService.register(menuHUDID, combo: combo)
        Logger.info("ConfigStore", "[HOTKEY] Menu HUD 핫키 변경: \(combo.displayString)")
    }

    func registerAllBindings() {
        bindings.forEach { _ = hotKeyService.register($0.id, combo: $0.combo) }
        shortcuts.forEach { shortcut in
            if !shortcut.combo.isEmpty {
                _ = hotKeyService.register(shortcut.id, combo: shortcut.combo)
            }
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
        let frontBundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if actionExecutor.shouldExecute(binding, frontmostBundleID: frontBundle) {
            actionExecutor.execute(binding)
            Logger.info("ConfigStore", "[Palette] 실행: \(binding.title)")
        }
        showPalette = false
    }
}
