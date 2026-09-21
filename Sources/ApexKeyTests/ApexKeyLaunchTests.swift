import XCTest
@testable import ApexKey

/// P0: LaunchConfig 파싱/인코딩 + ScriptExecutor 빈 입력 가드
final class ApexKeyLaunchTests: XCTestCase {

    func testParseArgsKeepsQuotedGroups() {
        XCTAssertEqual(
            LaunchConfig.parseArgs("--a \"hello world\" --b"),
            ["--a", "hello world", "--b"]
        )
        XCTAssertEqual(LaunchConfig.parseArgs(""), [])
        XCTAssertEqual(LaunchConfig.parseArgs("  --incognito  "), ["--incognito"])
    }

    func testLaunchConfigEncodeDecodeRoundTrip() {
        let config = LaunchConfig(bundleID: "com.apple.Safari", path: "/Applications/Safari.app", mode: .toggle, args: "--incognito", urlScheme: "")
        let decoded = ActionExecutor.decodeLaunchConfig(from: ActionExecutor.encodeLaunchConfig(config))
        XCTAssertEqual(decoded, config)
    }

    func testLegacyTargetFallsBackToBundleID() {
        let step = ShortcutStep(type: .launchApp, target: "com.apple.Safari", title: "Safari")
        XCTAssertEqual(step.effectiveLaunchConfig.bundleID, "com.apple.Safari")
        XCTAssertEqual(step.effectiveLaunchConfig.mode, .toggle)
    }

    func testExecuteLaunchEmptyTargetFails() {
        XCTAssertFalse(ActionExecutor.shared.executeLaunch(target: "   "))
    }

    func testExecuteLaunchBadURLSchemeFails() {
        // 공백 포함 스킴은 URL 파싱 실패 → false
        XCTAssertFalse(ActionExecutor.shared.executeLaunch(target: "not a url://with spaces"))
    }

    func testAppleScriptEmptyFails() {
        let r = ScriptExecutor.runAppleScript("   ")
        XCTAssertFalse(r.success)
    }

    func testJXAEmptyFails() {
        let r = ScriptExecutor.runJXA("")
        XCTAssertFalse(r.success)
    }
}
