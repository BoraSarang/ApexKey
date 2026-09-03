import XCTest
@testable import ApexKey

/// 모델/유틸리티 단위 테스트 (네트워크·AX 불필요)
final class ApexKeyModelTests: XCTestCase {

    func testHotKeyComboEmpty() {
        XCTAssertTrue(HotKeyCombo.empty.isEmpty)
        let combo = HotKeyCombo(keyCode: 4, modifiers: 0)
        XCTAssertFalse(combo.isEmpty)
    }

    func testActionTypeRawStrings() {
        XCTAssertEqual(ActionType.launchApp.rawValue, "launchApp")
        XCTAssertEqual(ActionType.menuCommand.rawValue, "menuCommand")
    }

    func testMenuItemKeyEquivalentDisplay() {
        // AX Carbon flags: Cmd = 1<<8 (cmdKey)
        let item = MenuItem(title: "새 창", commandChar: "n", commandModifiers: KeyboardUtil.cmdMask)
        XCTAssertTrue(item.hasKeyEquivalent)
        XCTAssertTrue(item.keyEquivalentDisplay.contains("⌘"))
        XCTAssertTrue(item.keyEquivalentDisplay.contains("N"))
    }

    func testMenuTitleFallbackParsing() {
        // AX가 cmdChar를 안 주는 경우 title "열기 ⌘O"에서 fallback 파싱
        let (char, mods) = MenuEnumerator.parseKeyEquivalent(in: "열기 ⌘O")
        XCTAssertEqual(char, "O")
        XCTAssertNotEqual(mods & KeyboardUtil.cmdMask, 0)
    }

    func testMenuItemSeparator() {
        let sep = MenuItem(title: "─", isSeparator: true)
        XCTAssertTrue(sep.isSeparator)
        XCTAssertFalse(sep.hasKeyEquivalent)
    }

    func testAppCategoryDisplayName() {
        XCTAssertEqual(AppCategory.browser.displayName, "브라우저")
        XCTAssertEqual(AppCategory.developer.displayName, "개발")
    }

    func testKeyboardUtilDisplayString() {
        // Cmd(1<<8) + Shift(1<<9) + H(4) = "⌘⇧H"
        let display = KeyboardUtil.displayString(keyCode: 4, modifiers: 1 << 8 | 1 << 9)
        XCTAssertTrue(display.contains("⌘"))
        XCTAssertTrue(display.contains("⇧"))
        XCTAssertTrue(display.hasSuffix("H"))
    }

    func testRegisteredCombosExcludesSelf() {
        let service = HotKeyService.shared
        _ = service.register(UUID(), combo: HotKeyCombo(keyCode: 4, modifiers: 1 << 8, displayString: "⌘H"))
        let excluding = UUID()
        let combos = service.registeredCombos(excluding: excluding)
        XCTAssertTrue(combos.contains { $0.keyCode == 4 && $0.modifiers == (1 << 8) })
    }
}
