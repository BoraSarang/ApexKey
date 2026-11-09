import Foundation
import XCTest
@testable import ApexKey

/// T-222 App Intents·자동화 카탈로그 검증.
///
/// 실제 Shortcuts 실행·앱 열기·설치 앱 스캔을 하지 않는다.
/// 실행기·URL 열기·앱/단축어 목록을 주입해 인자와 실패 사유를 검사한다.
final class AutomationCatalogTests: XCTestCase {

    private func result(
        exitCode: Int32 = 0,
        output: String = "",
        error: String = "",
        timedOut: Bool = false
    ) -> ProcessRunner.Result {
        ProcessRunner.Result(
            exitCode: exitCode,
            standardOutput: output,
            standardError: error,
            timedOut: timedOut
        )
    }

    private func app(_ name: String, _ bundleID: String, path: String? = nil) -> AppItem {
        AppItem(name: name, bundleID: bundleID, path: path ?? "/Applications/\(name).app")
    }

    private func shortcut(_ name: String, triggers: [AutomationTrigger]) -> ShortcutItem {
        ShortcutItem(name: name, automations: triggers)
    }

    private var timeTrigger: AutomationTrigger {
        .timeOfDay(TimeOfDayTrigger(time: DateComponents(hour: 9, minute: 0)))
    }

    private var focusTrigger: AutomationTrigger {
        .focus(FocusTrigger(focusName: "업무"))
    }

    // MARK: - 설정

    func testConfigDefaults() {
        let config = AppIntentAutomationConfig()
        XCTAssertTrue(config.resolvedIncludeSystemApps)
        XCTAssertTrue(config.resolvedIncludeUnsupported)
        XCTAssertNil(config.query)
    }

    func testConfigTolerantDecoding() {
        let data = Data(#"{"query":"safari","includeSystemApps":false,"unknown":1}"#.utf8)
        let config = AppIntentAutomationConfig.decode(from: data)
        XCTAssertEqual(config.query, "safari")
        XCTAssertFalse(config.resolvedIncludeSystemApps)
        XCTAssertNil(config.shortcutName)
    }

    // MARK: - 앱 찾기

    func testFindAppsRequiresQueryAndMatchesBothFields() {
        let apps = [app("Safari", "com.apple.Safari"), app("Notes", "com.apple.Notes")]

        XCTAssertEqual(
            AutomationCatalog.findApps(query: "  ", apps: apps),
            .failure(.emptyQuery)
        )
        XCTAssertEqual(
            AutomationCatalog.findApps(query: "safari", apps: apps),
            .success(["Safari — com.apple.Safari"])
        )
        XCTAssertEqual(
            AutomationCatalog.findApps(query: "com.apple.notes", apps: apps),
            .success(["Notes — com.apple.Notes"])
        )
        XCTAssertEqual(
            AutomationCatalog.findApps(query: "없는앱", apps: apps),
            .failure(.noMatches("없는앱"))
        )
    }

    func testFindAppsSortsAndLimits() {
        let apps = [
            app("Zeta", "z.app"),
            app("Alpha", "a.app"),
            app("Beta", "b.app"),
        ]
        let outcome = AutomationCatalog.findApps(query: ".app", apps: apps, limit: 2)
        guard case .success(let lines) = outcome else { return XCTFail("결과가 있어야 함") }
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[0].hasPrefix("Alpha"))
        XCTAssertTrue(lines[1].hasPrefix("Beta"))
    }

    // MARK: - App Intents (Shortcuts)

    func testRunShortcutRequiresName() {
        XCTAssertEqual(
            AutomationCatalog.runShortcut(named: "  ") { _, _ in
                XCTFail("이름이 비면 실행하지 않는다")
                return self.result()
            },
            .failure(.emptyShortcutName)
        )
    }

    func testRunShortcutRejectsMissingShortcutBeforeRunning() {
        var ran = false
        let outcome = AutomationCatalog.runShortcut(named: "집중") { _, args in
            if args.first == "list" { return self.result(output: "다른 단축어\n") }
            ran = true
            return self.result()
        }
        XCTAssertEqual(outcome, .failure(.shortcutMissing("집중")))
        XCTAssertFalse(ran, "목록에 없으면 실행하지 않는다")
    }

    func testRunShortcutPassesArguments() {
        var runArguments: [String]?
        let outcome = AutomationCatalog.runShortcut(named: "집중") { _, args in
            if args.first == "list" { return self.result(output: "집중\n") }
            runArguments = args
            return self.result(output: "완료\n")
        }
        XCTAssertEqual(outcome, .success(["완료"]))
        XCTAssertEqual(runArguments, ["run", "집중"])
    }

