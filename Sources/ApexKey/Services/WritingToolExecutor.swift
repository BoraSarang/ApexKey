import Foundation

/// 라이팅 툴 액션 실행기
final class WritingToolExecutor {
    static let shared = WritingToolExecutor()
    
    private let availabilityManager = AIAvailabilityManager.shared
    
    /// 라이팅 툴 실행
    @discardableResult
    func execute(_ step: ShortcutStep, context: inout UseModelExecutor.ExecutionContext) -> Bool {
        guard let writingTool = step.writingTool else {
            Logger.error("E-MAC-AI-9010", "WritingToolExecutor: step에 writingTool 설정이 없음")
            return false
        }
        
        Logger.info("WritingToolExecutor", "실행 시작: \(writingTool.displayName)")
        
        // 가용성 체크
        let availability = availabilityManager.isAvailable(.onDevice)
        guard availability.isAvailable else {
            Logger.error("E-MAC-AI-9010", "라이팅 툴 사용 불가: \(availability.displayMessage)")
            return false
        }
        
        // 입력 변수에서 텍스트 가져오기
        let inputText = getInputText(from: writingTool.inputVariable, context: context)
        guard !inputText.isEmpty else {
            Logger.error("E-MAC-AI-9011", "라이팅 툴 입력이 비어있음 (변수ID: \(writingTool.inputVariable.uuidString.prefix(8)))")
            return false
        }
        
        // macOS 26+에서 FoundationModels 실행
        if #available(macOS 26.0, *) {
            return executeWithFoundationModels(
                writingTool: writingTool,
                inputText: inputText,
                context: &context
            )
        } else {
            Logger.error("E-MAC-AI-9012", "Apple Intelligence 사용 불가")
            return false
        }
    }
    
    // MARK: - FoundationModels (macOS 26+)
    
    @available(macOS 26.0, *)
    private func executeWithFoundationModels(
        writingTool: WritingToolStep,
        inputText: String,
        context: inout UseModelExecutor.ExecutionContext
    ) -> Bool {
        // E-MAC-AI-9013: FoundationModels 프레임워크 연동이 아직 구현되지 않았다.
        // 이전 구현은 processLocally()로 "교정완료: {원문}" 같은 문자열 래핑을 만들어
        // 출력 변수를 채우고 `return true`를 해 실제 교정 없이 성공을 보고했다.
        //
        // TODO(PLAN_v0.21 T-143 후속):
        // 1. SystemLanguageModel.default 사용
        // 2. 각 액션별 프롬프트 구성
        // 3. session.respond(to:) 호출
        // 4. 결과를 출력 변수에 저장
        Logger.error("E-MAC-AI-9013", "FoundationModels 연동 미구현 — 라이팅 툴 단계 실패 처리: \(writingTool.action.displayName)")
        return false
    }

    // MARK: - 로컬 처리 (미구현 상태에서는 호출되지 않음)
    //
    // 아래 헬퍼는 AI 연동 없이도 "결과처럼 보이는" 문자열을 만들 수 있어 위험하다.
    // E-MAC-AI-9013에서 execute 경로에서 제거했으며, 후속 AI 구현 시
    // 별도 "정리/압축" 전용 로컬 처리로 재활용할 수 있도록 보존한다.

    /// 로컬 규칙 기반 처리 — **AI 결과가 아니므로 AI 단계의 성공 경로에서 호출 금지**
    private func processLocally(action: WritingToolAction, inputText: String, tone: WritingTone?) -> VariableValue {
        switch action {
        case .proofread:
            return .text("ai.writing.result_proofread_fmt".localizedFormat(inputText))
        case .rewrite:
            return .text("ai.writing.result_rewrite_fmt".localizedFormat(inputText))
        case .summarize:
            let sentences = inputText.components(separatedBy: CharacterSet(charactersIn: ".!?\n")).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let summary = sentences.prefix(3).joined(separator: ". ")
            return .text(summary.isEmpty ? inputText : summary + ".")
        case .makeList:
            let items = inputText.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            return .list(items.map { .text($0) })
        case .makeTable:
            // 간단한 테이블 변환
            let rows = inputText.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            var dict: [String: VariableValue] = [:]
            for (index, row) in rows.enumerated() {
                dict["row_\(index)"] = .text(row)
            }
            return .dictionary(dict)
        case .changeTone:
            let prefix = mapToneToPrefix(tone)
            return .text("\(prefix)\(inputText)")
        case .keyPoints:
            let sentences = inputText.components(separatedBy: CharacterSet(charactersIn: ".!\n")).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let keyPoints = sentences.prefix(5).map { "• \($0.trimmingCharacters(in: .whitespaces))" }
            return .text(keyPoints.joined(separator: "\n"))
        }
    }
    
    private func mapToneToPrefix(_ tone: WritingTone?) -> String {
        guard let tone = tone else { return "" }
        switch tone {
        case .professional: return "ai.tone.code_professional".localized
        case .friendly: return "ai.tone.code_friendly".localized
        case .concise: return "ai.tone.code_concise".localized
        case .casual: return "ai.tone.code_casual".localized
        case .formal: return "ai.tone.code_formal".localized
        case .educational: return "ai.tone.code_educational".localized
        }
    }
    
    // MARK: - 입력 텍스트 가져오기
    
    private func getInputText(from variableID: UUID, context: UseModelExecutor.ExecutionContext) -> String {
        if let value = context.stepOutputs[variableID] {
            return value.asText ?? ""
        }
        if let value = context.variables[variableID] {
            return value.asText ?? ""
        }
        // 마지막 출력에서 가져오기
        return context.lastOutput.asText ?? ""
    }
}
