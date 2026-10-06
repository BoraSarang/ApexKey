import XCTest
@testable import ApexKey

/// 메뉴바 아이콘 그리드 UI 테스트 (M-03 UI)
final class MenuBarIconsGridTests: XCTestCase {

    // MARK: - 키보드 이동

    func testHorizontalMovesWithinRow() {
        // 8열, 10개: index 7(첫 행 끝)에서 → 는 마지막 항목으로 클램프되지 않고 행 안에 머문다
        XCTAssertEqual(MenuBarIconsGridView.moveSelection(from: 6, by: (1, 0), columns: 8, count: 10), 7)
        XCTAssertEqual(MenuBarIconsGridView.moveSelection(from: 0, by: (-1, 0), columns: 8, count: 10), 0)
    }

    func testVerticalMovesByRow() {
        XCTAssertEqual(MenuBarIconsGridView.moveSelection(from: 2, by: (0, 1), columns: 8, count: 10), 9)
        XCTAssertEqual(MenuBarIconsGridView.moveSelection(from: 9, by: (0, 1), columns: 8, count: 10), 9)
        XCTAssertEqual(MenuBarIconsGridView.moveSelection(from: 9, by: (0, -1), columns: 8, count: 10), 1)
        XCTAssertEqual(MenuBarIconsGridView.moveSelection(from: 1, by: (0, -1), columns: 8, count: 10), 0)
    }

    func testEmptyGridStaysAtZero() {
        XCTAssertEqual(MenuBarIconsGridView.moveSelection(from: 0, by: (1, 0), columns: 8, count: 0), 0)
    }

    func testSingleColumnMovesLinearly() {
        XCTAssertEqual(MenuBarIconsGridView.moveSelection(from: 0, by: (0, 1), columns: 1, count: 3), 1)
        XCTAssertEqual(MenuBarIconsGridView.moveSelection(from: 2, by: (1, 0), columns: 1, count: 3), 2)
    }

    // MARK: - 시스템 아이콘 기호 매핑

    func testKnownSystemIconsMap() {
        XCTAssertEqual(MenuBarIconEnumerator.systemSymbolName(forDescription: "Wi-Fi, connected, 3 bars"), "wifi")
        XCTAssertEqual(MenuBarIconEnumerator.systemSymbolName(forDescription: "Battery"), "battery.100")
        XCTAssertEqual(MenuBarIconEnumerator.systemSymbolName(forDescription: "Control Center"), "switch.2")
        XCTAssertEqual(MenuBarIconEnumerator.systemSymbolName(forDescription: "Clock"), "clock")
    }

    func testUnknownFallsBackToGrid() {
        XCTAssertEqual(MenuBarIconEnumerator.systemSymbolName(forDescription: "Something Else"), "circle.grid.2x2")
    }

    // MARK: - 클릭 결과 토스트 정책 (M-05와 동일: 실패만)

    func testClickSuccessIsSilent() {
        XCTAssertNil(MenuBarIconEnumerator.ClickResult.success.toastMessage)
    }

    func testClickFailuresHaveMessages() {
        XCTAssertNotNil(MenuBarIconEnumerator.ClickResult.noPermission.toastMessage)
        XCTAssertNotNil(MenuBarIconEnumerator.ClickResult.actionFailed.toastMessage)
    }

    // MARK: - 기본값

    func testDefaultHotkey() {
        // ⌥⌘] — keyCode 30, cmd+option
        let def = ConfigStore.defaultMenuBarIconsHotkey
        XCTAssertEqual(def.keyCode, 30)
        XCTAssertEqual(def.modifiers, KeyboardUtil.cmdMask | KeyboardUtil.optionMask)
        XCTAssertFalse(def.isEmpty)
    }

    func testNewKeysExistInBothLanguages() {
        for key in ["menubar.icons.title", "menubar.icons.count", "menubar.icons.empty",
                    "menubar.icons.no_permission", "menubar.icons.click_no_permission",
                    "menubar.icons.click_failed", "menubar.icons.footer_hint",
                    "menubar.icons.footer_hint_swapped", "settings.menubar_icons.current",
                    "settings.menubar_icons.description", "settings.menubar_icons.change",
                    "settings.menubar_icons.reset", "settings.menubar_icons.per_row",
                    "settings.menubar_icons.swap_clicks", "settings.menubar_icons.swap_clicks.description"] {
            XCTAssertFalse(key.localized.isEmpty, key)
        }
    }
}
