import Foundation

/// Apple Intelligence 모델 타입
enum AIModelType: String, Codable, CaseIterable, Identifiable {
    case onDevice = "onDevice"                    // 온디바이스 (로컬)
    case privateCloud = "privateCloud"            // Private Cloud Compute
    case chatGPT = "chatGPT"                      // ChatGPT Extension
    case askEachTime = "askEachTime"              // 실행 시마다 선택
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .onDevice: return "ai.provider.on_device".localized
        case .privateCloud: return "Private Cloud"
        case .chatGPT: return "ChatGPT"
        case .askEachTime: return "ai.provider.ask_each".localized
        }
    }
    
    var description: String {
        switch self {
        case .onDevice: return "ai.provider_desc_ond".localized
        case .privateCloud: return "ai.provider_desc_pcloud".localized
        case .chatGPT: return "ai.provider_desc_chatgpt".localized
        case .askEachTime: return "ai.provider_desc_ask_each".localized
        }
    }
    
    var systemImage: String {
        switch self {
        case .onDevice: return "cpu"
        case .privateCloud: return "cloud.fill"
        case .chatGPT: return "bubble.left.and.bubble.right.fill"
        case .askEachTime: return "questionmark.circle"
        }
    }
    
    var requiresNetwork: Bool {
        switch self {
        case .onDevice: return false
        case .privateCloud, .chatGPT: return true
        case .askEachTime: return true
        }
    }
    
    var minimumOSVersion: String {
        switch self {
        case .onDevice, .privateCloud: return "macOS 26.0"
        case .chatGPT: return "macOS 26.0"
        case .askEachTime: return "macOS 26.0"
        }
    }
    
    /// 가용성 체크용 식별자
    var availabilityKey: String {
        switch self {
        case .onDevice: return "SystemLanguageModel.default"
        case .privateCloud: return "SystemLanguageModel.default (Private Cloud)"
        case .chatGPT: return "ChatGPT Extension"
        case .askEachTime: return "N/A"
        }
    }
}

/// AI 출력 타입
enum AIOutputType: String, Codable, CaseIterable, Identifiable {
    case text = "text"                           // 일반 텍스트
    case dictionary = "dictionary"               // 구조화된 딕셔너리 (JSON)
    case list = "list"                           // 리스트/배열
    case boolean = "boolean"                     // 참/거짓
    case appEntity = "appEntity"                 // App Intents 엔티티
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .text: return "ui.text".localized
        case .dictionary: return "ai.output.dictionary".localized
        case .list: return "ai.output.list".localized
        case .boolean: return "ai.output.boolean".localized
        case .appEntity: return "ai.output.app_entity".localized
        }
    }
    
    var description: String {
        switch self {
        case .text: return "ai.output_desc_text".localized
        case .dictionary: return "ai.output_desc_dict".localized
        case .list: return "ai.output_desc_list".localized
        case .boolean: return "ai.output_desc_bool".localized
        case .appEntity: return "ai.output_desc_app_entity".localized
        }
    }
    
    var systemImage: String {
        switch self {
        case .text: return "text.alignleft"
        case .dictionary: return "curlybraces"
        case .list: return "list.bullet"
        case .boolean: return "checkmark.circle"
        case .appEntity: return "cube.box"
        }
    }
    
    /// 해당 타입으로 변환 가능한 VariableValueType
    var compatibleValueTypes: Set<VariableValueType> {
        switch self {
        case .text: return [.text]
        case .dictionary: return [.dictionary]
        case .list: return [.list]
        case .boolean: return [.boolean]
        case .appEntity: return [.dictionary, .any]
        }
    }
}

/// Use Model 액션 단계
struct UseModelStep: Identifiable, Codable, Hashable {
    var id: UUID
    var modelType: AIModelType
    var prompt: String                          // 프롬프트 (Magic Variable 포함 가능)
    var followUp: Bool                          // Follow Up 모드 (채팅형 다듬기)
    var outputType: AIOutputType
    var outputVariable: UUID                    // 결과 저장할 변수 ID
    var systemPrompt: String?                   // 시스템 프롬프트 (선택)
    var temperature: Double?                    // 0.0~1.0, nil이면 기본값
    var maxTokens: Int?                         // 최대 토큰 수, nil이면 기본값
    var stopSequences: [String]?                // 중단 시퀀스
    var label: String?                          // 사용자 정의 라벨
    
