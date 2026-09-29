import XCTest
@testable import ApexKey

/// AI 3종 스텁 회귀 테스트 (PLAN_v0.21 T-143 / E-MAC-AI-9013)
///
/// 이전 구현은 FoundationModels를 호출하지 않으면서 `return true`를 반환했다.
/// - useModel: 입력 프롬프트를 그대로 출력 변수로 저장
/// - writingTool: "교정완료: {원문}" 같은 문자열 래핑
/// - imagePlayground: 512×512 단색 사각형에 프롬프트를 그린 플레이스홀더
/// 그 결과 "AI 결과처럼 보이는" 값이 후속 단계에 흘러가면서 단축어가 성공으로 보고되었다.
final class AIStubHonestyTests: XCTestCase {

    // MARK: - 가용성 판정

    /// 어떤 모델 타입도 `.available`을 반환하면 안 된다 (연동 미구현)
    func testNoModelTypeReportsAvailable() {
        for type in AIModelType.allCases {
            let availability = AIAvailabilityManager.shared.isAvailable(type)
            XCTAssertFalse(
                availability.isAvailable,
                "\(type.rawValue) 이 사용 가능으로 보고됨 — FoundationModels 연동이 없으므로 거짓"
            )
        }
    }

    /// "실행 시 선택"은 선택 UI가 없으므로 가용 불가여야 한다
    func testAskEachTimeIsNotAvailable() {
        let availability = AIAvailabilityManager.shared.isAvailable(.askEachTime)
        XCTAssertFalse(availability.isAvailable)
        if case .modelUnavailable = availability {
            // 기대 케이스
        } else {
            XCTFail("askEachTime은 .modelUnavailable이어야 함, 실제: \(availability)")
        }
    }

    /// 가용성 맵 전체가 가용 불가로 채워져야 한다
    func testAvailabilityMapHasNoAvailableEntry() {
        let map = AIAvailabilityManager.shared.availabilityMap
        XCTAssertEqual(map.count, AIModelType.allCases.count)
        for (type, availability) in map {
            XCTAssertFalse(availability.isAvailable, "\(type.rawValue) 가 사용 가능으로 보고됨")
        }
    }

    /// 가용성 사유 메시지가 비어 있지 않아야 한다 (빈 문자열로 사용자에게 아무것도 안 보여서는 안 됨)
    func testUnavailableReasonIsNotEmpty() {
        for type in AIModelType.allCases {
            let message = AIAvailabilityManager.shared.isAvailable(type).displayMessage
            XCTAssertFalse(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                           "\(type.rawValue) 의 안내 메시지가 비어 있음")
        }
    }

    // MARK: - 실행기는 성공을 반환하면 안 된다

    private func makeContext() -> UseModelExecutor.ExecutionContext {
        UseModelExecutor.ExecutionContext()
    }

    func testUseModelStepDoesNotFakeSuccess() {
        var step = ShortcutStep(type: .useModel, target: "", title: "테스트")
        step.useModel = UseModelStep(prompt: "안녕하세요", outputVariable: UUID())
        var context = makeContext()
        XCTAssertFalse(
            UseModelExecutor.shared.execute(step, context: &context),
            "미구현 AI 단계가 성공을 반환함 — 성공 둔팝 회귀"
        )
    }

    func testWritingToolStepDoesNotFakeSuccess() {
        var step = ShortcutStep(type: .writingTool, target: "", title: "테스트")
        let inputID = UUID()
        step.writingTool = WritingToolStep(action: .proofread, inputVariable: inputID, outputVariable: UUID())
        var context = makeContext()
        context.variables[inputID] = .text("이 문장에 오류가 있습니다")
        XCTAssertFalse(
            WritingToolExecutor.shared.execute(step, context: &context),
            "미구현 라이팅 툴이 성공을 반환함 — 성공 둔팝 회귀"
        )
    }

    func testImagePlaygroundStepDoesNotFakeSuccess() {
        var step = ShortcutStep(type: .imagePlayground, target: "", title: "테스트")
        step.imagePlayground = ImagePlaygroundStep(prompt: "고양이", outputVariable: UUID())
        var context = makeContext()
        XCTAssertFalse(
            ImagePlaygroundExecutor.shared.execute(step, context: &context),
            "미구현 이미지 생성이 성공을 반환함 — 성공 둔팝 회귀"
        )
    }

    /// 실패한 AI 단계가 출력 변수를 오염시키면 안 된다
    /// (이전 구현은 프롬프트/플레이스홀더를 변수에 넣어 후속 단계에 흘려보냈다)
    func testFailedAIStepDoesNotWriteOutputVariable() {
        let outputID = UUID()
        var step = ShortcutStep(type: .useModel, target: "", title: "테스트")
        step.useModel = UseModelStep(prompt: "이 값이 새면 안 된다", outputVariable: outputID)
        var context = makeContext()
        _ = UseModelExecutor.shared.execute(step, context: &context)
        XCTAssertNil(
            context.stepOutputs[outputID],
            "실패한 AI 단계가 출력 변수를 채웠음 — 후속 단계로 오염 전파"
        )
        XCTAssertNil(context.variables[outputID], "실패한 AI 단계가 변수를 오염시킴")
    }

    /// 이미지 생성 실패 시 임시 디렉터리에 파일을 남기지 않아야 한다
    /// (이전 구현이 플레이스홀더 PNG를 tmp에 기록했다)
    func testFailedImageStepLeavesNoTempFile() {
        let tmp = FileManager.default.temporaryDirectory
        let before = (try? FileManager.default.contentsOfDirectory(atPath: tmp.path))?
            .filter { $0.hasPrefix("apexkey_img_") }.count ?? 0

        var step = ShortcutStep(type: .imagePlayground, target: "", title: "테스트")
        step.imagePlayground = ImagePlaygroundStep(prompt: "고양이", outputVariable: UUID())
        var context = makeContext()
        _ = ImagePlaygroundExecutor.shared.execute(step, context: &context)

        let after = (try? FileManager.default.contentsOfDirectory(atPath: tmp.path))?
            .filter { $0.hasPrefix("apexkey_img_") }.count ?? 0
        XCTAssertEqual(after, before, "실패한 이미지 생성 단계가 임시 파일을 남김")
    }

    // MARK: - 엔진 경로 (ExecutionEngine)

    /// 워크플로우 단계로 실행해도 성공으로 보고되면 안 된다
    func testEngineReportsAIFailureAsFailure() {
        var step = ShortcutStep(type: .useModel, target: "", title: "테스트")
        step.useModel = UseModelStep(prompt: "프롬프트", outputVariable: UUID())
        let shortcut = ShortcutItem(id: UUID(), name: "AI 실패 확인", steps: [step])

        var context = makeContext()
        let result = ExecutionEngine.shared.execute(shortcut, context: &context)
        XCTAssertFalse(result.success, "AI 단계 실패가 워크플로우 성공으로 보고됨")
    }
}
