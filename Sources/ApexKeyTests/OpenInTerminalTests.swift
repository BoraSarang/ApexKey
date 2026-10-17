import XCTest
@testable import ApexKey

/// PLAN_v0.32 — 터미널에서 열기 (T-195).
///
/// **부작용 없는 검증만** 한다: 터미널을 실제로 띄우면 테스트가 창을 연다.
/// 경로 결정·AppleScript 출력 파싱·앱 선택·인용은 순수 함수로 분리해 검증하고,
/// Finder 자동화 권한이 필요한 실제 읽기는 사용자 실동작 항목이다.
final class OpenInTerminalTests: XCTestCase {
    // MARK: - TerminalOpenConfig 코덱

    func testConfigDefaultsAreAutoAndWindow() {
        let cfg = TerminalOpenConfig.decode(from: nil)
        XCTAssertNil(cfg.appBundleID)
        XCTAssertFalse(cfg.openInNewTab)

        XCTAssertNil(TerminalOpenConfig.decode(from: Data()).appBundleID)
    }

    func testConfigRoundTrip() {
        let cfg = TerminalOpenConfig(appBundleID: "com.googlecode.iterm2", openInNewTab: true)
        let decoded = TerminalOpenConfig.decode(from: cfg.encode())
        XCTAssertEqual(decoded.appBundleID, "com.googlecode.iterm2")
        XCTAssertTrue(decoded.openInNewTab)
    }

    /// 관대 디코딩 — 필드가 빠진 예전 JSON이 설정 전체를 기본값으로 되돌리면 안 된다 (E-MAC-STORE-5008)
    func testConfigToleratesMissingKeys() {
        let partial = #"{"appBundleID":"com.apple.Terminal"}"#.data(using: .utf8)
        let decoded = TerminalOpenConfig.decode(from: partial)
        XCTAssertEqual(decoded.appBundleID, "com.apple.Terminal")
        XCTAssertFalse(decoded.openInNewTab)
    }

    func testConfigToleratesBrokenData() {
        let broken = Data([0x00, 0x01, 0x02])
        XCTAssertNil(TerminalOpenConfig.decode(from: broken).appBundleID)
        XCTAssertFalse(TerminalOpenConfig.decode(from: broken).openInNewTab)
    }

    // MARK: - 열 폴더 결정 (선택 우선 → 현재 창)

    func testResolvePrefersSelectedFolder() {
        let selectedFolder = URL(fileURLWithPath: "/tmp/선택폴더")
        let currentFolder = URL(fileURLWithPath: "/tmp/현재창")
        let resolved = FinderPathProvider.resolveFolder(
            selection: [selectedFolder],
            currentFolder: currentFolder,
            isDirectory: { $0.path == "/tmp/선택폴더" }
        )
        XCTAssertEqual(resolved?.path, "/tmp/선택폴더")
    }

    func testResolveUsesFolderAmongSelectedFiles() {
        let file = URL(fileURLWithPath: "/tmp/현재창/aa.mp4")
        let folder = URL(fileURLWithPath: "/tmp/현재창/하위")
        let resolved = FinderPathProvider.resolveFolder(
            selection: [file, folder],
            currentFolder: nil,
            isDirectory: { $0.path == "/tmp/현재창/하위" }
        )
        XCTAssertEqual(resolved?.path, "/tmp/현재창/하위")
    }

    func testResolveFallsBackToParentOfSelectedFile() {
        let file = URL(fileURLWithPath: "/tmp/현재창/aa.mp4")
        let resolved = FinderPathProvider.resolveFolder(
            selection: [file],
            currentFolder: URL(fileURLWithPath: "/tmp/다른창"),
            isDirectory: { _ in false }
        )
        XCTAssertEqual(resolved?.path, "/tmp/현재창")
    }

    func testResolveFallsBackToCurrentFolder() {
        let resolved = FinderPathProvider.resolveFolder(
            selection: [],
            currentFolder: URL(fileURLWithPath: "/tmp/현재창"),
            isDirectory: { _ in false }
        )
        XCTAssertEqual(resolved?.path, "/tmp/현재창")
    }

    func testResolveReturnsNilWhenNothingKnown() {
        XCTAssertNil(FinderPathProvider.resolveFolder(selection: [], currentFolder: nil, isDirectory: { _ in false }))
    }

    // MARK: - AppleScript 출력 파싱 (현재폴더 NUL 선택…)

    func testParseReadsCurrentFolderAndSelection() {
        let parsed = FinderPathProvider.parseAppleScriptOutput(
            "/Users/lee/Files/\u{0}/Users/lee/Files/하위\u{0}"
        )
        XCTAssertEqual(parsed.currentFolder?.path, "/Users/lee/Files")
        XCTAssertEqual(parsed.selection.map(\.path), ["/Users/lee/Files/하위"])
    }

    func testParseHandlesMissingCurrentFolder() {
        let parsed = FinderPathProvider.parseAppleScriptOutput("\u{0}/Users/lee/Files/하위\u{0}")
        XCTAssertNil(parsed.currentFolder)
        XCTAssertEqual(parsed.selection.map(\.path), ["/Users/lee/Files/하위"])
    }

