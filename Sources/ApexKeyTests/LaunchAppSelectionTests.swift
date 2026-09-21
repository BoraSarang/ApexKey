import XCTest
@testable import ApexKey

/// 앱 선택 반영 로직 (LaunchAppSelection) — 클릭 → 번들ID/경로 반영 보장
final class LaunchAppSelectionTests: XCTestCase {

    private func app(name: String = "Finder", bundleID: String = "com.apple.finder", path: String = "/System/Library/CoreServices/Finder.app") -> AppItem {
        AppItem(name: name, bundleID: bundleID, path: path)
    }

    func testSelectingFillsBundleIDAndPath() {
        let config = LaunchAppSelection.selecting(app(), in: LaunchConfig())
        XCTAssertEqual(config.bundleID, "com.apple.finder")
        XCTAssertEqual(config.path, "/System/Library/CoreServices/Finder.app")
    }

    func testSelectingKeepsModeArgsScheme() {
        let base = LaunchConfig(bundleID: "old", path: "/old", mode: .activate, args: "--a", urlScheme: "foo://x")
        let next = LaunchAppSelection.selecting(app(), in: base)
        XCTAssertEqual(next.mode, .activate)
        XCTAssertEqual(next.args, "--a")
        XCTAssertEqual(next.urlScheme, "foo://x")
        XCTAssertEqual(next.bundleID, "com.apple.finder")
    }

    func testApplySyncsStepAndLegacyTarget() {
        var step = ShortcutStep(type: .launchApp, target: "", title: "")
        let config = LaunchAppSelection.selecting(app(), in: LaunchConfig(mode: .toggle))
        LaunchAppSelection.apply(config, to: &step)
        XCTAssertEqual(step.launchConfig, config)
        XCTAssertEqual(step.target, "com.apple.finder")
        // 실행 설정 판독이 선택값을 그대로 돌려줌 (클릭 미반영 회귀 방지)
        XCTAssertEqual(step.effectiveLaunchConfig.bundleID, "com.apple.finder")
        XCTAssertEqual(step.effectiveLaunchConfig.path, "/System/Library/CoreServices/Finder.app")
    }

    func testReselectOverwritesPreviousApp() {
        // DeepL 선택 후 Finder 재선택 → 잔재 없이 교체 (스크린샷 회귀 케이스)
        var step = ShortcutStep(type: .launchApp, target: "", title: "")
        let deepL = AppItem(name: "DeepL", bundleID: "com.linguee.DeepLCopyTranslator", path: "/Applications/DeepL.app")
        LaunchAppSelection.apply(LaunchAppSelection.selecting(deepL, in: LaunchConfig()), to: &step)
        LaunchAppSelection.apply(LaunchAppSelection.selecting(app(), in: step.launchConfig!), to: &step)
        XCTAssertEqual(step.target, "com.apple.finder")
        XCTAssertEqual(step.effectiveLaunchConfig.path, "/System/Library/CoreServices/Finder.app")
    }
}
