import Foundation

/// 조건 연산자
enum ConditionOperator: String, Codable, CaseIterable, Identifiable {
    case equals = "equals"
    case notEquals = "notEquals"
    case contains = "contains"
    case notContains = "notContains"
    case startsWith = "startsWith"
    case endsWith = "endsWith"
    case isEmpty = "isEmpty"
    case isNotEmpty = "isNotEmpty"
    case greaterThan = "greaterThan"
    case lessThan = "lessThan"
    case greaterOrEqual = "greaterOrEqual"
    case lessOrEqual = "lessOrEqual"
    case matches = "matches"  // 정규식
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .equals: return "같음"
        case .notEquals: return "다름"
        case .contains: return "포함"
        case .notContains: return "미포함"
        case .startsWith: return "시작함"
        case .endsWith: return "끝남"
        case .isEmpty: return "비어있음"
        case .isNotEmpty: return "비어있지 않음"
        case .greaterThan: return "초과"
        case .lessThan: return "미만"
        case .greaterOrEqual: return "이상"
        case .lessOrEqual: return "이하"
        case .matches: return "정규식 일치"
        }
    }
    
    var symbol: String {
        switch self {
        case .equals: return "="
        case .notEquals: return "≠"
        case .contains: return "⊃"
        case .notContains: return "⊅"
        case .startsWith: return "↳"
        case .endsWith: return "↲"
        case .isEmpty: return "∅"
        case .isNotEmpty: return "≠∅"
        case .greaterThan: return ">"
        case .lessThan: return "<"
        case .greaterOrEqual: return "≥"
        case .lessOrEqual: return "≤"
        case .matches: return "~="
        }
    }
    
    var requiresRightOperand: Bool {
        switch self {
        case .isEmpty, .isNotEmpty: return false
        default: return true
        }
    }
    
    var supportedTypes: Set<VariableValueType> {
        switch self {
        case .equals, .notEquals:
            return [.text, .number, .boolean, .date, .file]
        case .contains, .notContains, .startsWith, .endsWith, .matches:
            return [.text]
        case .isEmpty, .isNotEmpty:
            return [.text, .list, .dictionary]
        case .greaterThan, .lessThan, .greaterOrEqual, .lessOrEqual:
            return [.number, .date]
        }
    }
}

/// 조건식 (왼쪽 값, 연산자, 오른쪽 값)
struct Condition: Identifiable, Codable, Hashable {
    var id: UUID
    var leftOperand: ConditionOperand
    var `operator`: ConditionOperator
    var rightOperand: ConditionOperand?
    
    private enum CodingKeys: String, CodingKey {
        case id, leftOperand, op, rightOperand
    }
    
    init(
        id: UUID = UUID(),
        leftOperand: ConditionOperand,
        operator: ConditionOperator,
        rightOperand: ConditionOperand? = nil
    ) {
        self.id = id
        self.leftOperand = leftOperand
        self.operator = `operator`
        self.rightOperand = rightOperand
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.leftOperand = try c.decode(ConditionOperand.self, forKey: .leftOperand)
        self.operator = try c.decode(ConditionOperator.self, forKey: .op)
        self.rightOperand = try c.decodeIfPresent(ConditionOperand.self, forKey: .rightOperand)
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(leftOperand, forKey: .leftOperand)
        try c.encode(`operator`, forKey: .op)
        try c.encodeIfPresent(rightOperand, forKey: .rightOperand)
    }
    