    init(
        id: UUID = UUID(),
        modelType: AIModelType = .onDevice,
        prompt: String = "",
        followUp: Bool = false,
        outputType: AIOutputType = .text,
        outputVariable: UUID,
        systemPrompt: String? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        stopSequences: [String]? = nil,
        label: String? = nil
    ) {
        self.id = id
        self.modelType = modelType
        self.prompt = prompt
        self.followUp = followUp
        self.outputType = outputType
        self.outputVariable = outputVariable
        self.systemPrompt = systemPrompt
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.stopSequences = stopSequences
        self.label = label
    }
    
    var displayName: String {
        label ?? "ai.display_model_use".localizedFormat(modelType.displayName, outputType.displayName)
    }
    
    /// 프롬프트에서 Magic Variable 토큰 추출
    var magicVariableTokens: [String] {
        let pattern = #"\{마법변수:([^:]+):([^}]+)\}"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: prompt.utf16.count)
        let matches = regex?.matches(in: prompt, options: [], range: range) ?? []
        return matches.compactMap { match in
            guard let range = Range(match.range(at: 0), in: prompt) else { return nil }
            return String(prompt[range])
        }
    }
    
    /// 프롬프트에서 Special Variable 토큰 추출
    var specialVariableTokens: [String] {
        let pattern = #"\{([a-zA-Z]+)\}"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: prompt.utf16.count)
        let matches = regex?.matches(in: prompt, options: [], range: range) ?? []
        return matches.compactMap { match in
            guard let range = Range(match.range(at: 0), in: prompt) else { return nil }
            return String(prompt[range])
        }.filter { token in
            SpecialVariable(rawValue: String(token.dropFirst().dropLast())) != nil
        }
    }
}

/// Apple Intelligence Writing Tools 액션
enum WritingToolAction: String, Codable, CaseIterable, Identifiable {
    case proofread = "proofread"           // 교정
    case rewrite = "rewrite"               // 다시 쓰기
    case summarize = "summarize"           // 요약
    case makeList = "makeList"             // 목록 만들기
    case makeTable = "makeTable"           // 표 만들기
    case changeTone = "changeTone"         // 톤 변경
    case keyPoints = "keyPoints"           // 핵심 포인트
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .proofread: return "ai.writing.proofread".localized
        case .rewrite: return "ai.writing.rewrite".localized
        case .summarize: return "ai.writing.summarize".localized
        case .makeList: return "ai.writing.make_list".localized
        case .makeTable: return "ai.writing.make_table".localized
        case .changeTone: return "ai.writing.change_tone".localized
        case .keyPoints: return "ai.writing.key_points".localized
        }
    }
    
    var description: String {
        switch self {
        case .proofread: return "ai.writing_desc_proofread".localized
        case .rewrite: return "ai.writing_desc_rewrite".localized
        case .summarize: return "ai.writing_desc_summarize".localized
        case .makeList: return "ai.writing_desc_make_list".localized
        case .makeTable: return "ai.writing_desc_make_table".localized
        case .changeTone: return "ai.writing_desc_change_tone".localized
        case .keyPoints: return "ai.writing_desc_key_points".localized
        }
    }
    
    var systemImage: String {
        switch self {
        case .proofread: return "checkmark.text.page"
        case .rewrite: return "arrow.triangle.2.circlepath.doc"
        case .summarize: return "doc.text.magnifyingglass"
        case .makeList: return "list.bullet.rectangle"
        case .makeTable: return "tablecells"
        case .changeTone: return "textformat.alt"
        case .keyPoints: return "highlighter"
        }
    }
    
    var defaultOutputType: AIOutputType {
        switch self {
        case .proofread, .rewrite, .changeTone: return .text
        case .summarize, .keyPoints: return .text
        case .makeList: return .list
        case .makeTable: return .dictionary
        }
    }
}

