import Foundation
import AppKit

/// 문서 앱 연동 — Pages·Numbers·TextEdit (T-216)
///
/// **실측(2026-11-09)**: 이 기기에는 Pages·Numbers가 설치되어 있지 않아 `sdef`를
/// 읽을 수 없었다(-43). TextEdit은 문서 생성·열기·본문 편집·글꼴/크기 속성을 제공한다.
/// 그래서 Pages·Numbers 코드는 **표준 `open`/`make new document`**만 사용하고,
/// 실행 전에 설치 여부를 확인해 "앱 미설치"를 명확히 알린다.
///
/// 본문 편집·글꼴 지정은 TextEdit 전용이다. Pages·Numbers의 본문을 스크립트로
/// 바꾸는 것은 사전 실측 없이 시도하지 않는다.
enum DocumentApps {

    typealias Runner = AppleApps.Runner
    typealias Opener = (URL) -> Bool
    typealias InstalledCheck = (DocumentConfig.App) -> Bool

    enum FailureReason: Equatable, Error {
        case appNotInstalled(String)
        case unsupportedApp(String)
        case fileNotFound(String)
        case emptyContent
        case emptyStyle
        case noOpenDocument
        case automationDenied
        case scriptFailed(String)

        var message: String {
            switch self {
            case .appNotInstalled(let name): return "error.user.doc_app_not_installed".localizedFormat(name)
            case .unsupportedApp(let name): return "error.user.doc_unsupported_app".localizedFormat(name)
            case .fileNotFound(let path): return "error.user.doc_file_not_found".localizedFormat(path)
            case .emptyContent: return "error.user.doc_empty_content".localized
            case .emptyStyle: return "error.user.doc_empty_style".localized
            case .noOpenDocument: return "error.user.doc_no_open_document".localized
            case .automationDenied: return "error.user.apple_denied".localized
            case .scriptFailed(let detail): return "error.user.apple_failed".localizedFormat(detail)
            }
        }
    }

    typealias Outcome = Result<[String], FailureReason>

    static let defaultRunner: Runner = AppleApps.defaultRunner
    static let defaultOpener: Opener = { NSWorkspace.shared.open($0) }

    /// 설치 여부 — 기본 앱은 항상 사용 가능으로 본다
    static let defaultInstalledCheck: InstalledCheck = { app in
        guard let bundleID = app.bundleIdentifier else { return true }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }

    // MARK: - 새 문서

    static func createDocument(
        app: DocumentConfig.App,
        content: String,
        installed: InstalledCheck = defaultInstalledCheck,
        runner: Runner = defaultRunner
    ) -> Outcome {
        guard app != .defaultApp else {
            return .failure(.unsupportedApp(app.displayName))
        }
        guard installed(app) else {
            return .failure(.appNotInstalled(app.displayName))
        }

        switch app {
        case .textEdit:
            return run(scripts.textEditNew, arguments: [content], runner: runner)
        case .pages:
            return run(scripts.pagesNew, arguments: [], runner: runner)
        case .numbers:
            return run(scripts.numbersNew, arguments: [], runner: runner)
        case .defaultApp:
            return .failure(.unsupportedApp(app.displayName))
        }
    }

    // MARK: - 문서 열기

    static func viewDocument(
        path: String,
        app: DocumentConfig.App,
        installed: InstalledCheck = defaultInstalledCheck,
        opener: Opener = defaultOpener,
        runner: Runner = defaultRunner,
        fileManager: FileManager = .default
    ) -> Outcome {
        let url: URL
        switch existingURL(path, fileManager: fileManager) {
        case .failure(let reason): return .failure(reason)
        case .success(let value): url = value
        }

        if app == .defaultApp {
            guard opener(url) else {
                return .failure(.scriptFailed("document could not be opened"))
            }
            return .success([url.path])
        }

        guard installed(app), let name = app.scriptName else {
            return .failure(.appNotInstalled(app.displayName))
        }
        let source: String
        switch app {
        case .textEdit: source = scripts.textEditOpen
        case .pages: source = scripts.pagesOpen
        case .numbers: source = scripts.numbersOpen
        case .defaultApp: return .failure(.unsupportedApp(name))
        }
        return run(source, arguments: [url.path], runner: runner)
    }

    // MARK: - 문서 편집 (TextEdit 전용)

