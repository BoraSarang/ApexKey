import Foundation

/// Apple 앱 연동 1 — Notes·Reminders·Calendar (T-214)
///
/// **왜 `osascript` + 인자 전달인가**
/// - 제목·본문을 AppleScript 소스에 문자열 보간하면 따옴표·줄바꿈 하나로 스크립트가 깨진다.
///   `on run argv`로 넘기면 사용자 입력이 코드가 되지 않는다.
/// - 실패 사유를 **권한 거부 / 항목 없음 / 스크립트 오류**로 나눠야 사용자가 무엇을
///   고쳐야 하는지 알 수 있다. `osascript`의 stderr에는 이 구분에 필요한 단서가 있다.
///
/// 테스트는 `runner`를 주입해 실제 앱·권한 없이 인자 구성과 성공/실패 경로를 검증한다.
enum AppleApps {

    typealias Runner = (_ source: String, _ arguments: [String]) -> ProcessRunner.Result

    enum FailureReason: Equatable, Error {
        case emptyTitle
        case emptyText
        case noteNotFound(String)
        case listNotFound(String)
        case calendarNotFound(String)
        case invalidDuration
        case automationDenied
        case scriptFailed(String)

        var message: String {
            switch self {
            case .emptyTitle: return "error.user.apple_empty_title".localized
            case .emptyText: return "error.user.apple_empty_text".localized
            case .noteNotFound(let name): return "error.user.apple_note_not_found".localizedFormat(name)
            case .listNotFound(let name): return "error.user.apple_list_not_found".localizedFormat(name)
            case .calendarNotFound(let name): return "error.user.apple_calendar_not_found".localizedFormat(name)
            case .invalidDuration: return "error.user.apple_invalid_duration".localized
            case .automationDenied: return "error.user.apple_denied".localized
            case .scriptFailed(let detail): return "error.user.apple_failed".localizedFormat(detail)
            }
        }
    }

    typealias Outcome = Result<[String], FailureReason>

    /// 기본 실행기 — osascript에 스크립트 하나와 인자들을 넘긴다
    static let defaultRunner: Runner = { source, arguments in
        ProcessRunner.run(
            executable: "/usr/bin/osascript",
            arguments: ["-e", source] + arguments,
            timeout: 60
        )
    }

    // MARK: - Notes

    static func createNote(
        title: String,
        body: String,
        runner: Runner = defaultRunner
    ) -> Outcome {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return .failure(.emptyTitle) }