    func testRunShortcutWritesInputAndCleansUp() throws {
        var inputPath: String?
        let outcome = AutomationCatalog.runShortcut(named: "집중", input: "hello input") { _, args in
            if args.first == "list" { return self.result(output: "집중\n") }
            if let index = args.firstIndex(of: "--input-path"), index + 1 < args.count {
                inputPath = args[index + 1]
                let contents = try? String(contentsOfFile: args[index + 1], encoding: .utf8)
                XCTAssertEqual(contents, "hello input")
            }
            return self.result()
        }
        XCTAssertTrue(outcome.isSuccess)
        XCTAssertNotNil(inputPath)
        if let inputPath {
            XCTAssertFalse(
                FileManager.default.fileExists(atPath: inputPath),
                "임시 입력 파일은 실행 후 지운다"
            )
        }
    }

    func testRunShortcutClassifiesFailures() {
        XCTAssertEqual(
            AutomationCatalog.runShortcut(named: "집중") { _, args in
                if args.first == "list" { return self.result(output: "집중\n") }
                return self.result(exitCode: 1, error: "Not authorized to send Apple events (-1743)")
            },
            .failure(.automationDenied)
        )
        XCTAssertEqual(
            AutomationCatalog.runShortcut(named: "집중") { _, _ in
                self.result(exitCode: 1, error: "not found")
            },
            .failure(.shortcutsUnavailable)
        )
        XCTAssertEqual(
            AutomationCatalog.runShortcut(named: "집중") { _, args in
                if args.first == "list" { return self.result(output: "집중\n") }
                return self.result(exitCode: 1, error: "failed")
            },
            .failure(.commandFailed("failed"))
        )
    }

    // MARK: - App 동작

    func testOpenURLValidatesScheme() {
        XCTAssertEqual(
            AutomationCatalog.openURL("  ") { _ in
                XCTFail("빈 주소는 열지 않는다")
                return true
            },
            .failure(.emptyURL)
        )
        XCTAssertEqual(
            AutomationCatalog.openURL("file:///etc/passwd") { _ in
                XCTFail("file scheme은 열지 않는다")
                return true
            },
            .failure(.invalidURL("file:///etc/passwd"))
        )
        XCTAssertEqual(
            AutomationCatalog.openURL("not a url") { _ in
                XCTFail("잘못된 주소는 열지 않는다")
                return true
            },
            .failure(.invalidURL("not a url"))
        )
    }

    func testOpenURLOpensScheme() {
        var opened: URL?
        let outcome = AutomationCatalog.openURL(" shortcuts://run-shortcut?name=Test ")
        { url in
            opened = url
            return true
        }
        XCTAssertTrue(outcome.isSuccess)
        XCTAssertEqual(opened?.scheme, "shortcuts")
        XCTAssertEqual(opened?.host, "run-shortcut")

        XCTAssertEqual(
            AutomationCatalog.openURL("music://") { _ in false },
            .failure(.invalidURL("music://"))
        )
    }

    // MARK: - 자동화 카탈로그

    func testAutomationLinesFilterAndMarkUnsupported() {
        let shortcuts = [
            shortcut("아침", triggers: [timeTrigger]),
            shortcut("업무", triggers: [focusTrigger]),
            shortcut("비어 있음", triggers: []),
        ]

        let all = AutomationCatalog.automationLines(shortcuts: shortcuts)
        XCTAssertEqual(all.count, 2)
        XCTAssertTrue(all.contains { $0.hasPrefix("아침 — ") })
        XCTAssertTrue(
            all.contains { $0.contains("ui.catalog.state_planned".localized) },
            "감시자가 없는 트리거는 준비 중으로 표시한다"
        )

        let supportedOnly = AutomationCatalog.automationLines(
            shortcuts: shortcuts,
            includeUnsupported: false
        )
        XCTAssertEqual(supportedOnly.count, 1)
        XCTAssertTrue(supportedOnly[0].hasPrefix("아침"))

        let filtered = AutomationCatalog.automationLines(shortcuts: shortcuts, query: "업무")
        XCTAssertEqual(filtered.count, 1)
        XCTAssertTrue(filtered[0].hasPrefix("업무"))
    }

