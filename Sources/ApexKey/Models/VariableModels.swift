import Foundation

/// 변수 타입 분류
enum VariableType: String, Codable, CaseIterable, Identifiable {
    case magic      // 이전 단계 출력 (자동 생성, 파란 알약 UI)
    case special    // 시스템 특수 변수 (매번 묻기, 클립보드, 현재 날짜 등)
    case manual     // 사용자 정의 변수 (변수 설정/가져오기 액션으로 관리)
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .magic: return "마법 변수"
        case .special: return "특수 변수"
        case .manual: return "사용자 변수"
        }
    }
    
    var systemImage: String {
        switch self {
        case .magic: return "wand.and.stars"
        case .special: return "star.fill"
        case .manual: return "text.cursor"
        }
    }
    
    var color: String {
        switch self {
        case .magic: return "#007AFF"      // 파랑
        case .special: return "#FF9500"    // 주황
        case .manual: return "#34C759"     // 초록
        }
    }
}

/// 특수 변수 종류 (시스템 제공)
enum SpecialVariable: String, Codable, CaseIterable, Identifiable {
    case askEachTime = "askEachTime"           // 매번 묻기
    case clipboard = "clipboard"               // 클립보드
    case currentDate = "currentDate"           // 현재 날짜/시간
    case shortcutInput = "shortcutInput"       // 단축어 입력
    case repeatIndex = "repeatIndex"           // 반복 인덱스 (1부터 시작)
    case repeatItem = "repeatItem"             // 반복 현재 항목
    case lastResult = "lastResult"             // 마지막 단계 결과
    case deviceName = "deviceName"             // 기기 이름
    case batteryLevel = "batteryLevel"         // 배터리 잔량
    case wifiName = "wifiName"                 // 연결된 Wi-Fi 이름
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .askEachTime: return "매번 묻기"
        case .clipboard: return "클립보드"
        case .currentDate: return "현재 날짜"
        case .shortcutInput: return "단축어 입력"
        case .repeatIndex: return "반복 인덱스"
        case .repeatItem: return "반복 항목"
        case .lastResult: return "마지막 결과"
        case .deviceName: return "기기 이름"
        case .batteryLevel: return "배터리 잔량"
        case .wifiName: return "Wi-Fi 이름"
        }
    }
    
    var description: String {
        switch self {
        case .askEachTime: return "실행할 때마다 값을 입력받습니다"
        case .clipboard: return "현재 클립보드 내용을 가져옵니다"
        case .currentDate: return "현재 날짜와 시간을 가져옵니다"
        case .shortcutInput: return "단축어 실행 시 전달받은 입력을 사용합니다"
        case .repeatIndex: return "현재 반복 횟수 (1부터 시작)"
        case .repeatItem: return "현재 반복 중인 항목"
        case .lastResult: return "직전 단계의 실행 결과"
        case .deviceName: return "이 Mac의 이름"
        case .batteryLevel: return "현재 배터리 충전 수준 (0.0~1.0)"
        case .wifiName: return "현재 연결된 Wi-Fi 네트워크 이름"
        }
    }
    
    var systemImage: String {
        switch self {
        case .askEachTime: return "questionmark.circle"
        case .clipboard: return "doc.on.clipboard"
        case .currentDate: return "calendar"
        case .shortcutInput: return "arrow.down.doc"
        case .repeatIndex: return "number.circle"
        case .repeatItem: return "list.bullet"
        case .lastResult: return "arrow.uturn.left"
        case .deviceName: return "desktopcomputer"
        case .batteryLevel: return "battery.100"
        case .wifiName: return "wifi"
        }
    }
    
    /// 토큰 문자열 (텍스트 필드에 삽입될 형태)
    var tokenString: String {
        return "{\(rawValue)}"
    }
    
    /// 출력 타입 힌트
    var outputTypeHint: VariableValueType {
        switch self {
        case .askEachTime: return .text
        case .clipboard: return .text
        case .currentDate: return .date
        case .shortcutInput: return .any
        case .repeatIndex: return .number
        case .repeatItem: return .any
        case .lastResult: return .any
        case .deviceName: return .text
        case .batteryLevel: return .number
        case .wifiName: return .text
        }
    }
}

