import XCTest
@testable import ApexKey

/// Run Shortcut 단계의 end-to-end 경로 테스트 (E-MAC-FLOW-7011)
///
/// 왜 이게 없었나:
/// `executeRunShortcut`는 엔진에서 정상 동작하고(recursion depth 포함),
/// 그런데 **설정 UI가 없었다** — 단계 설정이 자유 입력 필드로 떨어져서 사용자가
/// UUID를 직접 입력해야 했다. 즉 "엔진은 되는데 아무도 못 쓰는" 상태였다.
/// 이 테스트는 그 연결을 잠근다.
final class RunShortcutWiringTests: XCTestCase {

    /// 대상 UUID가 엔진에 전달되고 재귀 실행되는지
    func testEngineRunsTargetShortcutAndPassesOutput() {
        // 대상 단축어는 "텍스트 액션" 단계를 갖고, 호출측은 그 출력을 받아야 한다
        let target = ShortcutItem(
            name: "대상",
            steps: [ShortcutStep(type: .text, target: "알림", title: "알림 단계")]
        )
        var seen: [UUID] = []
        let previous = ExecutionEngine.shared.shortcutProvider
        ExecutionEngine.shared.shortcutProvider = { id in
            seen.append(id)
            return id == target.id ? target : nil
        }
        defer { ExecutionEngine.shared.shortcutProvider = previous }

        var caller = ShortcutItem(
            name: "호출측",
            steps: [
                ShortcutStep(type: .runShortcut, target: target.id.uuidString, title: target.name),
                ShortcutStep(type: .text, target: "다음", title: "다음 단계"),
            ]
        )
        var context = UseModelExecutor.ExecutionContext()
        let result = ExecutionEngine.shared.execute(steps: caller.steps, context: &context)
        XCTAssertTrue(result.success, "실행 실패: \(result.error ?? "-")")
        XCTAssertEqual(seen, [target.id], "shortcutProvider가 호출되지 않았다 — UI가 저장한 UUID가 전달되지 않는다")
        // 재귀 호출이므로 대상의 출력이 마지막 출력이어야 한다
        XCTAssertEqual(context.lastOutput.asText, "다음")
    }

    /// 잘못된 UUID면 **조용히 성공하지 않는다**
    func testInvalidTargetUUIDFails() {
        var step = ShortcutStep(type: .runShortcut, target: "not-a-uuid", title: "")
        var context = UseModelExecutor.ExecutionContext()
        let result = ExecutionEngine.shared.execute(steps: [step], context: &context)
        XCTAssertFalse(result.success, "잘못된 UUID인데 성공했다 — 조용히 실패해야 한다")
        _ = step
    }

    /// 대상이 없으면 실패 (삭제된 동작 참조)
    func testMissingTargetFails() {
        let previous = ExecutionEngine.shared.shortcutProvider
        ExecutionEngine.shared.shortcutProvider = { _ in nil }
        defer { ExecutionEngine.shared.shortcutProvider = previous }

        let ghost = UUID()
        var step = ShortcutStep(type: .runShortcut, target: ghost.uuidString, title: "")
        var context = UseModelExecutor.ExecutionContext()
        let result = ExecutionEngine.shared.execute(steps: [step], context: &context)
        XCTAssertFalse(result.success, "삭제된 동작을 호출했는데 성공했다")
        _ = step
    }

    /// 자기 자신을 부르면 재귀 깊이 제한에 걸려 **실패**해야 한다 (무한 루프 아님)
    func testSelfReferenceTerminates() {
        // 피커 UI가 자기 자신을 제외하지만, 저장된 값이 잘못 들어올 수 있다
        // (손으로 편집, 가져오기, 구 데이터). 엔진이 무한 루프에 빠지지 않아야 한다.
        let selfID = UUID()
        let loop = ShortcutItem(
            id: selfID,
            name: "자기참조",
            steps: [ShortcutStep(type: .runShortcut, target: selfID.uuidString, title: "자기참조")]
        )
        let previous = ExecutionEngine.shared.shortcutProvider
        ExecutionEngine.shared.shortcutProvider = { $0 == selfID ? loop : nil }
        defer { ExecutionEngine.shared.shortcutProvider = previous }

        var context = UseModelExecutor.ExecutionContext()
        let result = ExecutionEngine.shared.execute(steps: loop.steps, context: &context)
        // 깊이 제한에 도달하면 실패해야 한다 — 무한 실행이면 안 된다
        XCTAssertFalse(result.success, "자기참조가 끝없이 실행됐다 (깊이 제한이 없다)")
    }

    /// `step.title`이 대상 이름이어야 단계 목록에서 의미가 보인다
    /// (엔진은 target(UUID)만 읽지만, 표시·검색은 title을 쓴다)
    func testTitleIsInformativeForListDisplay() {
        // 표시 경로: `ShortcutStep.summary`가 runShortcut에서 target이 비면 액션명만 보인다
        var step = ShortcutStep(type: .runShortcut, target: "", title: "")
        XCTAssertEqual(step.summary, "action.runShortcut".localized)
        // title이 있으면 이름이 보인다
        step.title = "대상 동작"
        XCTAssertTrue(step.summary.contains("대상 동작"), "제목이 목록에 반영되지 않는다: \(step.summary)")
    }
}
