import Foundation
import CryptoKit

/// 수치·날짜·목록 보조 액션 (E-MAC-TEXT-6002)
///
/// `TextActions`와 같은 원칙을 따른다.
/// - **실패를 빈 문자열/0으로 뭉개지 않는다.** "빈 결과"와 "패턴 오류"를 구분할 수 있어야 한다
/// - 순수 함수다. 권한·네트워크·파일 접근이 없다 → 테스트가 쉽고 메인을 블로킹하지 않는다
enum DataActions {

    enum Outcome: Equatable {
        case success(String)
        case failure(FailureReason)

        var text: String {
            switch self {
            case .success(let t): return t
            case .failure: return ""
            }
        }

        var isSuccess: Bool {
            if case .success = self { return true }
            return false
        }
    }

    enum FailureReason: Equatable {
        case emptyInput
        case notANumber(String)
        case divisionByZero
        case expressionTooDeep
        case malformedExpression(String)
        case base64DecodeFailed
        case notValidUTF8
        case invalidDateFormat(String)
        case unsupportedOperation(String)
        case countOutOfRange(String)

        var messageKey: String {
            switch self {
            case .emptyInput: return "error.user.text_empty"
            case .notANumber: return "error.user.text_not_number"
            case .divisionByZero: return "error.user.text_div_zero"
            case .expressionTooDeep: return "error.user.text_expression_deep"
            case .malformedExpression: return "error.user.text_expression_invalid"
            case .base64DecodeFailed: return "error.user.text_base64_invalid"
            case .notValidUTF8: return "error.user.text_not_utf8"
            case .invalidDateFormat: return "error.user.text_date_invalid"
            case .unsupportedOperation: return "error.user.text_unsupported"
            case .countOutOfRange: return "error.user.text_count_range"
            }
        }
    }

    // MARK: - 대소문자

    enum CaseStyle: String, Codable, CaseIterable, Hashable {
        case uppercase   // ALLCAPS
        case lowercase   // allcaps
        case capitalized // Title Case
        case sentence    // 첫 글자만 대문자
        case camel       // camelCase
        case kebab       // kebab-case

        var displayName: String {
            switch self {
            case .uppercase: return "style.case_upper".localized
            case .lowercase: return "style.case_lower".localized
            case .capitalized: return "style.case_title".localized
            case .sentence: return "style.case_sentence".localized
            case .camel: return "style.case_camel".localized
            case .kebab: return "style.case_kebab".localized
            }
        }
    }

