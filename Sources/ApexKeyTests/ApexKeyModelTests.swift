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
        XCTAssertEqual(AppCategory.utilities.displayName, "유틸리티")
        XCTAssertEqual(AppCategory.productivity.displayName, "생산성")
        XCTAssertEqual(AppCategory.photoVideo.displayName, "사진 및 비디오")
        XCTAssertEqual(AppCategory.socialNetworking.displayName, "소셜 네트워킹")
    }

    func testAppCategoryMigration() {
        // 기존 6개 카테고리 → 신규 표준 체계 자동 이관
        XCTAssertEqual(AppCategory.migrate("browser"), .utilities)
        XCTAssertEqual(AppCategory.migrate("developer"), .uncategorized)
        XCTAssertEqual(AppCategory.migrate("communication"), .socialNetworking)
        XCTAssertEqual(AppCategory.migrate("media"), .photoVideo)
        XCTAssertEqual(AppCategory.migrate("productivity"), .productivity)
        XCTAssertEqual(AppCategory.migrate("uncategorized"), .uncategorized)
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

    // MARK: - 동작(단축어)

    func testShortcutStepToBinding() {
        let step = ShortcutStep(type: .wait, target: "2.0", title: "대기 2초")
        let binding = step.toBinding()
        XCTAssertEqual(binding.actionType, .wait)
        XCTAssertEqual(binding.target, "2.0")
        XCTAssertTrue(binding.combo.isEmpty)
    }

    func testShortcutStepSummary() {
        XCTAssertEqual(ShortcutStep(type: .paste, target: "clipboard").summary, "클립보드")
        XCTAssertEqual(ShortcutStep(type: .paste, target: "안녕").summary, "안녕")
        XCTAssertEqual(ShortcutStep(type: .wait, target: "3").summary, "3초")
        XCTAssertEqual(ShortcutStep(type: .macro, target: "36,36").summary, "2키")
        XCTAssertEqual(
            ShortcutStep(type: .system, target: SystemActionType.mute.rawValue).summary,
            "음소거 토글"
        )
    }

    func testShortcutStepsCodableRoundTrip() {
        let steps = [
            ShortcutStep(type: .launchApp, target: "com.apple.Safari", title: "Safari"),
            ShortcutStep(type: .wait, target: "1.0", title: "대기"),
            ShortcutStep(type: .system, target: SystemActionType.mute.rawValue, title: "음소거"),
        ]
        let data = try! JSONEncoder().encode(steps)
        let decoded = try! JSONDecoder().decode([ShortcutStep].self, from: data)
        XCTAssertEqual(decoded.count, 3)
        XCTAssertEqual(decoded[0].type, .launchApp)
        XCTAssertEqual(decoded[0].target, "com.apple.Safari")
        XCTAssertEqual(decoded[2].type, .system)
        XCTAssertEqual(decoded[2].target, SystemActionType.mute.rawValue)
    }
}
