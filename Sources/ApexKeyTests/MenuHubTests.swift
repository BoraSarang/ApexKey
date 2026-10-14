import XCTest
import AppKit
@testable import ApexKey

/// Menu Hub 회귀 테스트 (메뉴바 A안)
/// - 우클릭 메뉴 첫 항목은 open-only "메인 창 열기"여야 한다 (토글 금지)
/// - 최신행은 가장 최근 실행 단축키를 골라야 한다
@MainActor
final class MenuHubTests: XCTestCase {

    func testBuildMenuFirstItemIsOpenOnly() {
        let delegate = AppDelegate()
        let menu = delegate.buildMenu()
        let first = menu.items.first
        XCTAssertEqual(first?.action, #selector(AppDelegate.openPanelAction(_:)))
        XCTAssertEqual(first?.keyEquivalent, "o")
        // 키가 풀려야 함 — 원문 키 노출이면 문자열 누락
        XCTAssertEqual(first?.title, "ui.main_window.open".localized)
        XCTAssertNotEqual(first?.title, "ui.main_window.open")
    }

    func testLatestRunPicksMostRecent() {
        let old = ShortcutItem(name: "옛날", lastRunAt: Date(timeIntervalSinceNow: -3600))
        let recent = ShortcutItem(name: "최근", lastRunAt: Date(timeIntervalSinceNow: -60))
        let never = ShortcutItem(name: "미실행")
        XCTAssertEqual(MenuHubView.latestRun(in: [old, never, recent])?.id, recent.id)
    }

    func testLatestRunIsNilWhenNothingRan() {
        XCTAssertNil(MenuHubView.latestRun(in: [ShortcutItem(name: "a")]))
        XCTAssertNil(MenuHubView.latestRun(in: []))
    }

    /// Hub 문자열 키가 모두 풀려야 함 — 원문 키 노출이면 누락.
    /// 키 추가 시 이 목록에도 추가한다.
    func testHubStringsResolve() {
        let keys = [
            "ui.main_window.open",
            "hub.run_tab", "hub.settings_tab",
            "hub.open_palette", "hub.open_palette.sub",
            "hub.repeat_last", "hub.repeat_last.sub",
            "hub.clipboard", "hub.clipboard.sub",
            "hub.menu_hud", "hub.menu_hud.sub",
            "hub.menu_bar_icons", "hub.menu_bar_icons.sub",
            "hub.open_panel", "hub.open_panel.sub",
            "hub.new_shortcut", "hub.new_shortcut.sub",
            "hub.latest.none", "hub.latest.just",
            "hub.open_settings_all", "hub.open_settings_all.sub",
            "hub.toggle.always_on_top", "hub.toggle.launch_at_login",
            "hub.toggle.success_toast", "hub.toggle.menu_bar",
            "hub.toggle.hint",
            "hub.footer.settings", "hub.footer.check_update",
        ]
        for key in keys {
            XCTAssertNotEqual(key.localized, key, "\(key) 미등록 — 원문 키가 노출됨")
        }
        XCTAssertNotEqual(
            "hub.update_available".localizedFormat("v9.9.9"), "hub.update_available",
            "hub.update_available 포맷 키 미등록"
        )
    }
}