    static func editDocument(
        path: String,
        text: String,
        mode: DocumentConfig.EditMode,
        app: DocumentConfig.App,
        installed: InstalledCheck = defaultInstalledCheck,
        runner: Runner = defaultRunner,
        fileManager: FileManager = .default
    ) -> Outcome {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.emptyContent)
        }
        guard app == .textEdit else {
            return .failure(.unsupportedApp(app.displayName))
        }
        guard installed(app) else {
            return .failure(.appNotInstalled(app.displayName))
        }

        var targetPath = ""
        if !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            switch existingURL(path, fileManager: fileManager) {
            case .failure(let reason): return .failure(reason)
            case .success(let url): targetPath = url.path
            }
        }
        return run(
            scripts.textEditEdit,
            arguments: [targetPath, text, mode.rawValue],
            sentinels: [("APEX_NO_DOCUMENT", .noOpenDocument)],
            runner: runner
        )
    }

    // MARK: - 문단 스타일 (TextEdit 전용)

    static func setParagraphStyle(
        path: String,
        fontName: String,
        fontSize: Int,
        app: DocumentConfig.App,
        installed: InstalledCheck = defaultInstalledCheck,
        runner: Runner = defaultRunner,
        fileManager: FileManager = .default
    ) -> Outcome {
        let cleanFont = fontName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanFont.isEmpty || fontSize > 0 else { return .failure(.emptyStyle) }
        guard app == .textEdit else {
            return .failure(.unsupportedApp(app.displayName))
        }
        guard installed(app) else {
            return .failure(.appNotInstalled(app.displayName))
        }

        var targetPath = ""
        if !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            switch existingURL(path, fileManager: fileManager) {
            case .failure(let reason): return .failure(reason)
            case .success(let url): targetPath = url.path
            }
        }
        return run(
            scripts.textEditStyle,
            arguments: [cleanFont, String(max(fontSize, 0)), targetPath],
            sentinels: [("APEX_NO_DOCUMENT", .noOpenDocument)],
            runner: runner
        )
    }

    // MARK: - 내부

    private static func existingURL(
        _ path: String,
        fileManager: FileManager
    ) -> Result<URL, FailureReason> {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.fileNotFound(path)) }
        let url = URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath)
        guard fileManager.fileExists(atPath: url.path) else {
            return .failure(.fileNotFound(url.path))
        }
        return .success(url)
    }

    private static func run(
        _ source: String,
        arguments: [String],
        sentinels: [(marker: String, reason: FailureReason)] = [],
        runner: Runner
    ) -> Outcome {
        let result = runner(source, arguments)
        if result.succeeded {
            return .success(AppleApps.parseLines(result.standardOutput))
        }
        for sentinel in sentinels where result.standardError.contains(sentinel.marker) {
            return .failure(sentinel.reason)
        }
        if result.timedOut {
            return .failure(.scriptFailed("timeout"))
        }
        if AppleApps.isAutomationDenied(result.standardError) {
            return .failure(.automationDenied)
        }
        let detail = result.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
        return .failure(.scriptFailed(detail.isEmpty ? "exit \(result.exitCode)" : String(detail.prefix(200))))
    }

    enum scripts {

        static let textEditNew = """
        on run argv
            set docContent to item 1 of argv
            tell application "TextEdit"
                set newDoc to make new document
                if docContent is not "" then set text of newDoc to docContent
                activate
                return name of newDoc
            end tell
        end run
        """

        static let pagesNew = """
        on run argv
            tell application "Pages"
                make new document
                activate
                return "Pages"
            end tell
        end run
        """

        static let numbersNew = """
        on run argv
            tell application "Numbers"
                make new document
                activate
                return "Numbers"
            end tell
        end run
        """

        static let textEditOpen = """
        on run argv
            set targetPath to item 1 of argv
            tell application "TextEdit"
                set targetDoc to open (POSIX file targetPath)
                activate
                return name of targetDoc
            end tell
        end run
        """

        static let pagesOpen = """
        on run argv
            set targetPath to item 1 of argv
            tell application "Pages"
                set targetDoc to open (POSIX file targetPath)
                activate
                return name of targetDoc
            end tell
        end run
        """

        static let numbersOpen = """
        on run argv
            set targetPath to item 1 of argv
            tell application "Numbers"
                set targetDoc to open (POSIX file targetPath)
                activate
                return name of targetDoc
            end tell
        end run
        """

        static let textEditEdit = """
        on run argv
            set targetPath to item 1 of argv
            set editText to item 2 of argv
            set editMode to item 3 of argv
            tell application "TextEdit"
                if targetPath is "" then
                    if (count of documents) is 0 then error "APEX_NO_DOCUMENT" number 9401
                    set targetDoc to document 1
                else
                    set targetDoc to open (POSIX file targetPath)
                end if
                if editMode is "replace" then
                    set text of targetDoc to editText
                else
                    set text of targetDoc to (text of targetDoc) & editText
                end if
                return name of targetDoc
            end tell
        end run
        """

        static let textEditStyle = """
        on run argv
            set fontName to item 1 of argv
            set fontSize to (item 2 of argv) as integer
            set targetPath to item 3 of argv
            tell application "TextEdit"
                if targetPath is "" then
                    if (count of documents) is 0 then error "APEX_NO_DOCUMENT" number 9401
                    set targetDoc to document 1
                else
                    set targetDoc to open (POSIX file targetPath)
                end if
                set targetText to text of targetDoc
                if fontName is not "" then set font of targetText to fontName
                if fontSize > 0 then set size of targetText to fontSize
                return name of targetDoc
            end tell
        end run
        """
    }
}
