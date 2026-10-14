import XCTest
import ApplicationServices
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

    // MARK: - 시스템 아이콘 표시 설정 (기본 제외)

    func testSystemFilterExcludesByDefault() {let sys = MenuBarIconEnumerator.IconItem(
            title: "Wi-Fi", bundleID: MenuBarIconEnumerator.menuBarAgentBundleID,
            pid: 0, element: AXUIElementCreateSystemWide(), positionX: 1, hasShowMenu: true)
        let app = MenuBarIconEnumerator.IconItem(
            title: "Foo", bundleID: "com.example.foo",
            pid: 0, element: AXUIElementCreateSystemWide(), positionX: 2, hasShowMenu: false)
        XCTAssertEqual(
            MenuBarIconEnumerator.visibleIcons([sys, app], includeSystem: false).map(\.title), ["Foo"])
        XCTAssertEqual(
            MenuBarIconEnumerator.visibleIcons([sys, app], includeSystem: true).count, 2)
    }

    // MARK: - 시스템 판정 (Apple 소유 프로세스)

    private func makeItem(title: String, bundleID: String?) -> MenuBarIconEnumerator.IconItem {
        MenuBarIconEnumerator.IconItem(
            title: title, bundleID: bundleID, pid: 0,
            element: AXUIElementCreateSystemWide(), positionX: nil, hasShowMenu: false)
    }

    func testAppleOwnedProcessesAreSystemIcons() {
        // 설정 "Menu Bar Controls" ≒ Apple 소유 — TextInputMenuAgent 대표 케이스
        XCTAssertTrue(makeItem(title: "Wi-Fi", bundleID: "com.apple.MenuBarAgent").isSystemIcon)
        XCTAssertTrue(makeItem(title: "TextInputMenuAgent", bundleID: "com.apple.TextInputMenuAgent").isSystemIcon)
        XCTAssertTrue(makeItem(title: "Siri", bundleID: "com.apple.Siri").isSystemIcon)
    }

    func testThirdPartyAndNilStayNonSystem() {
        XCTAssertFalse(makeItem(title: "Foo", bundleID: "com.example.foo").isSystemIcon)
        XCTAssertFalse(makeItem(title: "ApexKey", bundleID: "com.borasarang.ApexKey").isSystemIcon)
        XCTAssertFalse(makeItem(title: "Unknown", bundleID: nil).isSystemIcon)
    }

    func testTextInputMapsToKeyboardSymbol() {
        XCTAssertEqual(
            MenuBarIconEnumerator.systemSymbolName(forDescription: "TextInputMenuAgent"), "keyboard")
    }

    @MainActor
    func testSystemIconsPrefDefaultsOffAndPersists() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ApexKeyIconsPrefTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let suiteName = "ApexKeyIconsPrefTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            HotKeyService.shared.unregisterAll()
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: dir)
        }
        let store = ConfigStore(storeDirectory: dir, defaults: defaults,
                                seedInstalledApps: false, registerSystemIntegrations: false)
        XCTAssertFalse(store.showSystemMenuBarIcons)
        store.showSystemMenuBarIcons = true
        let reloaded = ConfigStore(storeDirectory: dir, defaults: defaults,
                                   seedInstalledApps: false, registerSystemIntegrations: false)
        XCTAssertTrue(reloaded.showSystemMenuBarIcons)
    }

    // MARK: - 기본값

    func testDefaultHotkey() {
        // ⌥] — keyCode 30, option
        let def = ConfigStore.defaultMenuBarIconsHotkey
        XCTAssertEqual(def.keyCode, 30)
        XCTAssertEqual(def.modifiers, KeyboardUtil.optionMask)
        XCTAssertEqual(def.displayString, "⌥]")
        XCTAssertFalse(def.isEmpty)
    }

    func testDefaultHotkeysMatchUserBaseline() {
        // 새로 설치해도 사용자 단축키 그대로 — 공장 기본값 회귀 금지
        let expected: [(HotKeyCombo, UInt32, String)] = [
            (ConfigStore.defaultToggleHotkey, 0, "⌥A"),
            (ConfigStore.defaultPaletteHotkey, 39, "⌥'"),
            (ConfigStore.defaultClipboardHotkey, 41, "⌥;"),
            (ConfigStore.defaultMenuHUDHotkey, 1, "⌥S"),
            (ConfigStore.defaultMenuBarIconsHotkey, 30, "⌥]"),
        ]
        for (combo, keyCode, display) in expected {
            XCTAssertEqual(combo.keyCode, keyCode, display)
            XCTAssertEqual(combo.modifiers, KeyboardUtil.optionMask, display)
            XCTAssertEqual(combo.displayString, display)
            XCTAssertFalse(combo.isEmpty, display)
        }
    }

    // MARK: - 셀 맞춤 (긴 이름 겹침 회귀)

    func testIconSizeShrinksForManyColumns() {
        // 8열까지 32pt, 9열부터 20pt — 좁은 셀에서 아이콘이 셀을 넘지 않게
        XCTAssertEqual(MenuBarIconsGridView.iconSize(columns: 1), 32)
        XCTAssertEqual(MenuBarIconsGridView.iconSize(columns: 8), 32)
        XCTAssertEqual(MenuBarIconsGridView.iconSize(columns: 9), 20)
        XCTAssertEqual(MenuBarIconsGridView.iconSize(columns: 16), 20)
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
