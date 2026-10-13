import XCTest
@testable import ApexKey

/// 키캡 토큰·검색 정규화 테스트 (E-MAC-UX keycap)
final class KeycapStyleTests: XCTestCase {
    func testModifierTokensOrder() {
        let mods = KeyboardUtil.cmdMask | KeyboardUtil.shiftMask | KeyboardUtil.optionMask | KeyboardUtil.controlMask
        let tokens = KeyboardUtil.modifierTokens(mods)
        XCTAssertEqual(tokens.map { $0.symbol }, ["⌘", "⇧", "⌥", "⌃"])
        XCTAssertEqual(tokens.map { $0.upper }, ["CMD", "SHIFT", "OPT", "CTRL"])
        XCTAssertEqual(tokens.map { $0.lower }, ["cmd", "shift", "opt", "ctrl"])
    }

    func testModifierTokensEmpty() {
        XCTAssertTrue(KeyboardUtil.modifierTokens(0).isEmpty)
    }

    func testKeyTokenLetter() {
        let key = KeyboardUtil.keyToken(45) // N
        XCTAssertEqual(key.symbol, "N")
        XCTAssertEqual(key.upper, "N")
        XCTAssertEqual(key.lower, "n")
    }

    func testKeyTokenSpecial() {
        let key = KeyboardUtil.keyToken(36) // ⏎
        XCTAssertEqual(key.symbol, "⏎")
    }

    func testNormalizedSearchMatchesCmdText() {
        let text = KeyboardUtil.normalizedSearchText(keyCode: 45, modifiers: KeyboardUtil.cmdMask | KeyboardUtil.shiftMask)
        XCTAssertTrue(text.contains("cmd"))
        XCTAssertTrue(text.contains("shift"))
        XCTAssertTrue(text.contains("⌘"))
    }

    func testMenuItemTokens() {
        let item = MenuItem(title: "새 창", commandChar: "n", commandModifiers: KeyboardUtil.cmdMask)
        XCTAssertTrue(item.hasKeyEquivalent)
        XCTAssertEqual(item.keycapModifiers.map { $0.symbol }, ["⌘"])
        XCTAssertEqual(item.keycapKey.symbol, "N")
        XCTAssertTrue(item.normalizedSearchText.contains("cmd"))
        XCTAssertTrue(item.normalizedSearchText.contains("n"))
    }

    func testMenuItemNoShortcutSearchEmpty() {
        let item = MenuItem(title: "분리선", isSeparator: true)
        XCTAssertFalse(item.hasKeyEquivalent)
        XCTAssertEqual(item.normalizedSearchText, "")
    }

    func testKeycapStyleRawValuesStable() {
        // UserDefaults 영속용 rawValue 변경 금지
        XCTAssertEqual(KeycapStyle.symbol.rawValue, "symbol")
        XCTAssertEqual(KeycapStyle.symbolUpper.rawValue, "symbolUpper")
        XCTAssertEqual(KeycapStyle.inline.rawValue, "inline")
        XCTAssertEqual(KeycapStyle.allCases.count, 6)
    }

    func testDisplayStringUnchanged() {
        // 기존 joined 방식 유지 — 로그·폴백 회귀 방지
        let s = KeyboardUtil.displayString(keyCode: 45, modifiers: KeyboardUtil.cmdMask | KeyboardUtil.shiftMask)
        XCTAssertEqual(s, "⌘⇧N")
    }

    func testKeycapPrefKey() {
        XCTAssertEqual(ConfigStore.PrefKeys.keycapStyle, "pref.keycapStyle")
    }
}