    func testShortcutLookupPrefersExactThenContains() {
        let shortcuts = [shortcut("아침 루틴", triggers: []), shortcut("아침", triggers: [])]
        XCTAssertEqual(
            AutomationCatalog.shortcut(named: "아침", in: shortcuts)?.name,
            "아침",
            "정확히 일치하는 이름을 먼저 고른다"
        )
        XCTAssertEqual(
            AutomationCatalog.shortcut(named: "루틴", in: shortcuts)?.name,
            "아침 루틴"
        )
        XCTAssertNil(AutomationCatalog.shortcut(named: "   ", in: shortcuts))
        XCTAssertNil(AutomationCatalog.shortcut(named: "없음", in: shortcuts))
    }

    func testHasTrigger() {
        let withTriggers = shortcut("아침", triggers: [timeTrigger])
        XCTAssertTrue(AutomationCatalog.hasTrigger(shortcut: withTriggers, triggerName: ""))
        XCTAssertTrue(
            AutomationCatalog.hasTrigger(
                shortcut: withTriggers,
                triggerName: timeTrigger.displayName
            )
        )
        XCTAssertFalse(AutomationCatalog.hasTrigger(shortcut: withTriggers, triggerName: "없는 트리거"))

        let without = shortcut("빈", triggers: [])
        XCTAssertFalse(AutomationCatalog.hasTrigger(shortcut: without, triggerName: ""))
    }

    // MARK: - 엔진 배선

    private func run(_ step: ShortcutStep) -> ExecutionEngine.Result {
        var context = UseModelExecutor.ExecutionContext()
        return ExecutionEngine.shared.execute(steps: [step], context: &context)
    }

    private func step(_ type: ActionType, _ config: AppIntentAutomationConfig) -> ShortcutStep {
        ShortcutStep(type: type, target: "", title: "", actionParameters: config.encode())
    }

    override func tearDown() {
        ExecutionEngine.shared.appListProvider = nil
        ExecutionEngine.shared.shortcutListProvider = nil
        super.tearDown()
    }

    func testFindAppIsWiredIntoEngine() {
        ExecutionEngine.shared.appListProvider = {
            [self.app("Safari", "com.apple.Safari")]
        }

        let found = run(step(.findApp, AppIntentAutomationConfig(query: "safari")))
        XCTAssertTrue(found.success)
        XCTAssertEqual(found.error, nil)

        let empty = run(step(.findApp, AppIntentAutomationConfig(query: "  ")))
        XCTAssertFalse(empty.success)
        XCTAssertNotEqual(empty.error, "toast.reason.unimplemented".localized)
    }

    func testAutomationListingIsWiredIntoEngine() {
        ExecutionEngine.shared.shortcutListProvider = {
            [self.shortcut("아침", triggers: [self.timeTrigger])]
        }

        let listed = run(step(.automation, AppIntentAutomationConfig()))
        XCTAssertTrue(listed.success)

        let none = run(step(.findAutomation, AppIntentAutomationConfig(query: "없음")))
        XCTAssertFalse(none.success)
        XCTAssertNotEqual(none.error, "toast.reason.unimplemented".localized)
    }

    func testAutomationRunAndTriggerAreWired() {
        ExecutionEngine.shared.shortcutListProvider = {
            [self.shortcut("아침", triggers: [self.timeTrigger])]
        }

        let ran = run(step(.automationRun, AppIntentAutomationConfig(shortcutName: "아침")))
        XCTAssertTrue(ran.success, "실행할 단축어를 찾으면 엔진이 실행한다")

        let missing = run(step(.automationRun, AppIntentAutomationConfig(shortcutName: "없음")))
        XCTAssertFalse(missing.success)
        XCTAssertEqual(
            missing.error,
            "error.user.intent_shortcut_not_in_app".localizedFormat("없음")
        )

        let triggered = run(step(.trigger, AppIntentAutomationConfig(shortcutName: "아침")))
        XCTAssertTrue(triggered.success)

        let wrongTrigger = run(step(.trigger, AppIntentAutomationConfig(
            shortcutName: "아침",
            triggerName: "없는 트리거"
        )))
        XCTAssertFalse(wrongTrigger.success)
        XCTAssertNotEqual(wrongTrigger.error, "toast.reason.unimplemented".localized)
    }

    func testAppIntentAndActionFailuresAreWired() {
        let unimplemented = "toast.reason.unimplemented".localized

        let emptyIntent = run(step(.appIntent, AppIntentAutomationConfig()))
        XCTAssertFalse(emptyIntent.success)
        XCTAssertNotEqual(emptyIntent.error, unimplemented)

        let emptyAction = run(step(.appAction, AppIntentAutomationConfig()))
        XCTAssertFalse(emptyAction.success)
        XCTAssertNotEqual(emptyAction.error, unimplemented)
    }
}

private extension Result {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
