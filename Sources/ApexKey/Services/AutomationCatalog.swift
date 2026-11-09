import AppKit
import Foundation

/// App Intents·자동화 카탈로그 (T-222)
///
/// **정직한 범위**
/// - App Intent를 이름으로 직접 호출하는 공개 런타임 API는 없다. 그래서 `appIntent`는
///   사용자가 Shortcuts 앱에서 해당 App Intent를 넣어 만든 단축어를 이름으로 실행한다.
/// - `appAction`은 앱의 URL scheme을 연다. scheme이 동작을 정의하므로 앱별 사전 확인이 필요 없다.
/// - `automation`·`findAutomation`·`automationRun`·`trigger`는 ApexKey 안의 단축어·트리거
///   모델을 그대로 읽고 실행한다. 별도 저장소가 없다.
///
/// 외부 실행·네트워크·앱 목록은 주입 가능해 테스트가 실제 앱·단축어를 건드리지 않는다.
enum AutomationCatalog {

    typealias Runner = (_ executable: String, _ arguments: [String]) -> ProcessRunner.Result
    typealias Opener = (URL) -> Bool

    static let shortcutsPath = "/usr/bin/shortcuts"

    enum FailureReason: Equatable, Error {
        case emptyQuery
        case noMatches(String)
        case emptyShortcutName
        case emptyURL
        case shortcutsUnavailable
        case shortcutMissing(String)
        case shortcutNotInApexKey(String)
        case triggerMissing(String, String)
        case invalidURL(String)
        case inputWriteFailed(String)
        case automationDenied
        case commandFailed(String)

        var message: String {
            switch self {
            case .emptyQuery: return "error.user.intent_empty_query".localized
            case .noMatches(let query): return "error.user.intent_no_matches".localizedFormat(query)
            case .emptyShortcutName: return "error.user.intent_empty_shortcut".localized
            case .emptyURL: return "error.user.intent_empty_url".localized
            case .shortcutsUnavailable: return "error.user.intent_shortcuts_unavailable".localized
            case .shortcutMissing(let name): return "error.user.intent_shortcut_missing".localizedFormat(name)
            case .shortcutNotInApexKey(let name): return "error.user.intent_shortcut_not_in_app".localizedFormat(name)
            case .triggerMissing(let name, let trigger):
                return "error.user.intent_trigger_missing".localizedFormat(name, trigger)
            case .invalidURL(let value): return "error.user.intent_invalid_url".localizedFormat(value)
            case .inputWriteFailed(let path): return "error.user.intent_input_write_failed".localizedFormat(path)
            case .automationDenied: return "error.user.apple_denied".localized
            case .commandFailed(let detail): return "error.user.intent_command_failed".localizedFormat(detail)
            }
        }
    }

    typealias Outcome = Result<[String], FailureReason>

    static let defaultRunner: Runner = { executable, arguments in
        ProcessRunner.run(executable: executable, arguments: arguments, timeout: 120)
    }

    static let defaultOpener: Opener = { NSWorkspace.shared.open($0) }

    // MARK: - 앱 찾기

    /// 이름 또는 번들 ID로 설치 앱을 찾는다. 결과는 `이름 — 번들ID` 줄이다.
    static func findApps(
        query: String,
        apps: [AppItem],
        limit: Int = 20
    ) -> Outcome {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return .failure(.emptyQuery) }

        let matches = apps
            .filter { app in
                app.name.localizedCaseInsensitiveContains(needle)
                    || app.bundleID.localizedCaseInsensitiveContains(needle)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .prefix(limit)
        guard !matches.isEmpty else { return .failure(.noMatches(needle)) }
        return .success(matches.map { "\($0.name) — \($0.bundleID)" })
    }

    // MARK: - App Intents (Shortcuts 실행)