/// Writing Tools 단계
struct WritingToolStep: Identifiable, Codable, Hashable {
    var id: UUID
    var action: WritingToolAction
    var inputVariable: UUID              // 입력 텍스트 변수
    var outputVariable: UUID             // 결과 저장 변수
    var tone: WritingTone?               // .changeTone일 때만 사용
    var label: String?
    
    init(
        id: UUID = UUID(),
        action: WritingToolAction,
        inputVariable: UUID,
        outputVariable: UUID,
        tone: WritingTone? = nil,
        label: String? = nil
    ) {
        self.id = id
        self.action = action
        self.inputVariable = inputVariable
        self.outputVariable = outputVariable
        self.tone = tone
        self.label = label
    }
    
    var displayName: String {
        label ?? action.displayName
    }
}

/// Writing Tools 톤 옵션
enum WritingTone: String, Codable, CaseIterable, Identifiable {
    case professional = "professional"   // 전문적
    case friendly = "friendly"           // 친근함
    case concise = "concise"             // 간결함
    case casual = "casual"               // 캐주얼
    case formal = "formal"               // 격식
    case educational = "educational"     // 교육적
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .professional: return "ai.tone.professional".localized
        case .friendly: return "ai.tone.friendly".localized
        case .concise: return "ai.tone.concise".localized
        case .casual: return "ai.tone.casual".localized
        case .formal: return "ai.tone.formal".localized
        case .educational: return "ai.tone.educational".localized
        }
    }
}

/// Image Playground 액션 (이미지 생성)
struct ImagePlaygroundStep: Identifiable, Codable, Hashable {
    var id: UUID
    var prompt: String                   // 이미지 설명 프롬프트
    var style: ImagePlaygroundStyle
    var outputVariable: UUID             // 생성된 이미지 저장 변수
    var label: String?
    
    init(
        id: UUID = UUID(),
        prompt: String = "",
        style: ImagePlaygroundStyle = .animation,
        outputVariable: UUID,
        label: String? = nil
    ) {
        self.id = id
        self.prompt = prompt
        self.style = style
        self.outputVariable = outputVariable
        self.label = label
    }
    
    var displayName: String {
        label ?? "ai.display_image_style".localizedFormat(style.displayName)
    }
}

enum ImagePlaygroundStyle: String, Codable, CaseIterable, Identifiable {
    case animation = "animation"         // 애니메이션 스타일
    case illustration = "illustration"   // 일러스트 스타일
    case sketch = "sketch"               // 스케치 스타일
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .animation: return "ai.image.animation".localized
        case .illustration: return "ai.image.illustration".localized
        case .sketch: return "ai.image.sketch".localized
        }
    }
}

/// AI 액션 실행 결과
struct AIExecutionResult: Codable, Hashable {
    var success: Bool
    var output: VariableValue?
    var error: String?
    var modelUsed: AIModelType?
    var tokensUsed: Int?
    var followUpContext: AIFollowUpContext?
}

/// Follow Up 컨텍스트 (채팅형 연속 대화)
struct AIFollowUpContext: Codable, Hashable {
    var sessionID: UUID
    var conversationHistory: [AIMessage]
    var currentPrompt: String
    var awaitingResponse: Bool
    
    init(sessionID: UUID = UUID(), conversationHistory: [AIMessage] = [], currentPrompt: String = "", awaitingResponse: Bool = false) {
        self.sessionID = sessionID
        self.conversationHistory = conversationHistory
        self.currentPrompt = currentPrompt
        self.awaitingResponse = awaitingResponse
    }
}

/// AI 대화 메시지
struct AIMessage: Identifiable, Codable, Hashable {
    var id: UUID
    var role: AIMessageRole
    var content: String
    var timestamp: Date
    