/// 변수 값 타입 (런타임 타입 정보)
enum VariableValueType: String, Codable, CaseIterable, Identifiable {
    case text = "text"
    case number = "number"
    case boolean = "boolean"
    case list = "list"
    case dictionary = "dictionary"
    case file = "file"
    case image = "image"
    case date = "date"
    case any = "any"  // 타입 미정/혼합
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .text: return "텍스트"
        case .number: return "숫자"
        case .boolean: return "참/거짓"
        case .list: return "리스트"
        case .dictionary: return "딕셔너리"
        case .file: return "파일"
        case .image: return "이미지"
        case .date: return "날짜"
        case .any: return "모든 타입"
        }
    }
}

/// 변수 정의 모델
struct Variable: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var type: VariableType
    var specialType: SpecialVariable?
    var valueType: VariableValueType
    var defaultValue: VariableValue?
    var isHidden: Bool = false  // UI에서 숨김 (내부용)
    
    init(
        id: UUID = UUID(),
        name: String,
        type: VariableType,
        specialType: SpecialVariable? = nil,
        valueType: VariableValueType = .any,
        defaultValue: VariableValue? = nil,
        isHidden: Bool = false
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.specialType = specialType
        self.valueType = valueType
        self.defaultValue = defaultValue
        self.isHidden = isHidden
    }
    
    /// Magic Variable 생성 (단계 출력에서 자동 생성)
    static func magic(from step: ShortcutStep, outputType: VariableValueType) -> Variable {
        Variable(
            name: step.title.isEmpty ? step.type.displayName : step.title,
            type: .magic,
            valueType: outputType
        )
    }
    
    /// Special Variable 생성
    static func special(_ special: SpecialVariable) -> Variable {
        Variable(
            name: special.displayName,
            type: .special,
            specialType: special,
            valueType: special.outputTypeHint
        )
    }
    
    /// Manual Variable 생성
    static func manual(name: String, valueType: VariableValueType = .text, defaultValue: VariableValue? = nil) -> Variable {
        Variable(
            name: name,
            type: .manual,
            valueType: valueType,
            defaultValue: defaultValue
        )
    }
    
    /// 토큰 문자열 (텍스트 필드 삽입용)
    var tokenString: String {
        if let special = specialType {
            return special.tokenString
        }
        return "{\(name)}"
    }
    
    /// 표시용 라벨 (파란 알약 스타일용)
    var displayLabel: String {
        if let special = specialType {
            return special.displayName
        }
        return name
    }
}

/// 변수 런타임 값 (다형성)
enum VariableValue: Codable, Hashable {
    case text(String)
    case number(Double)
    case boolean(Bool)
    case list([VariableValue])
    case dictionary([String: VariableValue])
    case file(URL)
    case image(Data)
    case date(Date)
    case null
    
    // MARK: - 타입 변환 헬퍼
    
    var asText: String? {
        if case .text(let v) = self { return v }
        return nil
    }
    
    var asNumber: Double? {
        if case .number(let v) = self { return v }
        if case .text(let v) = self { return Double(v) }
        return nil
    }
    
    var asBoolean: Bool? {
        if case .boolean(let v) = self { return v }
        if case .text(let v) = self { return v.lowercased() == "true" || v == "1" }
        if case .number(let v) = self { return v != 0 }
        return nil
    }
    
    var asList: [VariableValue]? {
        if case .list(let v) = self { return v }
        return nil
    }
    
    var asDictionary: [String: VariableValue]? {
        if case .dictionary(let v) = self { return v }
        return nil
    }
    
    var asFile: URL? {
        if case .file(let v) = self { return v }
        return nil
    }
    
    var asImage: Data? {
        if case .image(let v) = self { return v }
        return nil
    }
    
    var asDate: Date? {
        if case .date(let v) = self { return v }
        return nil
    }
    
    var type: VariableValueType {
        switch self {
        case .text: return .text
        case .number: return .number
        case .boolean: return .boolean
        case .list: return .list
        case .dictionary: return .dictionary
        case .file: return .file
        case .image: return .image
        case .date: return .date
        case .null: return .any
        }
    }
    
    var isEmpty: Bool {
        switch self {
        case .text(let v): return v.isEmpty
        case .list(let v): return v.isEmpty
        case .dictionary(let v): return v.isEmpty
        case .null: return true
        default: return false
        }
    }
    
    // MARK: - 인코딩/디코딩 (연관 값 처리)
    
    private enum CodingKeys: String, CodingKey {
        case type, value
    }
    
