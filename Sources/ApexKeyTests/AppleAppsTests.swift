import XCTest
@testable import ApexKey

/// T-214 Apple 앱 1 — Notes·Reminders·Calendar 검증.
///
/// 실제 앱과 자동화 권한에 의존하지 않는다. `AppleApps.Runner`를 주입해
/// 인자 구성·성공 출력·실패 분류를 결정적으로 검사한다.
final class AppleAppsTests: XCTestCase {

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

    // MARK: - 순수 로직

    func testHTMLEscapesAndConvertsNewlines() {
        XCTAssertEqual(
            AppleApps.html(from: "a < b & c\n둘째 줄"),
            "a &lt; b &amp; c<br>둘째 줄"
        )
        XCTAssertEqual(AppleApps.html(from: "a\r\nb"), "a<br>b")
    }

    func testParseLinesTrimsAndDropsEmpty() {
        XCTAssertEqual(
            AppleApps.parseLines(" Work \n\nHome\n"),
            ["Work", "Home"]
        )
        XCTAssertTrue(AppleApps.parseLines("\n \n").isEmpty)
    }

    func testClassifyAutomationDenied() {
        XCTAssertEqual(
            AppleApps.classify("execution error: Not authorized to send Apple events (-1743)", timedOut: false, exitCode: 1),
            .automationDenied
        )
        XCTAssertEqual(
            AppleApps.classify("ApexKey is not allowed assistive access.", timedOut: false, exitCode: 1),
            .automationDenied
        )
    }

    func testClassifyTimeoutAndScriptError() {
        XCTAssertEqual(
            AppleApps.classify("", timedOut: true, exitCode: -1),
            .scriptFailed("timeout")
        )
        XCTAssertEqual(
            AppleApps.classify("execution error: something broke (-2700)", timedOut: false, exitCode: 1),
            .scriptFailed("execution error: something broke (-2700)")
        )
    }

    /// 인자는 반드시 argv로 넘긴다 — 소스에 보간하면 따옴표 하나로 스크립트가 깨진다
    func testScriptsReadArgumentsFromArgv() {
        let sources = [
            AppleApps.scripts.newNote,
            AppleApps.scripts.appendNote,
            AppleApps.scripts.showNote,
            AppleApps.scripts.newReminder,
            AppleApps.scripts.newEvent,
        ]
        for source in sources {
            XCTAssertTrue(source.contains("on run argv"), source)
            XCTAssertTrue(source.contains("item 1 of argv"), source)
        }
    }

    // MARK: - Notes

    func testCreateNoteRequiresTitle() {
        var called = false
        let outcome = AppleApps.createNote(title: "  ", body: "x") { _, _ in
            called = true
            return self.result()
        }
        XCTAssertEqual(outcome, .failure(.emptyTitle))
        XCTAssertFalse(called, "제목이 없으면 스크립트를 실행하지 않아야 함")
    }

    func testCreateNotePassesEscapedBodyAndReturnsName() {
        var captured: (String, [String])?
        let outcome = AppleApps.createNote(title: "회의", body: "a < b\n둘째") { source, arguments in
            captured = (source, arguments)
            return self.result(output: "회의")
        }

        XCTAssertEqual(outcome, .success(["회의"]))
        XCTAssertEqual(captured?.1, ["회의", "a &lt; b<br>둘째"])
        XCTAssertTrue(captured?.0.contains("tell application \"Notes\"") == true)
    }

    func testNoteAppendMapsSentinelToNotFound() {
        let outcome = AppleApps.noteAction(
            .append,
            title: "없는 메모",
            text: "x",
            folderName: ""
        ) { _, _ in
            self.result(exitCode: 1, error: "execution error: APEX_NOTE_NOT_FOUND (-9101)")
        }
        XCTAssertEqual(outcome, .failure(.noteNotFound("없는 메모")))
    }

    func testNoteCreateFolderRequiresFolderName() {
        let outcome = AppleApps.noteAction(
            .createFolder,
            title: "무시됨",
            text: "",
            folderName: " "
        ) { _, _ in
            XCTFail("이름이 없으면 실행하지 않아야 함")
            return self.result()
        }
        XCTAssertEqual(outcome, .failure(.emptyTitle))
    }

    func testNoteShowPassesTitle() {
        var arguments: [String]?
        let outcome = AppleApps.noteAction(
            .show,
            title: "할 일",
            text: "",
            folderName: ""
        ) { _, args in
            arguments = args
            return self.result(output: "할 일")
        }
        XCTAssertEqual(outcome, .success(["할 일"]))
        XCTAssertEqual(arguments, ["할 일"])
    }

    // MARK: - Reminders

