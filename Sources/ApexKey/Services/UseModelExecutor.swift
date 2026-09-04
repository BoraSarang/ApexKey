import Foundation
import AppKit
import IOKit
#if canImport(CoreWLAN)
import CoreWLAN
#endif

/// "모델 사용" 액션 실행기
/// macOS 26+에서 FoundationModels를 사용하고, 그 외에는 폴백 처리
final class UseModelExecutor {
    static let shared = UseModelExecutor()
    
    private let availabilityManager = AIAvailabilityManager.shared
    
    /// 실행 컨텍스트 — 단계 간 변수 전달용
    struct ExecutionContext {
        var variables: [UUID: VariableValue] = [:]
        var stepOutputs: [UUID: VariableValue] = [:]  // Magic Variable용
        var lastOutput: VariableValue = .null
        var repeatIndex: Int? = nil
        var repeatItem: VariableValue = .null
        var shortcutInput: VariableValue = .null
        
        mutating func setOutput(_ value: VariableValue, for stepID: UUID) {
            stepOutputs[stepID] = value
            lastOutput = value
        }
        
        func resolveToken(_ token: String) -> VariableValue {
            // Magic Variable 토큰 파싱: {마법변수:stepID:variableName}
            let magicPattern = #"\{마법변수:([^:]+):([^}]+)\}"#
            if let regex = try? NSRegularExpression(pattern: magicPattern),
               let match = regex.firstMatch(in: token, range: NSRange(location: 0, length: token.utf16.count)),
               let stepIDRange = Range(match.range(at: 1), in: token) {
                let stepIDStr = String(token[stepIDRange])
                if let stepID = UUID(uuidString: stepIDStr) {
                    return stepOutputs[stepID] ?? .text(stepIDStr)
                }
            }
            
            // 특수 변수 토큰: {clipboard}, { currentDate}, etc.
            let specialPattern = #"\{([a-zA-Z]+)\}"#
            if let regex = try? NSRegularExpression(pattern: specialPattern),
               let match = regex.firstMatch(in: token, range: NSRange(location: 0, length: token.utf16.count)),
               let varRange = Range(match.range(at: 1), in: token) {
                let varName = String(token[varRange])
                if let special = SpecialVariable(rawValue: varName) {
                    return resolveSpecialVariable(special)
                }
            }
            
            // 일반 변수 ID
            if let uuid = UUID(uuidString: token) {
                return variables[uuid] ?? .text(token)
            }
            
            return .text(token)
        }
        
        private func resolveSpecialVariable(_ special: SpecialVariable) -> VariableValue {
            switch special {
            case .clipboard:
                return .text(NSPasteboard.general.string(forType: .string) ?? "")
            case .currentDate:
                return .date(Date())
            case .deviceName:
                return .text(Host.current().localizedName ?? "Mac")
            case .lastResult:
                return lastOutput
            case .repeatIndex:
                if let idx = repeatIndex { return .number(Double(idx)) }
                return .null
            case .repeatItem:
                return repeatItem
            case .shortcutInput:
                return shortcutInput
            case .askEachTime:
                return .null  // UI에서 별도 처리
            case .batteryLevel:
                return .number(VariableResolver.batteryLevel())
            case .wifiName:
                return .text(VariableResolver.getWiFiName() ?? "")
            }
        }
    }
    
    // MARK: - 메인 실행 메서드
    