    private enum ValueType: String, Codable {
        case text, number, boolean, list, dictionary, file, image, date, null
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let v):
            try container.encode(ValueType.text, forKey: .type)
            try container.encode(v, forKey: .value)
        case .number(let v):
            try container.encode(ValueType.number, forKey: .type)
            try container.encode(v, forKey: .value)
        case .boolean(let v):
            try container.encode(ValueType.boolean, forKey: .type)
            try container.encode(v, forKey: .value)
        case .list(let v):
            try container.encode(ValueType.list, forKey: .type)
            try container.encode(v, forKey: .value)
        case .dictionary(let v):
            try container.encode(ValueType.dictionary, forKey: .type)
            try container.encode(v, forKey: .value)
        case .file(let v):
            try container.encode(ValueType.file, forKey: .type)
            try container.encode(v.absoluteString, forKey: .value)
        case .image(let v):
            try container.encode(ValueType.image, forKey: .type)
            try container.encode(v.base64EncodedString(), forKey: .value)
        case .date(let v):
            try container.encode(ValueType.date, forKey: .type)
            try container.encode(v, forKey: .value)
        case .null:
            try container.encode(ValueType.null, forKey: .type)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ValueType.self, forKey: .type)
        
        switch type {
        case .text:
            let v = try container.decode(String.self, forKey: .value)
            self = .text(v)
        case .number:
            let v = try container.decode(Double.self, forKey: .value)
            self = .number(v)
        case .boolean:
            let v = try container.decode(Bool.self, forKey: .value)
            self = .boolean(v)
        case .list:
            let v = try container.decode([VariableValue].self, forKey: .value)
            self = .list(v)
        case .dictionary:
            let v = try container.decode([String: VariableValue].self, forKey: .value)
            self = .dictionary(v)
        case .file:
            let s = try container.decode(String.self, forKey: .value)
            self = .file(URL(string: s) ?? URL(fileURLWithPath: s))
        case .image:
            let s = try container.decode(String.self, forKey: .value)
            self = .image(Data(base64Encoded: s) ?? Data())
        case .date:
            let v = try container.decode(Date.self, forKey: .value)
            self = .date(v)
        case .null:
            self = .null
        }
    }
    
    // MARK: - 편의 생성자
    
    static func from(_ value: Any?) -> VariableValue {
        guard let value = value else { return .null }
        if let v = value as? String { return .text(v) }
        if let v = value as? Double { return .number(v) }
        if let v = value as? Int { return .number(Double(v)) }
        if let v = value as? Bool { return .boolean(v) }
        if let v = value as? [Any] { return .list(v.map(VariableValue.from)) }
        if let v = value as? [String: Any] { return .dictionary(v.mapValues(VariableValue.from)) }
        if let v = value as? URL { return .file(v) }
        if let v = value as? Data { return .image(v) }
        if let v = value as? Date { return .date(v) }
        return .text(String(describing: value))
    }
}

/// 단계 실행 출력 (Magic Variable 소스)
struct ActionOutput: Identifiable, Codable, Hashable {
    var id: UUID
    var stepID: UUID
    var stepTitle: String
    var stepType: ActionType
    var output: VariableValue
    var outputType: VariableValueType
    var timestamp: Date
    
    init(stepID: UUID, stepTitle: String, stepType: ActionType, output: VariableValue, outputType: VariableValueType) {
        self.id = UUID()
        self.stepID = stepID
        self.stepTitle = stepTitle
        self.stepType = stepType
        self.output = output
        self.outputType = outputType
        self.timestamp = Date()
    }
    
    /// Magic Variable 토큰 문자열 — 해석기(VariableResolver/UseModelExecutor)와 포맷 일치
    /// {마법변수:stepID:outputType} (stepID는 UUID로, stepOutputs[stepID] 조회와 매칭)
    var tokenString: String {
        return "{마법변수:\(stepID.uuidString):\(outputType.rawValue)}"
    }
    
    /// UI 표시용 미리보기
    var preview: String {
        switch output {
        case .text(let v): return v.count > 50 ? String(v.prefix(50)) + "…" : v
        case .number(let v): return String(v)
        case .boolean(let v): return v ? "참" : "거짓"
        case .list(let v): return "\(v.count)개 항목"
        case .dictionary(let v): return "\(v.count)개 키"
        case .file(let v): return v.lastPathComponent
        case .image: return "이미지"
        case .date(let v): return v.formatted(date: .abbreviated, time: .shortened)
        case .null: return "값 없음"
        }
    }
}

/// 변수 스코프 (어디서 접근 가능한지)
enum VariableScope: String, Codable, CaseIterable {
    case global       // 전체 단축어에서 접근 가능
    case local        // 현재 분기/루프 내부만
    case stepOutput   // 특정 단계 출력 (Magic Variable)
}