    static func changeCase(_ input: String, style: CaseStyle) -> Outcome {
        guard !input.isEmpty else { return .failure(.emptyInput) }
        switch style {
        case .uppercase:
            return .success(input.uppercased())
        case .lowercase:
            return .success(input.lowercased())
        case .capitalized:
            // 단어 첫 글자만. "hello world" → "Hello World"
            return .success(input
                .split(separator: " ", omittingEmptySubsequences: true)
                .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                .joined(separator: " "))
        case .sentence:
            guard let first = input.first else { return .failure(.emptyInput) }
            return .success(String(first).uppercased() + input.dropFirst())
        case .camel:
            let words = input.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            guard let head = words.first else { return .failure(.emptyInput) }
            let tail = words.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }
            return .success(head.lowercased() + tail.joined())
        case .kebab:
            let words = input.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            return .success(words.map { $0.lowercased() }.joined(separator: "-"))
        }
    }

    // MARK: - 정렬

    enum SortOrder: String, Codable, CaseIterable, Hashable {
        case ascending
        case descending
    }

    enum SortMode: String, Codable, CaseIterable, Hashable {
        case text     // 사전순
        case numeric  // 숫자순 (숫자가 아니면 뒤로)

        var displayName: String {
            switch self {
            case .text: return "mode.sort_text".localized
            case .numeric: return "mode.sort_numeric".localized
            }
        }
    }

    /// 줄바꿈으로 나눠 정렬해 줄바꿈으로 되돌린다
    static func sort(_ input: String, separator: String, order: SortOrder, mode: SortMode) -> Outcome {
        guard !input.isEmpty else { return .failure(.emptyInput) }
        var items = separator.isEmpty
            ? input.components(separatedBy: "\n")
            : input.components(separatedBy: separator)
        // 빈 항목 제거 — "a\n\nb"의 빈 줄이 정렬을 방해하지 않게
        items = items.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !items.isEmpty else { return .success("") }

        switch mode {
        case .text:
            items.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        case .numeric:
            // 숫자가 아닌 항목은 뒤로 보낸다 (조용히 0으로 취급하면 순서가 거짓말이 된다)
            items.sort { lhs, rhs in
                let l = Double(lhs.trimmingCharacters(in: .whitespaces))
                let r = Double(rhs.trimmingCharacters(in: .whitespaces))
                switch (l, r) {
                case let (l?, r?): return l == r ? lhs < rhs : l < r
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
                }
            }
        }
        if order == .descending { items.reverse() }
        return .success(items.joined(separator: "\n"))
    }

    // MARK: - 감싸기 / 단어 수

    static func surround(_ input: String, prefix: String, suffix: String) -> Outcome {
        guard !input.isEmpty else { return .failure(.emptyInput) }
        return .success(prefix + input + suffix)
    }

    static func wordCount(_ input: String) -> Outcome {
        guard !input.isEmpty else { return .failure(.emptyInput) }
        return .success(String(input
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count))
    }

    // MARK: - 수식 계산

    /// 수식 계산 — `2+3*4` → 14
    ///
    /// `eval`을 쓰지 않는다. **재귀 하강 파서**로 직접 파싱한다.
    /// - 지원: `+ - * / % ^`, 괄호, 단항 마이너스, 소수점, 지수 표기(`1e3`)
    /// - 재귀 깊이 제한: `((((...))))` 같은 입력으로 스택을 터뜨리지 않는다
    /// - 0으로 나누기: IEEE 754는 inf를 만들지만 그건 사용자에게 오류가 아니라
    ///   조용히 이상한 값이므로 **명시적 실패**로 돌려준다
    static func calculate(_ expression: String) -> Outcome {
        let normalized = expression
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "−", with: "-")  // U+2212 마이너스
            .replacingOccurrences(of: " ", with: "")
        guard !normalized.isEmpty else { return .failure(.emptyInput) }

        var parser = ExpressionParser(text: Array(normalized), maxDepth: 64)
        guard let value = parser.parse(), parser.isAtEnd else {
            return .failure(.malformedExpression(expression))
        }
        guard value.isFinite else {
            // inf/NaN — 0으로 나누기나 오버플로
            return .failure(.divisionByZero)
        }
        return .success(formatNumberValue(value))
    }

    /// 재귀 하강 파서 — 우선순위: `^` > 단항 `-` > `* / %` > `+ -`
    private struct ExpressionParser {
        let text: [Character]
        let maxDepth: Int
        var index = 0

        init(text: [Character], maxDepth: Int) {
            self.text = text
            self.maxDepth = maxDepth
        }

        var isAtEnd: Bool { index >= text.count }

        mutating func parse(depth: Int = 0) -> Double? {
            guard depth <= maxDepth else { return nil }
            guard var left = parseTerm(depth: depth) else { return nil }
            while index < text.count, let op = parseOperator(), op == "+" || op == "-" {
                index += 1
                guard let right = parseTerm(depth: depth + 1) else { return nil }
                left = op == "+" ? left + right : left - right
            }
            return left
        }

        private mutating func parseTerm(depth: Int) -> Double? {
            guard depth <= maxDepth else { return nil }
            guard var left = parseUnary(depth: depth) else { return nil }
            while index < text.count, let op = parseOperator(), op == "*" || op == "/" || op == "%" {
                index += 1
                guard let right = parseUnary(depth: depth + 1) else { return nil }
                if (op == "/" || op == "%") && right == 0 { return nil }  // 0 나누기
                switch op {
                case "*": left = left * right
                case "/": left = left / right
                default: left = left.truncatingRemainder(dividingBy: right)
                }
            }
            return left
        }

        private mutating func parseUnary(depth: Int) -> Double? {
            guard depth <= maxDepth else { return nil }
            if index < text.count, text[index] == "-" {
                index += 1
                return parseUnary(depth: depth + 1).map { -$0 }
            }
            if index < text.count, text[index] == "+" {
                index += 1
                return parseUnary(depth: depth + 1)
            }
            return parsePower(depth: depth)
        }

        private mutating func parsePower(depth: Int) -> Double? {
            guard let base = parsePrimary(depth: depth) else { return nil }
            // `^`는 오른쪽 결합: 2^3^2 = 2^(3^2)
            if index < text.count, text[index] == "^" {
                index += 1
                guard let exponent = parseUnary(depth: depth + 1) else { return nil }
                return pow(base, exponent)
            }
            return base
        }

        private mutating func parsePrimary(depth: Int) -> Double? {
            guard depth <= maxDepth else { return nil }
            guard index < text.count else { return nil }
            let ch = text[index]
            if ch == "(" {
                index += 1
                // 괄호 안은 **깊이를 1 올려서** 들어간다. 여기서 0으로 리셋하면
                // `((((...))))` 같은 입력이 깊이 제한을 끝내 통과한다
                // (테스트가 잡아낸 실제 버그였다).
                guard let value = parse(depth: depth + 1) else { return nil }
                guard index < text.count, text[index] == ")" else { return nil }
                index += 1
                return value
            }
            return parseNumber()
        }

        private mutating func parseNumber() -> Double? {
            let start = index
            var seenDot = false
            var seenExp = false
            while index < text.count {
                let ch = text[index]
                if ch.isNumber {
                    index += 1
                } else if ch == "." && !seenDot && !seenExp {
                    seenDot = true
                    index += 1
                } else if (ch == "e" || ch == "E"), !seenExp, index > start {
                    // 지수 표기: e 뒤에 부호가 올 수 있다
                    seenExp = true
                    index += 1
                    if index < text.count, text[index] == "+" || text[index] == "-" { index += 1 }
                } else {
                    break
                }
            }
            guard index > start else { return nil }
            return Double(String(text[start..<index]))
        }

        /// 연산자 읽기
        ///
        /// `**`는 의도적으로 **거부**한다. `*`만 소비하고 남은 `*`가 피연산자 자리에서
        /// 파싱 실패가 나므로 결과적으로 `malformedExpression`이 된다.
        /// 지수 표기는 `^` 하나만 쓴다.
        private mutating func parseOperator() -> Character? {
            guard index < text.count else { return nil }
            let ch = text[index]
            if ch == "*" && index + 1 < text.count, text[index + 1] == "*" {
                return nil
            }
            return "+-*/%^".contains(ch) ? ch : nil
        }
    }

    /// 계산 결과를 사람이 읽기 좋게 정리한다 (부동소수점 오차 제거)
    private static func formatNumberValue(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 1e15 {
            return String(Int(value))
        }
        // 0.1+0.2 = 0.30000000000000004 같은 노이즈를 정리
        let rounded = (value * 1e10).rounded() / 1e10
        return String(rounded)
    }

    // MARK: - 이항 수학 연산

    enum MathOperation: String, Codable, CaseIterable, Hashable {
        case add, subtract, multiply, divide, modulo, power, min, max

        var displayName: String {
            switch self {
            case .add: return "math.add".localized
            case .subtract: return "math.subtract".localized
            case .multiply: return "math.multiply".localized
            case .divide: return "math.divide".localized
            case .modulo: return "math.modulo".localized
            case .power: return "math.power".localized
            case .min: return "math.min".localized
            case .max: return "math.max".localized
            }
        }

        var symbol: String {
            switch self {
            case .add: return "+"
            case .subtract: return "−"
            case .multiply: return "×"
            case .divide: return "÷"
            case .modulo: return "%"
            case .power: return "^"
            case .min: return "min"
            case .max: return "max"
            }
        }
    }

    /// 두 값에 이항 연산을 적용한다 — 피연산자는 줄바꿈 또는 `separator`로 분리
    static func math(_ input: String, operation: MathOperation, separator: String) -> Outcome {
        let parts = separator.isEmpty
            ? input.components(separatedBy: "\n")
            : input.components(separatedBy: separator)
        let numbers = parts
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !numbers.isEmpty else { return .failure(.emptyInput) }
        guard numbers.count >= 2 else { return .failure(.malformedExpression(input)) }

        var values: [Double] = []
        for token in numbers {
            guard let v = Double(token) else { return .failure(.notANumber(token)) }
            values.append(v)
        }

        let result: Double
        switch operation {
        case .add:     result = values.reduce(0, +)
        case .subtract: result = values.dropFirst().reduce(values[0], -)
        case .multiply: result = values.reduce(1, *)
        case .modulo:
            result = values.dropFirst().reduce(values[0]) { acc, next in
                next == 0 ? acc : acc.truncatingRemainder(dividingBy: next)
            }
        case .divide:
            for v in values.dropFirst() where v == 0 { return .failure(.divisionByZero) }
            result = values.dropFirst().reduce(values[0], /)
        case .power:
            result = values.dropFirst().reduce(values[0]) { acc, next in
                // 정수 거듭제곱의 오버플로를 막는다
                guard abs(acc) < 1e100, abs(next) < 100 else { return acc }
                return pow(acc, next)
            }
        case .min:     result = values.min()!
        case .max:     result = values.max()!
        }
        guard result.isFinite else { return .failure(.divisionByZero) }
        return .success(formatNumberValue(result))
    }

    // MARK: - 숫자 변환

    /// 숫자로 변환 — 소수 자릿수 지정
    static func toNumber(_ input: String, decimals: Int) -> Outcome {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.emptyInput) }
        let stripped = trimmed.replacingOccurrences(
            of: "[^0-9eE+\\-.]", with: "", options: .regularExpression
        )
        guard let value = Double(stripped) else { return .failure(.notANumber(input)) }
        guard value.isFinite else { return .failure(.notANumber(input)) }
        let factor = pow(10.0, Double(max(0, decimals)))
        return .success(formatNumberValue((value * factor).rounded() / factor))
    }

    /// 두 값의 차이 (`a` − `b`)
    static func difference(_ input: String, separator: String) -> Outcome {
        let parts = (separator.isEmpty ? input.components(separatedBy: "\n") : input.components(separatedBy: separator))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard parts.count >= 2 else { return .failure(.malformedExpression(input)) }
        guard let a = Double(parts[0]) else { return .failure(.notANumber(parts[0])) }
        guard let b = Double(parts[1]) else { return .failure(.notANumber(parts[1])) }
        return .success(formatNumberValue(a - b))
    }

    // MARK: - Base64 / 해시 / UUID

    static func base64(_ input: String, decode: Bool) -> Outcome {
        guard !input.isEmpty else { return .failure(.emptyInput) }
        if decode {
            guard let data = Data(base64Encoded: input, options: .ignoreUnknownCharacters) else {
                return .failure(.base64DecodeFailed)
            }
            guard let text = String(data: data, encoding: .utf8) else {
                return .failure(.notValidUTF8)
            }
            return .success(text)
        }
        return .success(Data(input.utf8).base64EncodedString())
    }

    enum HashAlgorithm: String, Codable, CaseIterable, Hashable {
        case sha256
        case sha512

        var displayName: String {
            switch self {
            case .sha256: return "hash.sha256".localized
            case .sha512: return "hash.sha512".localized
            }
        }
    }

    /// 해시 — CryptoKit이 제공하는 알고리즘만 쓴다.
    /// **MD5는 넣지 않았다.** MD5는 충돌이 실제로 만들어지는 해시라
    /// "해시"라는 이름 아래 위험한 primitives를 제공하는 셈이다.
    static func hash(_ input: String, algorithm: HashAlgorithm) -> Outcome {
        guard !input.isEmpty else { return .failure(.emptyInput) }
        let data = Data(input.utf8)
        let hex: String
        switch algorithm {
        case .sha256: hex = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        case .sha512: hex = SHA512.hash(data: data).map { String(format: "%02x", $0) }.joined()
        }
        return .success(hex)
    }

    /// UUID 생성 — 여러 개를 줄바꿈으로 나눠 반환
    static func generateUUID(count: Int) -> Outcome {
        guard (1...100).contains(count) else { return .failure(.countOutOfRange("\(count)")) }
        return .success((0..<count).map { _ in UUID().uuidString }.joined(separator: "\n"))
    }

    // MARK: - 날짜

    /// 날짜를 지정 형식으로 변환
    ///
    /// 입력이 비어 있으면 **현재 시각**을 쓴다. 형식 토큰은 `DateFormatter.dateFormat`
    /// 규칙을 그대로 따른다 (`yyyy`, `MM`, `dd`, `HH`, `mm`, `ss`).
    static func formatDate(_ input: String, format: String) -> Outcome {
        let fmt = format.trimmingCharacters(in: .whitespaces)
        guard !fmt.isEmpty else { return .failure(.invalidDateFormat("")) }

        let date: Date
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            date = Date()
        } else {
            // 숫자로만 이뤄졌다면 Unix 타임스탬프로 해석
            if let ts = Double(trimmed), trimmed.allSatisfy({ $0.isNumber || $0 == "." }) {
                date = Date(timeIntervalSince1970: ts)
            } else {
                date = ISO8601DateFormatter().date(from: trimmed) ?? Date()
            }
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = fmt
        let out = formatter.string(from: date)
        // 형식이 비었거나 로컬라이저가 날짜 토큰을 못 읽으면 원문이 그대로 나온다
        if out == fmt && !fmt.contains(where: { "yMdHhmsaE".contains($0) }) {
            return .failure(.invalidDateFormat(fmt))
        }
        return .success(out)
    }

    /// Unix 타임스탬프
    static func timestamp(_ date: Date = Date()) -> Outcome {
        .success(String(Int(date.timeIntervalSince1970)))
    }
}