    /// Shortcuts 앱의 단축어를 이름으로 실행한다. 입력이 있으면 임시 파일로 넘긴다.
    static func runShortcut(
        named name: String,
        input: String = "",
        fileManager: FileManager = .default,
        runner: Runner = defaultRunner
    ) -> Outcome {
        let shortcut = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !shortcut.isEmpty else { return .failure(.emptyShortcutName) }

        let list = runner(shortcutsPath, ["list"])
        guard list.succeeded else {
            if AppleApps.isAutomationDenied(list.standardError) {
                return .failure(.automationDenied)
            }
            return .failure(.shortcutsUnavailable)
        }
        let names = AppleApps.parseLines(list.standardOutput)
        guard names.contains(shortcut) else {
            return .failure(.shortcutMissing(shortcut))
        }

        var arguments = ["run", shortcut]
        var temporary: URL?
        if !input.isEmpty {
            let file = fileManager.temporaryDirectory
                .appendingPathComponent("ApexKey-intent-\(UUID().uuidString).txt")
            do {
                try input.write(to: file, atomically: true, encoding: .utf8)
            } catch {
                return .failure(.inputWriteFailed(file.path))
            }
            temporary = file
            arguments += ["--input-path", file.path]
        }
        defer {
            if let temporary { try? fileManager.removeItem(at: temporary) }
        }

        let result = runner(shortcutsPath, arguments)
        guard result.succeeded else {
            if AppleApps.isAutomationDenied(result.standardError) {
                return .failure(.automationDenied)
            }
            return .failure(.commandFailed(detail(result)))
        }
        let output = AppleApps.parseLines(result.standardOutput)
        return .success(output.isEmpty ? [shortcut] : output)
    }

    // MARK: - App 동작 (URL scheme)

    static func openURL(_ raw: String, opener: Opener = defaultOpener) -> Outcome {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.emptyURL) }
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              !scheme.isEmpty,
              scheme != "file" else {
            return .failure(.invalidURL(trimmed))
        }
        guard opener(url) else { return .failure(.invalidURL(trimmed)) }
        return .success([url.absoluteString])
    }

    // MARK: - 자동화 카탈로그

    /// 등록된 자동화를 `단축어 — 트리거` 줄로 만든다.
    static func automationLines(
        shortcuts: [ShortcutItem],
        query: String = "",
        includeUnsupported: Bool = true
    ) -> [String] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)

        var lines: [String] = []
        for shortcut in shortcuts {
            for trigger in shortcut.automations {
                if !includeUnsupported && !trigger.isWatcherSupported { continue }
                if !needle.isEmpty,
                   !shortcut.name.localizedCaseInsensitiveContains(needle),
                   !trigger.displayName.localizedCaseInsensitiveContains(needle) {
                    continue
                }
                let suffix = trigger.isWatcherSupported ? "" : " (" + "ui.catalog.state_planned".localized + ")"
                lines.append("\(shortcut.name) — \(trigger.displayName)\(suffix)")
            }
        }
        return lines
    }

    /// 이름으로 단축어를 찾는다. 정확히 일치하는 이름을 우선하고, 없으면 포함 검색한다.
    static func shortcut(named name: String, in shortcuts: [ShortcutItem]) -> ShortcutItem? {
        let needle = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return nil }
        if let exact = shortcuts.first(where: {
            $0.name.compare(needle, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) {
            return exact
        }
        return shortcuts.first {
            $0.name.localizedCaseInsensitiveContains(needle)
        }
    }

    /// 단축어에 해당 트리거가 있는지. 트리거 이름이 비면 아무 트리거 하나면 통과한다.
    static func hasTrigger(
        shortcut: ShortcutItem,
        triggerName: String
    ) -> Bool {
        let needle = triggerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return !shortcut.automations.isEmpty }
        return shortcut.automations.contains {
            $0.displayName.localizedCaseInsensitiveContains(needle)
        }
    }

    // MARK: - 공통

    private static func detail(_ result: ProcessRunner.Result) -> String {
        if result.timedOut { return "timeout" }
        if let launchError = result.launchError { return launchError }
        let error = result.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
        if !error.isEmpty { return String(error.prefix(200)) }
        let output = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !output.isEmpty { return String(output.prefix(200)) }
        return "exit \(result.exitCode)"
    }
}