    func testParseEmptyOutput() {
        let parsed = FinderPathProvider.parseAppleScriptOutput("")
        XCTAssertNil(parsed.currentFolder)
        XCTAssertTrue(parsed.selection.isEmpty)
    }

    /// 구분자가 NUL인 이유 — 경로에 줄바꿈이 들어가도 한 항목으로 유지된다.
    func testParseKeepsNewlineInsidePath() {
        let weird = "/Users/lee/we\nird"
        let parsed = FinderPathProvider.parseAppleScriptOutput("\(weird)\u{0}")
        XCTAssertEqual(parsed.currentFolder?.path, weird)
    }

    // MARK: - 터미널 앱 결정

    func testResolveAutoPrefersITerm2() {
        XCTAssertEqual(TerminalLauncher.resolveApp(bundleID: nil, isInstalled: { _ in true }), .iTerm2)
        XCTAssertEqual(TerminalLauncher.resolveApp(bundleID: "  ", isInstalled: { _ in true }), .iTerm2)
    }

    func testResolveAutoFallsBackToAppleTerminal() {
        let onlyTerminal: (String) -> Bool = { $0 == "com.apple.Terminal" }
        XCTAssertEqual(TerminalLauncher.resolveApp(bundleID: nil, isInstalled: onlyTerminal), .appleTerminal)
        XCTAssertNil(TerminalLauncher.resolveApp(bundleID: nil, isInstalled: { _ in false }))
    }

    func testResolveExplicitSelectionWins() {
        XCTAssertEqual(
            TerminalLauncher.resolveApp(bundleID: "com.apple.Terminal", isInstalled: { _ in true }),
            .appleTerminal
        )
        // 지원하지 않는 번들ID는 자동으로 흘리지 않는다 — 사용자가 고른 값이 무효면 실패로 알린다
        XCTAssertNil(TerminalLauncher.resolveApp(bundleID: "com.unknown.terminal", isInstalled: { _ in true }))
    }

    // MARK: - 인용 (셸 → AppleScript 2계층)

    func testAppleScriptLiteralEscapesQuotesAndBackslashes() {
        XCTAssertEqual(AppleScriptLiteral.quoted("plain"), "\"plain\"")
        XCTAssertEqual(AppleScriptLiteral.quoted("a\"b"), "\"a\\\"b\"")
        XCTAssertEqual(AppleScriptLiteral.quoted("a\\b"), "\"a\\\\b\"")
    }

    /// 작은따옴표·큰따옴표가 섞인 경로가 스크립트를 깨뜨리지 않아야 한다
    func testShellThenAppleScriptQuotingKeepsPathInert() {
        let path = "/Users/lee/Doc's \"Qwen\"/x"
        let command = "cd " + ShellEnvironment.literal(path)
        XCTAssertEqual(command, "cd '/Users/lee/Doc'\\''s \"Qwen\"/x'")

        let literal = AppleScriptLiteral.quoted(command)
        XCTAssertTrue(literal.hasPrefix("\""))
        XCTAssertTrue(literal.hasSuffix("\""))
        // 이스케이프되지 않은 "Qwen" 이 남아 있으면 스크립트 문자열이 거기서 끝난다
        XCTAssertFalse(literal.contains("\"Qwen\""))
        XCTAssertTrue(literal.contains("\\\"Qwen\\\""))
    }

    // MARK: - 카탈로그 등록

    func testOpenInTerminalIsImplementedWithSettingsUI() {
        XCTAssertEqual(ActionType.openInTerminal.implementation, .implemented)
        XCTAssertTrue(ActionType.openInTerminal.hasStepSettingsUI)
        XCTAssertTrue(ActionType.openInTerminal.isSelectable)
        XCTAssertEqual(ActionType.openInTerminal.category, .essential)
        XCTAssertTrue(ActionCategory.essential.actionTypes.contains(.openInTerminal))
        XCTAssertFalse(ActionType.openInTerminal.displayName.isEmpty)
    }

    // MARK: - 실행 위임 (부작용 없는 실패 경로)

    func testOpenInTerminalMissingExplicitPathFails() {
        let result = ActionExecutor.openInTerminal(path: "/없는/경로/T-195", appBundleID: nil, openInNewTab: false)
        XCTAssertFalse(result.success)
        XCTAssertNil(result.path)
    }

    func testExecuteOpenInTerminalMissingPathFailsThroughEngine() {
        let step = ShortcutStep(type: .openInTerminal, target: "/없는/경로/T-195")
        var context = UseModelExecutor.ExecutionContext()
        let result = ExecutionEngine.shared.execute(steps: [step], context: &context)
        XCTAssertFalse(result.success)
        // 배선 누락이면 여기서 "미구현" 토스트가 나온다 (T-159류 회귀 감지)
        XCTAssertNotEqual(result.error, "toast.reason.unimplemented".localized)
        XCTAssertEqual(result.error, "toast.reason.folder_missing".localized)
    }
}
