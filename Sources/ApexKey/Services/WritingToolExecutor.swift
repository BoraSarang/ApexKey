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
        Logger.info("WritingToolExecutor", "FoundationModels 실행: \(writingTool.action.displayName)")
        
        // TODO: FoundationModels 프레임워크 실제 연동
        // Apple Shortcuts에서의 Writing Tools 흐름:
        // 1. SystemLanguageModel.default 사용
        // 2. 각 액션별 프롬프트 구성
        // 3. session.respond(to:) 호출
        // 4. 결과를 출력 변수에 저장
        
        // 임시: 규칙 기반 처리 (FoundationModels 연동 전까지)
        let result = processLocally(action: writingTool.action, inputText: inputText, tone: writingTool.tone)
        context.setOutput(result, for: writingTool.outputVariable)
        
        Logger.info("WritingToolExecutor", "실행 완료: \(writingTool.action.displayName)")
        return true
    }
    
    // MARK: - 로컬 처리 (폴백)
    
    private func processLocally(action: WritingToolAction, inputText: String, tone: WritingTone?) -> VariableValue {
        switch action {
        case .proofread:
            return .text("[교정 결과] \(inputText)")
        case .rewrite:
            return .text("[다시쓰기] \(inputText)")
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
        case .professional: return "[전문적]\n"
        case .friendly: return "[친근한]\n"
        case .concise: return "[간결한]\n"
        case .casual: return "[캐주얼한]\n"
        case .formal: return "[격식 있는]\n"
        case .educational: return "[교육적인]\n"
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