    /// 조건 평가 — 변수+특수변수+매직변수 모두 해석 (ResolveContext 기반)
    func evaluate(with context: VariableResolver.ResolveContext) -> Bool {
        let leftValue = leftOperand.resolve(with: context)
        let rightValue = rightOperand?.resolve(with: context)
        
        guard leftValue != .null else { return false }
        
        switch `operator` {
        case .equals:
            return rightValue != nil && rightValue != .null && leftValue == rightValue
        case .notEquals:
            guard let right = rightValue, right != .null else { return false }
            return leftValue != right
        case .contains:
            guard let right = rightValue?.asText,
                  let left = leftValue.asText else { return false }
            return left.contains(right)
        case .notContains:
            guard let right = rightValue?.asText,
                  let left = leftValue.asText else { return true }
            return !left.contains(right)
        case .startsWith:
            guard let right = rightValue?.asText,
                  let left = leftValue.asText else { return false }
            return left.hasPrefix(right)
        case .endsWith:
            guard let right = rightValue?.asText,
                  let left = leftValue.asText else { return false }
            return left.hasSuffix(right)
        case .isEmpty:
            return leftValue.isEmpty
        case .isNotEmpty:
            return !leftValue.isEmpty
        case .greaterThan:
            guard let left = leftValue.asNumber,
                  let right = rightValue?.asNumber else { return false }
            return left > right
        case .lessThan:
            guard let left = leftValue.asNumber,
                  let right = rightValue?.asNumber else { return false }
            return left < right
        case .greaterOrEqual:
            guard let left = leftValue.asNumber,
                  let right = rightValue?.asNumber else { return false }
            return left >= right
        case .lessOrEqual:
            guard let left = leftValue.asNumber,
                  let right = rightValue?.asNumber else { return false }
            return left <= right
        case .matches:
            guard let right = rightValue?.asText,
                  let left = leftValue.asText else { return false }
            do {
                let regex = try NSRegularExpression(pattern: right)
                let range = NSRange(location: 0, length: left.utf16.count)
                return regex.firstMatch(in: left, options: [], range: range) != nil
            } catch {
                return false
            }
        }
    }
    
    /// 표시용 문자열
    var displayString: String {
        let left = leftOperand.displayString
        let op = `operator`.displayName
        if let right = rightOperand {
            return "\(left) \(op) \(right.displayString)"
        }
        return "\(left) \(op)"
    }
}

/// 조건 피연산자 (변수, 상수, Magic Variable 등)
enum ConditionOperand: Codable, Hashable {
    case variable(UUID)           // 변수 참조
    case magicVariable(UUID)      // Magic Variable (단계 출력)
    case constant(VariableValue)  // 상수값
    case specialVariable(SpecialVariable)  // 특수 변수
    
    func resolve(with context: VariableResolver.ResolveContext) -> VariableValue {
        switch self {
        case .variable(let id):
            return context.variables[id] ?? .null
        case .magicVariable(let id):
            // Magic Variable — 단계 출력에서 조회
            return context.stepOutputs[id] ?? .null
        case .constant(let value):
            return value
        case .specialVariable(let sv):
            // 특수 변수 — 리졸버를 통해 해석 (반복 인덱스/항목 등)
            return VariableResolver.resolveSpecialVariable(sv, context: context)
        }
    }
    
    var displayString: String {
        switch self {
        case .variable(let id): return "{변수:\(id.uuidString.prefix(8))}"
        case .magicVariable(let id): return "{마법:\(id.uuidString.prefix(8))}"
        case .constant(let v):
            switch v {
            case .text(let s): return "\"\(s)\""
            case .number(let n): return String(n)
            case .boolean(let b): return b ? "참" : "거짓"
            case .list(let a): return "[\(a.count)개]"
            case .dictionary(let d): return "{\(d.count)개}"
            case .file(let u): return u.lastPathComponent
            case .image: return "이미지"
            case .date(let d): return d.formatted()
            case .null: return "없음"
            }
        case .specialVariable(let sv): return sv.displayName
        }
    }
}

/// If 분기 구조
struct IfBranch: Identifiable, Codable, Hashable {
    var id: UUID
    var condition: Condition
    var thenSteps: [ShortcutStep]
    var elseSteps: [ShortcutStep]?
    var label: String?  // 사용자 정의 라벨
    
    init(
        id: UUID = UUID(),
        condition: Condition,
        thenSteps: [ShortcutStep] = [],
        elseSteps: [ShortcutStep]? = nil,
        label: String? = nil
    ) {
        self.id = id
        self.condition = condition
        self.thenSteps = thenSteps
        self.elseSteps = elseSteps
        self.label = label
    }
    
    var displayName: String {
        label ?? "If \(condition.displayString)"
    }
}

/// Repeat 루프 모드
enum RepeatMode: String, Codable, CaseIterable, Identifiable {
    case count = "count"           // N번 반복
    case forEach = "forEach"       // 컬렉션 각 항목 순회
    case whileLoop = "whileLoop"   // 조건 만족하는 동안 (미구현)
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .count: return "횟수 반복"
        case .forEach: return "각 항목 반복"
        case .whileLoop: return "조건 반복"
        }
    }
    
    var systemImage: String {
        switch self {
        case .count: return "repeat"
        case .forEach: return "arrow.triangle.2.circlepath"
        case .whileLoop: return "infinity"
        }
    }
}

