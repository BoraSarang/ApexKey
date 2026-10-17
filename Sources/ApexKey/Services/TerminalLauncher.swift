import AppKit
import Foundation

/// 지원하는 터미널 앱 (T-195)
enum TerminalApp: String, CaseIterable, Identifiable {
    case iTerm2 = "com.googlecode.iterm2"
    case appleTerminal = "com.apple.Terminal"

    var id: String { rawValue }
    var bundleID: String { rawValue }

    var displayName: String {
        switch self {
        case .iTerm2: return "terminal.app.iterm2".localized
        case .appleTerminal: return "terminal.app.terminal".localized
        }
    }
}

/// 폴더를 터미널에서 연다 (T-195).
///
/// **새 창**은 `NSWorkspace.open(_:withApplicationAt:)`으로 연다 — 터미널 앱이
/// "폴더 열기"를 직접 처리하므로 **Automation 권한이 필요 없다**.
/// **새 탭**은 AppleScript가 필요하다(Automation 권한). 실패하면 성공으로 뭉개지 않고
/// 사유를 돌려준다 — 조용한 실패는 조용할수록 오래 남는다.
enum TerminalLauncher {
    struct OpenResult {
        var success: Bool
        /// 실패 사유 (사용자 문구). 성공이면 nil.
        var message: String?
    }

    // MARK: - 순수 로직 (테스트 대상)

    /// 설정된 번들ID → 실제 열 앱. 비어 있으면 자동(iTerm2 우선).
    static func resolveApp(
        bundleID: String?,
        isInstalled: (String) -> Bool = isInstalledDefault
    ) -> TerminalApp? {
        let trimmed = bundleID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            return TerminalApp(rawValue: trimmed)
        }
        return TerminalApp.allCases.first { isInstalled($0.bundleID) }
    }

    static func isInstalledDefault(_ bundleID: String) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }

    // MARK: - 열기

    static func open(folder: URL, app: TerminalApp, openInNewTab: Bool) -> OpenResult {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID) else {
            Logger.error("E-MAC-TERM-8103", "터미널 앱 없음: \(app.bundleID)")
            return OpenResult(success: false, message: "toast.reason.terminal_app_missing".localized)
        }
        if openInNewTab {
            return openTab(folder: folder, app: app)
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open([folder], withApplicationAt: appURL, configuration: configuration) { _, error in
            // 실패는 비동기로 온다 — 앱을 죽이지 않고 로그로 표면화한다
            if let error {
                Logger.error("E-MAC-TERM-8104", "터미널 폴더 열기 실패: \(error.localizedDescription)")
            }
        }
        Logger.info("FEATURE", "터미널에서 폴더 열기 (\(app.bundleID) · 새 창): \(folder.path)")
        return OpenResult(success: true, message: nil)
    }

    /// 새 탭 — AppleScript 경유 (Automation 권한 필요)
    private static func openTab(folder: URL, app: TerminalApp) -> OpenResult {
        // 셸 인용 → AppleScript 리터럴 순서로 감싼다 (계층이 다르다)
        let command = AppleScriptLiteral.quoted("cd " + ShellEnvironment.literal(folder.path))
        let source: String
        switch app {
        case .iTerm2:
            source = """
            tell application "iTerm2"
                activate
                if (count of windows) is 0 then
                    create window with default profile
                else
                    tell current window to create tab with default profile
                end if
                tell current session of current window
                    write text \(command)
                end tell
            end tell
            """
        case .appleTerminal:
            source = """
            tell application "Terminal"
                activate
                if (count of windows) is 0 then
                    do script \(command)
                else
                    do script \(command) in front window
                end if
            end tell
            """
        }

        let result = ScriptExecutor.runAppleScript(source)
        guard result.success else {
            Logger.error("E-MAC-TERM-8105", "터미널 새 탭 열기 실패 (\(app.bundleID)): \(result.errorOutput.prefix(300))")
            return OpenResult(success: false, message: "toast.reason.terminal_tab_failed".localized)
        }
        Logger.info("FEATURE", "터미널에서 폴더 열기 (\(app.bundleID) · 새 탭): \(folder.path)")
        return OpenResult(success: true, message: nil)
    }
}
