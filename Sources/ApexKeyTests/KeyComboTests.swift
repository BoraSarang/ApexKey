import XCTest
@testable import ApexKey

/// keyCombo 액션 (키 조합 보내기) 단위 테스트 — 실제 키 전송은 하지 않음
final class KeyComboTests: XCTestCase {

    func testParseValidTarget() {
        // ⌥⌘L = keyCode 37, modifiers option(2048)+cmd(256) = 2304
        let combo = ActionExecutor.parseKeyPress(from: "37:2304")
        XCTAssertNotNil(combo)
        XCTAssertEqual(combo?.keyCode, 37)
        XCTAssertEqual(combo?.modifiers, 2304)
        XCTAssertEqual(combo?.displayString, "⌘⌥L")
    }

    func testParseInvalidTargetReturnsNil() {
        XCTAssertNil(ActionExecutor.parseKeyPress(from: ""))
        XCTAssertNil(ActionExecutor.parseKeyPress(from: "abc"))
        XCTAssertNil(ActionExecutor.parseKeyPress(from: "37"))
        XCTAssertNil(ActionExecutor.parseKeyPress(from: "37:2304:extra"))
    }

    func testParseEmptyComboReturnsNil() {
        XCTAssertNil(ActionExecutor.parseKeyPress(from: "0:0"))
    }

    func testEncodeDecodeRoundTrip() {
        let combo = HotKeyCombo(keyCode: 37, modifiers: 2304, displayString: "⌥⌘L")
        let decoded = ActionExecutor.parseKeyPress(from: ActionExecutor.encodeKeyPress(combo))
        XCTAssertEqual(decoded?.keyCode, combo.keyCode)
        XCTAssertEqual(decoded?.modifiers, combo.modifiers)
    }

    func testSendEmptyComboFailsWithoutSideEffect() {
        XCTAssertFalse(ActionExecutor.sendKeyPress(.empty))
    }

    func testExecuteKeyComboInvalidTargetFails() {
        // 잘못된 형식의 binding 실행 → false (키 전송 없음)
        XCTAssertFalse(ActionExecutor.shared.execute(
            HotKeyBinding(combo: .empty, actionType: .keyCombo, target: "oops", title: "")
        ))
    }

    func testSummaryShowsDisplayString() {
        var step = ShortcutStep(type: .keyCombo, target: "", title: "")
        step.keyPress = HotKeyCombo(keyCode: 37, modifiers: 2304, displayString: "⌥⌘L")
        XCTAssertEqual(step.summary, "⌥⌘L")
    }
}
