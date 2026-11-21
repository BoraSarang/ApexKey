import AppKit
import Foundation

/// 새 탭 AppleScript를 아는 터미널 앱 (T-195)
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

/// 실제로 열 터미널 대상 (R-20261121-01).
///
/// `TerminalApp`은 **앱별 AppleScript가 있는 앱**만 담는다. 새 창은
/// `NSWorkspace.open(_:withApplicationAt:)`이라 폴더 열기를 지원하는 앱이면 무엇이든 되므로,
/// enum 밖 앱(Ghostty·Warp·kitty 등)은 `.custom`으로 받는다.
/// 새 탭은 앱별 스크립트가 필요하므로 known만 지원한다.
enum TerminalTarget: Equatable {
    case known(TerminalApp)
    case custom(bundleID: String?, path: String?)

    var bundleID: String? {
        switch self {
        case .known(let app): return app.bundleID
        case .custom(let bundleID, _): return bundleID
        }
    }

    var path: String? {
        switch self {
        case .known: return nil
        case .custom(_, let path): return path
        }
    }

    /// 새 탭(AppleScript) 지원 여부 — 앱별 스크립트가 있는 known만.
    var supportsNewTab: Bool {
        if case .known = self { return true }
        return false
    }

    /// 로그·UI 표시용 이름
    var displayName: String {
        switch self {
        case .known(let app):
            return app.displayName
        case .custom(let bundleID, let path):
            if let path, !path.isEmpty,
               let bundle = Bundle(url: URL(fileURLWithPath: path)) {
                return bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            }
            return bundleID ?? ""
        }
    }
}

/// 폴더를 터미널에서 연다 (T-195).
///
/// **새 창**은 `NSWorkspace.open(_:withApplicationAt:)`으로 연다 — 터미널 앱이
/// "폴더 열기"를 직접 처리하므로 **터미널에 AppleEvent를 보내지 않는다**
/// (Finder 폴더 읽기는 별개로 자동화 권한을 쓴다 — `FinderPathProvider`).
/// **새 탭**은 AppleScript가 필요하다(Automation 권한). 실패하면 성공으로 뭉개지 않고
/// 사유를 돌려준다 — 조용한 실패는 조용할수록 오래 남는다.
enum TerminalLauncher {
    struct OpenResult {
        var success: Bool
        /// 실패 사유 (사용자 문구). 성공이면 nil.
        var message: String?
    }

    // MARK: - 순수 로직 (테스트 대상)

    /// 설정된 번들ID/경로 → 실제 열 대상.
    ///
    /// - 알려진 앱이면 `.known` (새 탭 가능)
    /// - 그 밖의 번들ID/경로는 `.custom` (새 창만)
    /// - 둘 다 비어 있으면 자동 — 설치된 known 중 iTerm2 우선
    static func resolveTarget(
        bundleID: String?,
        path: String? = nil,
        isInstalled: (String) -> Bool = isInstalledDefault
    ) -> TerminalTarget? {
        let id = bundleID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let appPath = path?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !id.isEmpty {
            if let known = TerminalApp(rawValue: id) {
                return .known(known)
            }
            return .custom(bundleID: id, path: appPath.isEmpty ? nil : appPath)
        }
        if !appPath.isEmpty {
            return .custom(bundleID: nil, path: appPath)
        }
        return TerminalApp.allCases.first { isInstalled($0.bundleID) }.map(TerminalTarget.known)
    }

    static func isInstalledDefault(_ bundleID: String) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }

    /// 앱 URL — 직접 고른 경로 우선, 없으면 번들ID. (부작용 없음: 파일 존재 + LaunchServices 조회)
    static func appURL(for target: TerminalTarget) -> URL? {
        switch target {
        case .known(let app):
            return NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID)
        case .custom(let bundleID, let path):
            if let path, FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
            if let bundleID,
               let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                return url
            }
            return nil
        }
    }

    // MARK: - 열기

    static func open(folder: URL, target: TerminalTarget, openInNewTab: Bool) -> OpenResult {
        guard let appURL = appURL(for: target) else {
            Logger.error("E-MAC-TERM-8103", "터미널 앱 없음: \(target.bundleID ?? target.path ?? "?")")
            return OpenResult(success: false, message: "toast.reason.terminal_app_missing".localized)
        }
        if openInNewTab {
            // 새 탭은 앱별 AppleScript가 필요하다 — 직접 고른 앱은 새 창만 지원
            guard case .known(let app) = target else {
                Logger.error("E-MAC-TERM-8106", "새 탭 미지원 앱: \(target.bundleID ?? target.path ?? "?")")
                return OpenResult(success: false, message: "toast.reason.terminal_tab_unsupported".localized)
            }
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
        Logger.info("FEATURE", "터미널에서 폴더 열기 (\(target.displayName) · 새 창): \(folder.path)")
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
