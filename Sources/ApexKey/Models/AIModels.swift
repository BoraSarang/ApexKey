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
        case .onDevice: return "온디바이스"
        case .privateCloud: return "Private Cloud"
        case .chatGPT: return "ChatGPT"
        case .askEachTime: return "매번 선택"
        }
    }
    
    var description: String {
        switch self {
        case .onDevice: return "인터넷 없이 기기에서 실행, 간단한 작업에 적합"
        case .privateCloud: return "애플 서버에서 처리, 복잡한 작업에 적합, 프라이버시 보호"
        case .chatGPT: return "ChatGPT 활용, 광범위한 지식, 외부 서비스 연동"
        case .askEachTime: return "실행할 때마다 모델을 직접 선택"
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
        case .text: return "텍스트"
        case .dictionary: return "딕셔너리"
        case .list: return "리스트"
        case .boolean: return "참/거짓"
        case .appEntity: return "앱 엔티티"
        }
    }
    
    var description: String {
        switch self {
        case .text: return "자연어 응답, 후속 텍스트 처리에 적합"
        case .dictionary: return "키-값 쌍 구조, JSON 파싱 가능"
        case .list: return "항목 나열, Repeat with Each와 연동"
        case .boolean: return "예/아니오 판단, If 조건에 직접 사용"
        case .appEntity: return "앱 데이터 엔티티, Find 액션 결과 등"
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
        label ?? "모델 사용 (\(modelType.displayName) → \(outputType.displayName))"
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
        case .proofread: return "교정"
        case .rewrite: return "다시 쓰기"
        case .summarize: return "요약"
        case .makeList: return "목록 만들기"
        case .makeTable: return "표 만들기"
        case .changeTone: return "톤 변경"
        case .keyPoints: return "핵심 포인트"
        }
    }
    
    var description: String {
        switch self {
        case .proofread: return "맞춤법, 문법, 구두점을 교정합니다"
        case .rewrite: return "텍스트를 다른 스타일로 다시 씁니다"
        case .summarize: return "긴 텍스트를 요약합니다"
        case .makeList: return "텍스트에서 목록을 추출합니다"
        case .makeTable: return "텍스트에서 표를 생성합니다"
        case .changeTone: return "텍스트의 어조를 변경합니다 (전문적, 친근, 간결 등)"
        case .keyPoints: return "텍스트의 핵심 내용을 추출합니다"
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
        case .professional: return "전문적"
        case .friendly: return "친근함"
        case .concise: return "간결함"
        case .casual: return "캐주얼"
        case .formal: return "격식"
        case .educational: return "교육적"
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
        label ?? "이미지 생성 (\(style.displayName))"
    }
}

enum ImagePlaygroundStyle: String, Codable, CaseIterable, Identifiable {
    case animation = "animation"         // 애니메이션 스타일
    case illustration = "illustration"   // 일러스트 스타일
    case sketch = "sketch"               // 스케치 스타일
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .animation: return "애니메이션"
        case .illustration: return "일러스트"
        case .sketch: return "스케치"
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
        case .available: return "사용 가능"
        case .unsupportedOS(let version): return "macOS \(version) 이상 필요"
        case .appleIntelligenceDisabled: return "Apple Intelligence가 비활성화됨 (시스템 설정에서 활성화)"
        case .modelUnavailable(let reason): return "모델 사용 불가: \(reason)"
        case .unknown: return "상태 확인 중..."
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
        case .unsupportedOS: return "이 기능은 macOS 26 (Tahoe) 이상에서만 사용 가능합니다"
        case .appleIntelligenceDisabled: return "Apple Intelligence가 활성화되지 않았습니다. 시스템 설정 > Apple Intelligence에서 켜주세요"
        case .modelNotAvailable(let type): return "\(type.displayName) 모델을 사용할 수 없습니다"
        case .promptEmpty: return "프롬프트가 비어있습니다"
        case .outputConversionFailed(let type): return "응답을 \(type.displayName) 타입으로 변환할 수 없습니다"
        case .followUpNotSupported: return "Follow Up 모드는 현재 지원되지 않습니다"
        case .chatGPTNotSupported: return "ChatGPT Extension이 설치되지 않았습니다"
        case .networkError(let e): return "네트워크 오류: \(e.localizedDescription)"
        case .timeout: return "응답 시간이 초과되었습니다"
        case .cancelled: return "사용자에 의해 취소되었습니다"
        case .invalidResponse: return "유효하지 않은 응답입니다"
        case .tokenLimitExceeded: return "토큰 한도를 초과했습니다"
        case .contentFiltered: return "콘텐츠 필터에 의해 차단되었습니다"
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
        case .general: return "일반"
        case .coding: return "코딩"
        case .writing: return "글쓰기"
        case .analysis: return "분석"
        case .translation: return "번역"
        case .summarization: return "요약"
        case .creative: return "창작"
        case .custom: return "사용자 정의"
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