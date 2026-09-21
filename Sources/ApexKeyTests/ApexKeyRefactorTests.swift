import XCTest
@testable import ApexKey

/// v0.7 리팩토링·버그수정 회귀 테스트 (G/B 시리즈)
final class ApexKeyRefactorTests: XCTestCase {

    func testShellEnvironmentSingleSource() {
        let extra = ShellEnvironment.extraPaths(home: "/Users/test")
        XCTAssertTrue(extra.contains("/opt/homebrew/bin"))
        XCTAssertTrue(extra.contains("/Users/test/Library/Android/sdk/platform-tools"))
        XCTAssertTrue(ShellEnvironment.pathExport.hasPrefix("export PATH="))
        // pathExport는 실제 홈 기준으로 같은 extraPaths를 재사용해야 함 (단일 출처)
        XCTAssertTrue(ShellEnvironment.pathExport.contains(ShellEnvironment.extraPaths()))
    }

    func testHotKeyComboMatchesIgnoresDisplayString() {
        let a = HotKeyCombo(keyCode: 0, modifiers: 768, displayString: "⇧⌥A")
        let b = HotKeyCombo(keyCode: 0, modifiers: 768, displayString: "다른표시")
        XCTAssertTrue(a.matches(b))
        let c = HotKeyCombo(keyCode: 1, modifiers: 768, displayString: "⇧⌥A")
        XCTAssertFalse(a.matches(c))
    }

    func testRunShortcutInvalidUUIDFails() {
        let engine = ExecutionEngine()
        engine.shortcutProvider = { _ in nil }
        var ctx = UseModelExecutor.ExecutionContext()
        let step = ShortcutStep(type: .runShortcut, target: "not-a-uuid", title: "잘못된호출")
        let shortcut = ShortcutItem(name: "테스트", steps: [step])
        let result = engine.execute(shortcut, context: &ctx)
        XCTAssertFalse(result.success)
    }

    func testRunShortcutMissingTargetFails() {
        let engine = ExecutionEngine()
        engine.shortcutProvider = { _ in nil }
        var ctx = UseModelExecutor.ExecutionContext()
        let step = ShortcutStep(type: .runShortcut, target: UUID().uuidString, title: "없는대상")
        let shortcut = ShortcutItem(name: "테스트", steps: [step])
        let result = engine.execute(shortcut, context: &ctx)
        XCTAssertFalse(result.success)
    }

    func testRunShortcutDepthGuardFails() {
        let engine = ExecutionEngine()
        var ctx = UseModelExecutor.ExecutionContext()
        let shortcut = ShortcutItem(name: "깊이초과", steps: [])
        let result = engine.execute(shortcut, context: &ctx, depth: ExecutionEngine.maxRunShortcutDepth + 1)
        XCTAssertFalse(result.success)
    }

    func testIfMissingBranchFails() {
        let engine = ExecutionEngine()
        var ctx = UseModelExecutor.ExecutionContext()
        let step = ShortcutStep(type: .ifElse, target: "", title: "조건없음")
        let shortcut = ShortcutItem(name: "테스트", steps: [step])
        let result = engine.execute(shortcut, context: &ctx)
        XCTAssertFalse(result.success)
    }

    func testLaunchConfigDecodeFailureReturnsNil() {
        XCTAssertNil(ActionExecutor.decodeLaunchConfig(from: "json:{broken"))
        XCTAssertNil(ActionExecutor.decodeLaunchConfig(from: "com.apple.Safari"))
        let config = LaunchConfig(bundleID: "com.apple.Safari", mode: .toggle)
        let encoded = ActionExecutor.encodeLaunchConfig(config)
        XCTAssertTrue(encoded.hasPrefix("json:"))
        XCTAssertEqual(ActionExecutor.decodeLaunchConfig(from: encoded)?.bundleID, "com.apple.Safari")
    }

    func testExecuteUrlFileInvalidFails() {
        let badURL = HotKeyBinding(combo: .empty, actionType: .url, target: "", title: "빈URL")
        XCTAssertFalse(ActionExecutor.shared.execute(badURL))
        let missing = HotKeyBinding(combo: .empty, actionType: .file, target: "/definitely/not/here-apexkey-xyz", title: "없는파일")
        XCTAssertFalse(ActionExecutor.shared.execute(missing))
    }
}