    func testAddReminderDefaultsToNoDueDate() {
        var arguments: [String]?
        let outcome = AppleApps.addReminder(
            title: "우유 사기",
            listName: "장보기",
            notes: "저지방",
            dueOffsetMinutes: nil
        ) { _, args in
            arguments = args
            return self.result(output: "reminder-id")
        }
        XCTAssertEqual(outcome, .success(["reminder-id"]))
        XCTAssertEqual(arguments, ["우유 사기", "장보기", "저지방", "-1"])
    }

    func testAddReminderPassesDueOffset() {
        var arguments: [String]?
        _ = AppleApps.addReminder(
            title: "보고서",
            listName: "",
            notes: "",
            dueOffsetMinutes: 90
        ) { _, args in
            arguments = args
            return self.result(output: "id")
        }
        XCTAssertEqual(arguments?.last, "90")
    }

    func testReminderListMapsSentinel() {
        let outcome = AppleApps.addReminder(
            title: "x",
            listName: "없는 목록",
            notes: "",
            dueOffsetMinutes: nil
        ) { _, _ in
            self.result(exitCode: 1, error: "execution error: APEX_LIST_NOT_FOUND (-9102)")
        }
        XCTAssertEqual(outcome, .failure(.listNotFound("없는 목록")))
    }

    func testReminderListsParsesNames() {
        let outcome = AppleApps.reminderLists { _, _ in
            self.result(output: "Reminders\nWork\n")
        }
        XCTAssertEqual(outcome, .success(["Reminders", "Work"]))
    }

    // MARK: - Calendar

    func testAddEventRejectsNonPositiveDuration() {
        let outcome = AppleApps.addEvent(
            title: "회의",
            calendarName: "",
            startOffsetMinutes: 60,
            durationMinutes: 0,
            location: "",
            notes: ""
        ) { _, _ in
            XCTFail("길이가 0이면 실행하지 않아야 함")
            return self.result()
        }
        XCTAssertEqual(outcome, .failure(.invalidDuration))
    }

    func testAddEventPassesAllArguments() {
        var arguments: [String]?
        let outcome = AppleApps.addEvent(
            title: "점심",
            calendarName: "Work",
            startOffsetMinutes: 120,
            durationMinutes: 45,
            location: "회의실",
            notes: "메모"
        ) { _, args in
            arguments = args
            return self.result(output: "점심")
        }
        XCTAssertEqual(outcome, .success(["점심"]))
        XCTAssertEqual(arguments, ["점심", "Work", "120", "45", "회의실", "메모"])
    }

    func testAddEventMapsSentinel() {
        let outcome = AppleApps.addEvent(
            title: "x",
            calendarName: "없음",
            startOffsetMinutes: 0,
            durationMinutes: 30,
            location: "",
            notes: ""
        ) { _, _ in
            self.result(exitCode: 1, error: "execution error: APEX_CALENDAR_NOT_FOUND (-9103)")
        }
        XCTAssertEqual(outcome, .failure(.calendarNotFound("없음")))
    }

    func testCalendarNamesParsesNames() {
        let outcome = AppleApps.calendarNames { _, _ in
            self.result(output: "Home\nWork\n")
        }
        XCTAssertEqual(outcome, .success(["Home", "Work"]))
    }

    func testAutomationDeniedIsReported() {
        let outcome = AppleApps.calendarNames { _, _ in
            self.result(exitCode: 1, error: "Not authorized to send Apple events (-1743)")
        }
        XCTAssertEqual(outcome, .failure(.automationDenied))
    }

    // MARK: - 엔진 배선

    private func run(_ step: ShortcutStep) -> ExecutionEngine.Result {
        var context = UseModelExecutor.ExecutionContext()
        return ExecutionEngine.shared.execute(steps: [step], context: &context)
    }

    /// 4종이 "미구현" 토스트로 떨어지지 않는지 — 배선 누락 회귀 감지.
    /// 모두 제목이 비어 있으므로 실제 AppleScript는 실행되지 않는다.
    func testAppleAppActionsAreWiredIntoEngine() {
        let unimplemented = "toast.reason.unimplemented".localized
        let steps: [ShortcutStep] = [
            ShortcutStep(type: .createNote, target: "", title: ""),
            ShortcutStep(type: .noteActions, target: "", title: ""),
            ShortcutStep(type: .reminders, target: "", title: ""),
            ShortcutStep(type: .calendar, target: "", title: ""),
        ]
        for step in steps {
            let result = run(step)
            XCTAssertFalse(result.success, "\(step.type.rawValue) 는 제목 없이 실패해야 함")
            XCTAssertNotEqual(
                result.error,
                unimplemented,
                "\(step.type.rawValue) 가 엔진에 배선되지 않았다"
            )
        }
    }

    func testCalendarInvalidDurationIsWired() {
        let config = AppleAppConfig(title: "회의", durationMinutes: 0)
        let step = ShortcutStep(
            type: .calendar,
            target: "",
            title: "",
            actionParameters: config.encode()
        )
        let result = run(step)
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.error, "error.user.apple_invalid_duration".localized)
    }
}
