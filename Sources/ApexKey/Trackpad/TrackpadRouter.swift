import AppKit

/// 제스처 → 실제 실행. **새 실행 엔진을 만들지 않고** 기존 자산을 그대로 호출한다.
///
/// | 대상 | 재사용 |
/// |---|---|
/// | 워크플로우 | `ActionExecutor.executeWithDetail(ShortcutItem)` |
/// | 단축키 | `ActionExecutor.executeWithDetail(HotKeyBinding)` |
/// | 메뉴 항목 | `MenuEnumerator.performAction` (AXUIElement) |
/// | 시스템 액션 | `SystemActionExecutor.execute` |
@MainActor
enum TrackpadRouter {

    /// 규칙 실행. 실패하면 사유 문자열을 돌려준다(성공 시 nil).
    @discardableResult
    static func execute(_ rule: GestureRule, store: ConfigStore) -> String? {
        // 특정 앱 범위 — 앞에 있는 앱이 목록에 없으면 조용히 넘긴다
        if rule.scope == .apps {
            let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            guard let front, rule.appBundleIDs.contains(front) else { return nil }
        }

        switch rule.action.kind {
        case .workflow:
            guard let id = rule.action.shortcutID,
                  let shortcut = store.shortcuts.first(where: { $0.id == id }) else {
                return "trackpad.error.workflow_missing".localized
            }
            let result = ActionExecutor.shared.executeWithDetail(shortcut)
            return result.success ? nil : (result.message ?? "trackpad.error.execute_failed".localized)

        case .hotkey:
            guard let id = rule.action.bindingID,
                  let binding = store.bindings.first(where: { $0.id == id }) else {
                return "trackpad.error.hotkey_missing".localized
            }
            let result = ActionExecutor.shared.executeWithDetail(binding)
            return result.success ? nil : (result.message ?? "trackpad.error.execute_failed".localized)

        case .menu:
            guard let bundleID = rule.action.menuBundleID,
                  let title = rule.action.menuTitle, !title.isEmpty else {
                return "trackpad.error.menu_missing".localized
            }
            let item = MenuItem(title: title, menuPath: rule.action.menuPath)
            // 메뉴 실행은 대상 앱 활성화 + 0.15초 대기 + AppleScript 왕복이라
            // 메인 스레드에서 돌리면 UI가 눈에 띄게 멈춘다 → 백그라운드로 보낸다.
            DispatchQueue.global(qos: .userInitiated).async {
                let result = MenuEnumerator.shared.performAction(item, in: bundleID)
                guard !result.isSuccess else { return }
                DispatchQueue.main.async {
                    reportFailure(title: title, message: result.description)
                }
            }
            return nil

        case .system:
            guard let type = rule.action.systemAction else {
                return "trackpad.error.system_missing".localized
            }
            return SystemActionExecutor.execute(type, parameter: rule.action.systemText)
                ? nil : "trackpad.error.execute_failed".localized
        }
    }

    /// 실패 토스트 — 조용히 죽지 않게 사유를 보여준다.
    static func reportFailure(title: String, message: String?) {
        (NSApp.delegate as? AppDelegate)?.showToast(
            title: title,
            message: message,
            success: false
        )
    }
}