        return run(
            scripts.newNote,
            arguments: [cleanTitle, html(from: body)],
            sentinels: [("APEX_NOTE_NOT_FOUND", .noteNotFound(cleanTitle))],
            runner: runner
        )
    }

    static func noteAction(
        _ operation: AppleAppConfig.NoteOperation,
        title: String,
        text: String,
        folderName: String,
        runner: Runner = defaultRunner
    ) -> Outcome {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanFolder = folderName.trimmingCharacters(in: .whitespacesAndNewlines)

        switch operation {
        case .append:
            guard !cleanTitle.isEmpty else { return .failure(.emptyTitle) }
            return run(
                scripts.appendNote,
                arguments: [cleanTitle, html(from: text)],
                sentinels: [("APEX_NOTE_NOT_FOUND", .noteNotFound(cleanTitle))],
                runner: runner
            )

        case .show:
            guard !cleanTitle.isEmpty else { return .failure(.emptyTitle) }
            return run(
                scripts.showNote,
                arguments: [cleanTitle],
                sentinels: [("APEX_NOTE_NOT_FOUND", .noteNotFound(cleanTitle))],
                runner: runner
            )

        case .createFolder:
            guard !cleanFolder.isEmpty else { return .failure(.emptyTitle) }
            return run(scripts.newNoteFolder, arguments: [cleanFolder], runner: runner)
        }
    }

    // MARK: - Reminders

    static func addReminder(
        title: String,
        listName: String,
        notes: String,
        dueOffsetMinutes: Int?,
        runner: Runner = defaultRunner
    ) -> Outcome {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return .failure(.emptyTitle) }
        let cleanList = listName.trimmingCharacters(in: .whitespacesAndNewlines)
        // -1은 AppleScript에서 "마감 없음"을 뜻한다
        let offset = dueOffsetMinutes ?? -1

        return run(
            scripts.newReminder,
            arguments: [cleanTitle, cleanList, notes, String(offset)],
            sentinels: [("APEX_LIST_NOT_FOUND", .listNotFound(cleanList))],
            runner: runner
        )
    }

    static func reminderLists(runner: Runner = defaultRunner) -> Outcome {
        run(scripts.reminderLists, arguments: [], runner: runner)
    }

    // MARK: - Calendar

    static func addEvent(
        title: String,
        calendarName: String,
        startOffsetMinutes: Int,
        durationMinutes: Int,
        location: String,
        notes: String,
        runner: Runner = defaultRunner
    ) -> Outcome {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return .failure(.emptyTitle) }
        guard durationMinutes > 0 else { return .failure(.invalidDuration) }
        let cleanCalendar = calendarName.trimmingCharacters(in: .whitespacesAndNewlines)

        return run(
            scripts.newEvent,
            arguments: [
                cleanTitle,
                cleanCalendar,
                String(startOffsetMinutes),
                String(durationMinutes),
                location,
                notes,
            ],
            sentinels: [("APEX_CALENDAR_NOT_FOUND", .calendarNotFound(cleanCalendar))],
            runner: runner
        )
    }

    static func calendarNames(runner: Runner = defaultRunner) -> Outcome {
        run(scripts.calendarNames, arguments: [], runner: runner)
    }

    // MARK: - 순수 로직

    /// Notes의 `body`는 HTML로 해석된다. 일반 텍스트를 그대로 넣으면 `<`가 태그로
    /// 사라지고 줄바꿈이 무시되므로 escape 후 `<br>`로 바꾼다.
    static func html(from text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\n", with: "<br>")
    }

    /// 줄바꿈으로 구분된 결과를 빈 줄 없이 정리한다
    static func parseLines(_ output: String) -> [String] {
        output
            .split(whereSeparator: { $0 == "\n" || $0 == "\r" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// osascript stderr를 사용자가 행동할 수 있는 사유로 분류한다
    static func classify(_ stderr: String, timedOut: Bool, exitCode: Int32) -> FailureReason {
        if timedOut { return .scriptFailed("timeout") }

        if isAutomationDenied(stderr) {
            return .automationDenied
        }

        let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        return .scriptFailed(detail.isEmpty ? "exit \(exitCode)" : String(detail.prefix(200)))
    }

    /// TCC 자동화 거부(-1743)를 판별한다 — 다른 Apple 앱 연동도 같은 규칙을 쓴다
    static func isAutomationDenied(_ text: String) -> Bool {
        text.contains("-1743") || text.contains("Not authorized")
            || text.contains("not authorized") || text.contains("not allowed")
            || text.contains("Not allowed")
    }

    // MARK: - 내부

    private static func run(
        _ source: String,
        arguments: [String],
        sentinels: [(marker: String, reason: FailureReason)] = [],
        runner: Runner
    ) -> Outcome {
        let result = runner(source, arguments)
        if result.succeeded {
            let lines = parseLines(result.standardOutput)
            return .success(lines)
        }

        for sentinel in sentinels where result.standardError.contains(sentinel.marker) {
            return .failure(sentinel.reason)
        }
        return .failure(classify(result.standardError, timedOut: result.timedOut, exitCode: result.exitCode))
    }

    /// AppleScript 소스 — 인자는 `on run argv`에서만 읽는다
    enum scripts {
        static let newNote = """
        on run argv
            set noteTitle to item 1 of argv
            set noteBody to item 2 of argv
            tell application "Notes"
                set newNote to make new note with properties {name:noteTitle, body:noteBody}
                return name of newNote
            end tell
        end run
        """

        static let appendNote = """
        on run argv
            set targetName to item 1 of argv
            set extraText to item 2 of argv
            tell application "Notes"
                try
                    set targetNote to first note whose name is targetName
                on error
                    error "APEX_NOTE_NOT_FOUND" number 9101
                end try
                set body of targetNote to (body of targetNote) & "<br>" & extraText
                return name of targetNote
            end tell
        end run
        """

        static let showNote = """
        on run argv
            set targetName to item 1 of argv
            tell application "Notes"
                try
                    set targetNote to first note whose name is targetName
                on error
                    error "APEX_NOTE_NOT_FOUND" number 9101
                end try
                show targetNote
                return name of targetNote
            end tell
        end run
        """

        static let newNoteFolder = """
        on run argv
            set folderName to item 1 of argv
            tell application "Notes"
                set newFolder to make new folder with properties {name:folderName}
                return name of newFolder
            end tell
        end run
        """

        static let newReminder = """
        on run argv
            set reminderTitle to item 1 of argv
            set listName to item 2 of argv
            set noteText to item 3 of argv
            set dueOffset to (item 4 of argv) as integer
            tell application "Reminders"
                if listName is "" then
                    set targetList to default list
                else
                    try
                        set targetList to list listName
                    on error
                        error "APEX_LIST_NOT_FOUND" number 9102
                    end try
                end if
                tell targetList
                    set newReminder to make new reminder with properties {name:reminderTitle, body:noteText}
                    if dueOffset is greater than or equal to 0 then
                        set due date of newReminder to (current date) + dueOffset * minutes
                    end if
                    return id of newReminder as text
                end tell
            end tell
        end run
        """

        static let reminderLists = """
        on run argv
            set outText to ""
            tell application "Reminders"
                repeat with theList in lists
                    set outText to outText & (name of theList) & linefeed
                end repeat
            end tell
            return outText
        end run
        """

        static let newEvent = """
        on run argv
            set eventTitle to item 1 of argv
            set calendarName to item 2 of argv
            set startOffset to (item 3 of argv) as integer
            set durationMinutes to (item 4 of argv) as integer
            set eventLocation to item 5 of argv
            set eventNotes to item 6 of argv
            tell application "Calendar"
                if calendarName is "" then
                    set targetCalendar to first calendar
                else
                    try
                        set targetCalendar to calendar calendarName
                    on error
                        error "APEX_CALENDAR_NOT_FOUND" number 9103
                    end try
                end if
                set startDate to (current date) + startOffset * minutes
                set endDate to startDate + durationMinutes * minutes
                tell targetCalendar
                    set newEvent to make new event with properties {summary:eventTitle, start date:startDate, end date:endDate, location:eventLocation, description:eventNotes}
                    return summary of newEvent
                end tell
            end tell
        end run
        """

        static let calendarNames = """
        on run argv
            set outText to ""
            tell application "Calendar"
                repeat with theCalendar in calendars
                    set outText to outText & (name of theCalendar) & linefeed
                end repeat
            end tell
            return outText
        end run
        """
    }
}
