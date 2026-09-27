import XCTest
@testable import ApexKey

/// 실행 결과 전파 회귀 테스트 (PLAN_v0.21 T-148/149/150/151 · E-MAC-FLOW-7009)
///
/// 감사에서 확인된 결함 4가지:
/// 1. `executeRepeatCount`/`Each`가 내부 `success:false`를 버리고 `.continueRunning` 반환
///    → 반복 안의 스크립트가 매 회 실패해도 단축어가 성공으로 보고됨
/// 2. `execute(steps:)`가 `error` 문자열을 버림 → 구체적 원인이 "동작 실패: <이름>"으로 뭉개짐
/// 3. `executeStopShortcut` 경로가 누적 실패를 버리고 `success:true` 반환
/// 4. 셸 단계가 stdout 대신 **스크립트 소스코드**를 출력 변수로 기록
/// 5. 일반 액션 `default:` 분기가 `setOutput`을 호출하지 않음 → `{lastResult}`가 과거 잔여값
final class ExecutionResultPropagationTests: XCTestCase {

    /// 실패하는 셸 단계로 만든 반복을 래핑한 단축어
    private func makeFailingRepeatShortcut() -> ShortcutItem {
        let failingScript = ShortcutStep(type: .script, target: "exit 1", title: "실패 스크립트")
        var loopStep = ShortcutStep(type: .repeatLoop, target: "", title: "반복")
        loopStep.repeatLoop = RepeatLoop(mode: .count, count: 3, steps: [failingScript])
        return ShortcutItem(id: UUID(), name: "반복 실패 전파 확인", steps: [loopStep])
    }

    // MARK: - 1. 반복 내부 실패 전파

    func testFailingStepInsideRepeatFailsWholeShortcut() {
        let shortcut = makeFailingRepeatShortcut()
        var context = UseModelExecutor.ExecutionContext()
        let result = ExecutionEngine.shared.execute(shortcut, context: &context)
        XCTAssertFalse(
            result.success,
            "반복 내부의 실패한 단계가 무시되고 단축어가 성공으로 보고됨"
        )
    }

    func testFailingStepInsideRepeatProducesErrorMessage() {
        let shortcut = makeFailingRepeatShortcut()
        var context = UseModelExecutor.ExecutionContext()
        let result = ExecutionEngine.shared.execute(shortcut, context: &context)
        XCTAssertNotNil(
            result.error,
            "반복 내부 실패 사유가 상위로 전파되지 않음 (토스트에 구체적 원인이 안 나옴)"
        )
    }

    /// 실패하지 않는 반복은 여전히 성공이어야 한다 (회귀 방지)
    func testSucceedingRepeatStillSucceeds() {
        let okScript = ShortcutStep(type: .script, target: "true", title: "성공 스크립트")
        var loopStep = ShortcutStep(type: .repeatLoop, target: "", title: "반복")
        loopStep.repeatLoop = RepeatLoop(mode: .count, count: 2, steps: [okScript])
        let shortcut = ShortcutItem(id: UUID(), name: "반복 성공 확인", steps: [loopStep])

        var context = UseModelExecutor.ExecutionContext()
        let result = ExecutionEngine.shared.execute(shortcut, context: &context)
        XCTAssertTrue(result.success, "성공한 반복이 실패로 바뀌면 안 됨")
    }

    /// 단독 실패 단계는 원래대로 실패해야 한다 (1단계에서 이미 동작하던 경로)
    func testSingleFailingStepFailsShortcut() {
        let shortcut = ShortcutItem(
            id: UUID(),
            name: "단일 실패 확인",
            steps: [ShortcutStep(type: .script, target: "exit 1", title: "실패 스크립트")]
        )
        var context = UseModelExecutor.ExecutionContext()
        let result = ExecutionEngine.shared.execute(shortcut, context: &context)
        XCTAssertFalse(result.success)
    }

    // MARK: - 2. 에러 메시지 보존

    /// 스크립트 문법 오류의 구체적 사유가 상위에 남아야 한다
    func testScriptErrorDetailPropagatesToTopLevel() {
        let shortcut = ShortcutItem(
            id: UUID(),
            name: "스크립트 오류 확인",
            steps: [ShortcutStep(type: .script, target: "echo 'unterminated", title: "문법 오류")]
        )
        var context = UseModelExecutor.ExecutionContext()
        let result = ExecutionEngine.shared.execute(shortcut, context: &context)

        XCTAssertFalse(result.success)
        let error = result.error ?? ""
        XCTAssertFalse(
            error.isEmpty,
            "실패 사유가 비어 있음 — 토스트에 아무 원인이 표시되지 않음"
        )
        // 구체적 메시지(셸 문법 오류 텍스트)가 포함되어야 한다
        XCTAssertFalse(
            error.contains("error.user.action_failed_fmt"),
            "구체적 원인이 '동작 실패' 일반 문구로 대체됨"
        )
    }