/// Repeat 루프 구조
struct RepeatLoop: Identifiable, Codable, Hashable {
    var id: UUID
    var mode: RepeatMode
    var count: Int?                    // .count 모드: 반복 횟수
    var collectionVariable: UUID?      // .forEach 모드: 순회할 컬렉션 변수 ID
    var steps: [ShortcutStep]
    var repeatIndexVariable: UUID?     // 자동 생성: 반복 인덱스 변수 ID
    var repeatItemVariable: UUID?      // 자동 생성: 반복 항목 변수 ID (.forEach)
    var label: String?                 // 사용자 정의 라벨
    
    init(
        id: UUID = UUID(),
        mode: RepeatMode,
        count: Int? = nil,
        collectionVariable: UUID? = nil,
        steps: [ShortcutStep] = [],
        repeatIndexVariable: UUID? = nil,
        repeatItemVariable: UUID? = nil,
        label: String? = nil
    ) {
        self.id = id
        self.mode = mode
        self.count = count
        self.collectionVariable = collectionVariable
        self.steps = steps
        self.repeatIndexVariable = repeatIndexVariable
        self.repeatItemVariable = repeatItemVariable
        self.label = label
    }
    
    var displayName: String {
        if let label = label { return label }
        switch mode {
        case .count:
            return "\(count ?? 0)번 반복"
        case .forEach:
            return "각 항목 반복"
        case .whileLoop:
            return "조건 반복"
        }
    }
    
    /// 예상 반복 횟수 (실행 전 추정)
    func estimatedIterations(variables: [UUID: VariableValue]) -> Int {
        switch mode {
        case .count:
            return count ?? 1
        case .forEach:
            if let varID = collectionVariable,
               let collection = variables[varID]?.asList {
                return collection.count
            }
            return 0
        case .whileLoop:
            return 1  // 알 수 없음
        }
    }
}

/// 메뉴 선택 옵션
struct MenuOption: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var subtitle: String?
    var icon: String?  // SF Symbol 이름
    var value: VariableValue  // 선택 시 반환될 값
    
    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        value: VariableValue? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.value = value ?? .text(title)
    }
}

/// 메뉴 선택 액션 (Choose from Menu)
struct ChooseFromMenu: Identifiable, Codable, Hashable {
    var id: UUID
    var prompt: String
    var options: [MenuOption]
    var allowMultipleSelection: Bool
    var showCancelButton: Bool
    var outputVariable: UUID  // 선택 결과 저장할 변수 ID
    var label: String?
    
    init(
        id: UUID = UUID(),
        prompt: String = "옵션을 선택하세요",
        options: [MenuOption] = [],
        allowMultipleSelection: Bool = false,
        showCancelButton: Bool = true,
        outputVariable: UUID,
        label: String? = nil
    ) {
        self.id = id
        self.prompt = prompt
        self.options = options
        self.allowMultipleSelection = allowMultipleSelection
        self.showCancelButton = showCancelButton
        self.outputVariable = outputVariable
        self.label = label
    }
    
    var displayName: String {
        label ?? "메뉴 선택 (\(options.count)개 옵션)"
    }
}

/// 단축어 실행 액션 (Run Shortcut)
struct RunShortcutAction: Identifiable, Codable, Hashable {
    var id: UUID
    var targetShortcutID: UUID
    var waitForCompletion: Bool
    var passInput: Bool
    var outputVariable: UUID?  // 실행 결과 저장할 변수
    
    init(
        id: UUID = UUID(),
        targetShortcutID: UUID,
        waitForCompletion: Bool = true,
        passInput: Bool = false,
        outputVariable: UUID? = nil
    ) {
        self.id = id
        self.targetShortcutID = targetShortcutID
        self.waitForCompletion = waitForCompletion
        self.passInput = passInput
        self.outputVariable = outputVariable
    }
}

/// 단축어 중단/종료
struct StopShortcutAction: Identifiable, Codable, Hashable {
    var id: UUID
    var outputVariable: UUID?  // 최종 출력값 저장
    var outputValue: VariableValue?
    
    init(id: UUID = UUID(), outputVariable: UUID? = nil, outputValue: VariableValue? = nil) {
        self.id = id
        self.outputVariable = outputVariable
        self.outputValue = outputValue
    }
}

/// 주석/코멘트 단계 (실행되지 않음, 문서화용)
struct CommentStep: Identifiable, Codable, Hashable {
    var id: UUID
    var text: String
    var color: String  // HEX 색상
    
    init(id: UUID = UUID(), text: String, color: String = "#FFD60A") {
        self.id = id
        self.text = text
        self.color = color
    }
}