    init(id: UUID = UUID(), role: AIMessageRole, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

enum AIMessageRole: String, Codable, CaseIterable {
    case system = "system"
    case user = "user"
    case assistant = "assistant"
    case tool = "tool"
}

/// AI 모델 가용성 상태
enum AIAvailability: Codable, Equatable {
    case available
    case unsupportedOS(requiredVersion: String)
    case appleIntelligenceDisabled
    case modelUnavailable(reason: String)
    case unknown
    
    var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }
    
    var displayMessage: String {
        switch self {
        case .available: return "ai.state_available".localized
        case .unsupportedOS(let version): return "ai.state_unsupported_os".localizedFormat(version)
        case .appleIntelligenceDisabled: return "ai.state_ai_disabled".localized
        case .modelUnavailable(let reason): return "ai.state_model_unavailable".localizedFormat(reason)
        case .unknown: return "ai.state_checking".localized
        }
    }
}

/// AI 실행 오류
enum AIError: Error, LocalizedError {
    case unsupportedOS
    case appleIntelligenceDisabled
    case modelNotAvailable(AIModelType)
    case promptEmpty
    case outputConversionFailed(AIOutputType)
    case followUpNotSupported
    case chatGPTNotSupported
    case networkError(Error)
    case timeout
    case cancelled
    case invalidResponse
    case tokenLimitExceeded
    case contentFiltered
    
    var errorDescription: String? {
        switch self {
        case .unsupportedOS: return "ai.error_unsupported_os".localized
        case .appleIntelligenceDisabled: return "ai.error_ai_disabled".localized
        case .modelNotAvailable(let type): return "ai.error_model_not_available".localizedFormat(type.displayName)
        case .promptEmpty: return "ai.error_prompt_empty".localized
        case .outputConversionFailed(let type): return "ai.error_output_conversion".localizedFormat(type.displayName)
        case .followUpNotSupported: return "ai.error_follow_up".localized
        case .chatGPTNotSupported: return "ai.error_chatgpt_ext".localized
        case .networkError(let e): return "ai.error_network".localizedFormat(e.localizedDescription)
        case .timeout: return "ai.error_timeout".localized
        case .cancelled: return "ai.error_cancelled".localized
        case .invalidResponse: return "ai.error_invalid_response".localized
        case .tokenLimitExceeded: return "ai.error_token_limit".localized
        case .contentFiltered: return "ai.error_content_filtered".localized
        }
    }
}

/// 프롬프트 템플릿 (자주 쓰는 프롬프트 저장)
struct PromptTemplate: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var category: PromptCategory
    var prompt: String
    var description: String
    var variables: [Variable]  // 프롬프트에서 사용할 변수들
    var isBuiltIn: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        category: PromptCategory,
        prompt: String,
        description: String = "",
        variables: [Variable] = [],
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.prompt = prompt
        self.description = description
        self.variables = variables
        self.isBuiltIn = isBuiltIn
    }
}

enum PromptCategory: String, Codable, CaseIterable, Identifiable {
    case general = "general"
    case coding = "coding"
    case writing = "writing"
    case analysis = "analysis"
    case translation = "translation"
    case summarization = "summarization"
    case creative = "creative"
    case custom = "custom"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .general: return "ui.step_settings.general".localized
        case .coding: return "ai.tool_coding".localized
        case .writing: return "ai.tool_writing".localized
        case .analysis: return "ai.tool_analysis".localized
        case .translation: return "ai.tool_translation".localized
        case .summarization: return "ai.writing.summarize".localized
        case .creative: return "ai.tool_creative".localized
        case .custom: return "ai.tool_custom".localized
        }
    }
    
    var systemImage: String {
        switch self {
        case .general: return "doc.text"
        case .coding: return "chevron.left.forwardslash.chevron.right"
        case .writing: return "pencil"
        case .analysis: return "chart.bar.doc.horizontal"
        case .translation: return "character.bubble"
        case .summarization: return "doc.text.magnifyingglass"
        case .creative: return "sparkles"
        case .custom: return "person.crop.circle"
        }
    }
}