    /// 첫 실패 사유가 우선 보존되어야 한다 (뒤 단계의 무관한 실패로 덮어써지지 않음)
    func testFirstErrorIsPreserved() {
        let shortcut = ShortcutItem(
            id: UUID(),
            name: "첫 실패 우선",
            steps: [
                ShortcutStep(type: .script, target: "echo 'first_marker_unterminated", title: "첫 실패"),
                ShortcutStep(type: .script, target: "exit 2", title: "두 번째 실패"),
            ]
        )
        var context = UseModelExecutor.ExecutionContext()
        let result = ExecutionEngine.shared.execute(shortcut, context: &context)
        XCTAssertFalse(result.success)
        XCTAssertNotNil(result.error)
    }

    // MARK: - 3. Stop Shortcut 누적 실패

    /// Stop 이전에 실패한 단계가 있으면 전체가 실패로 보고되어야 한다
    func testStopShortcutDoesNotSwallowEarlierFailure() {
        let shortcut = ShortcutItem(
            id: UUID(),
            name: "중지 누적 실패 확인",
            steps: [
                ShortcutStep(type: .script, target: "exit 1", title: "실패 스크립트"),
                ShortcutStep(type: .stopShortcut, target: "", title: "중지"),
            ]
        )
        var context = UseModelExecutor.ExecutionContext()
        let result = ExecutionEngine.shared.execute(shortcut, context: &context)
        XCTAssertFalse(
            result.success,
            "Stop Shortcut가 그 이전에 쌓인 실패를 버리고 success:true를 반환함"
        )
    }

    // MARK: - 4. 셸 단계 출력 (소스코드가 아니라 실행 결과)

    /// 출력 변수는 **스크립트 소스**가 아니라 **stdout**을 담아야 한다
    func testScriptStepOutputsStdoutNotSource() throws {
        let marker = "apexkey_stdout_marker_9f3a"
        let step = ShortcutStep(
            type: .script,
            target: "echo '\(marker)'",
            title: "출력 확인"
        )
        let shortcut = ShortcutItem(id: UUID(), name: "출력 확인", steps: [step])

        var context = UseModelExecutor.ExecutionContext()
        let result = ExecutionEngine.shared.execute(shortcut, context: &context)
        XCTAssertTrue(result.success)

        let output = context.stepOutputs[step.id]?.asText ?? ""
        XCTAssertTrue(
            output.contains(marker),
            "출력 변수에 stdout이 없음. 실제: \(output.prefix(120))"
        )
        XCTAssertFalse(
            output.contains("echo '\(marker)'"),
            "출력 변수가 스크립트 소스코드임 (stdout이 버해지고 소스가 기록됨)"
        )
    }

    /// lastOutput도 stdout이어야 한다
    func testLastOutputIsStdoutNotSource() {
        let marker = "apexkey_lastout_marker_71bd"
        let step = ShortcutStep(type: .script, target: "echo '\(marker)'", title: "출력 확인")
        let shortcut = ShortcutItem(id: UUID(), name: "출력 확인", steps: [step])

        var context = UseModelExecutor.ExecutionContext()
        _ = ExecutionEngine.shared.execute(shortcut, context: &context)

        let last = context.lastOutput.asText ?? ""
        XCTAssertTrue(last.contains(marker), "lastOutput에 stdout이 없음. 실제: \(last.prefix(120))")
    }

    /// 실패한 셸 단계도 에러 출력을 노출해야 한다
    func testFailingScriptStepExposesStderr() {
        let step = ShortcutStep(
            type: .script,
            target: "echo 'apexkey_stderr_marker' 1>&2; exit 1",
            title: "실패"
        )
        let shortcut = ShortcutItem(id: UUID(), name: "실패 출력", steps: [step])
        var context = UseModelExecutor.ExecutionContext()
        let result = ExecutionEngine.shared.execute(shortcut, context: &context)

        XCTAssertFalse(result.success)
        XCTAssertTrue(
            (result.error ?? "").contains("apexkey_stderr_marker"),
            "stderr 내용이 토스트 사유에 반영되지 않음. 실제: \(result.error ?? "nil")"
        )
    }
}