    @discardableResult
    func execute(_ step: ShortcutStep, context: inout ExecutionContext) -> Bool {
        guard let useModel = step.useModel else {
            Logger.error("E-MAC-AI-9001", "UseModelExecutor: step에 useModel 설정이 없음 (stepID: \(step.id.uuidString.prefix(8)))")
            return false
        }
        
        Logger.info("UseModelExecutor", "실행 시작: \(useModel.displayName)")
        
        // 가용성 체크
        let availability = availabilityManager.isAvailable(useModel.modelType)
        guard availability.isAvailable else {
            Logger.error("E-MAC-AI-9001", "AI 모델 사용 불가: \(availability.displayMessage)")
            return false
        }
        
        // 프롬프트의 변수 토큰 해결
        let resolvedPrompt = resolvePromptTokens(useModel.prompt, context: context)
        
        // macOS 26+에서 FoundationModels 실행
        if #available(macOS 26.0, *) {
            return executeWithFoundationModels(
                useModel: useModel,
                resolvedPrompt: resolvedPrompt,
                context: &context
            )
        } else {
            Logger.error("E-MAC-AI-9002", "Apple Intelligence 사용 불가 (macOS \(ProcessInfo.processInfo.operatingSystemVersionString))")
            return false
        }
    }
    
    // MARK: - FoundationModels (macOS 26+)
    
    @available(macOS 26.0, *)
    private func executeWithFoundationModels(
        useModel: UseModelStep,
        resolvedPrompt: String,
        context: inout ExecutionContext
    ) -> Bool {
        // TODO: FoundationModels 프레임워크 실제 연동
        // 현재 프레임워크가 아직 완전히 공개되지 않았으므로 구조만 마련
        // 실제 구현 시:
        // 1. SystemLanguageModel.default 또는 .init(.init(overrides: [.init(name: "chatgpt")]))
        // 2. session = LanguageModelSession(model: model)
        // 3. let response = try await session.respond(to: resolvedPrompt)
        // 4. response.content → VariableValue 변환
        
        Logger.info("UseModelExecutor", "FoundationModels 실행 (모델: \(useModel.modelType.displayName))")
        
        // 임시: 프롬프트를 그대로 출력으로 반환 (폴백)
        let outputValue = convertToOutputType(
            text: resolvedPrompt,
            outputType: useModel.outputType
        )
        context.setOutput(outputValue, for: useModel.outputVariable)
        
        Logger.info("UseModelExecutor", "실행 완료: \(useModel.outputType.displayName) 출력")
        return true
    }
    
    // MARK: - 프롬프트 토큰 해결
    
    private func resolvePromptTokens(_ prompt: String, context: ExecutionContext) -> String {
        var resolveCtx = VariableResolver.ResolveContext()
        resolveCtx.variables = context.variables
        resolveCtx.stepOutputs = context.stepOutputs
        resolveCtx.lastOutput = context.lastOutput
        return VariableResolver.resolveText(prompt, context: resolveCtx)
    }
    
    // MARK: - 출력 타입 변환
    
    private func convertToOutputType(text: String, outputType: AIOutputType) -> VariableValue {
        switch outputType {
        case .text:
            return .text(text)
        case .dictionary:
            // JSON 파싱 시도
            if let data = text.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let dict = json.mapValues { val -> VariableValue in
                    if let str = val as? String { return .text(str) }
                    if let num = val as? Double { return .number(num) }
                    if let bool = val as? Bool { return .boolean(bool) }
                    if let arr = val as? [Any] { return .list(arr.map { VariableValue.text(String(describing: $0)) }) }
                    return .text(String(describing: val))
                }
                return .dictionary(dict)
            }
            // JSON이 아니면 딕셔너리로 감싸기
            return .dictionary(["text": .text(text)])
        case .list:
            // 줄바꿈으로 구분된 리스트로 변환
            let items = text.components(separatedBy: "\n").filter { !$0.isEmpty }
            return .list(items.map { .text($0) })
        case .boolean:
            let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let isTrue = lower == "true" || lower == "yes" || lower == "참" || lower == "예" || lower.hasPrefix("✓")
            return .boolean(isTrue)
        case .appEntity:
            return .text(text)
        }
    }
    
    // MARK: - Follow Up (채팅형)
    
    @discardableResult
    func executeFollowUp(
        step: ShortcutStep,
        context: inout ExecutionContext,
        conversationHistory: [AIMessage]
    ) -> Bool {
        guard let useModel = step.useModel else { return false }
        
        Logger.info("UseModelExecutor", "Follow Up 실행: \(conversationHistory.count)개 메시지")
        
        // 전체 대화 이력을 포함한 프롬프트 구성
        var fullPrompt = useModel.prompt + "\n\n---\n이전 대화:\n"
        for msg in conversationHistory {
            fullPrompt += "\(msg.role == .user ? "사용자" : "AI"): \(msg.content)\n"
        }
        
        // 단순화된 Follow Up → 새 프롬프트로 실행
        let followUpStep = UseModelStep(
            id: step.id,
            modelType: useModel.modelType,
            prompt: fullPrompt,
            followUp: false,
            outputType: useModel.outputType,
            outputVariable: useModel.outputVariable
        )
        var modifiedStep = step
        modifiedStep.useModel = followUpStep
        return execute(modifiedStep, context: &context)
    }
}
