import Foundation
import AppKit

/// 텍스트 액션 실행기 (E-MAC-TEXT-6001)
///
/// 11종 전부 **순수 함수**다(클립보드 2종만 예외 — 주입 가능하게 분리했다).
/// 의존성이 없어 테스트가 쉽고, 실행이 메인 스레드를 블로킹하지도 않는다
/// (호출부 백그라운드화는 `E-MAC-ACT-3006`에서 끝났다).
///
/// 정규식 실패는 조용히 빈 문자열을 돌려주지 않는다. `Result`로 실패를 알린다 —
/// 사용자가 "빈 결과"와 "패턴 오류"를 구분할 수 있어야 한다.
enum TextActions {

    // MARK: - 결과

    /// 텍스트 액션 결과 — 실패 사유를 구분해 그대로 노출한다
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
        case missingSearchPattern
        case invalidPattern(String)
        case nonNumericInput(String)
        case clipboardUnavailable

        /// 사용자 노출 메시지 키 (로컬라이즈)
        var messageKey: String {
            switch self {
            case .emptyInput: return "error.user.text_empty"
            case .missingSearchPattern: return "error.user.text_pattern_missing"
            case .invalidPattern: return "error.user.text_pattern_invalid"
            case .nonNumericInput: return "error.user.text_not_number"
            case .clipboardUnavailable: return "error.user.clipboard_unavailable"
            }
        }
    }

    // MARK: - 텍스트 (그대로 통과)

    static func text(_ input: String) -> Outcome {
        .success(input)
    }

    // MARK: - 결합 / 분리

    /// 여러 텍스트 결합 — `components`는 `\u{1F}`(유닛 구분자)로 연결된 블록
    static func combine(_ components: [String], separator: String) -> Outcome {
        guard !components.isEmpty else { return .failure(.emptyInput) }
        return .success(components.joined(separator: separator))
    }

    /// 구분자로 분리 — `limit`이 nil이면 전부, 0이면 무제한
    static func split(_ input: String, separator: String, limit: Int? = nil) -> Outcome {
        guard !input.isEmpty else { return .failure(.emptyInput) }
        guard !separator.isEmpty else {
            // 구분자가 없으면 원본을 그대로 한 덩어리로 본다
            return .success(input)
        }
        let parts = input.components(separatedBy: separator)
        guard limit == nil || parts.count <= (limit ?? .max) else {
            // 상한이 있으면 초과분을 마지막에 붙인다
            let kept = Array(parts.prefix(max(0, (limit ?? 0) - 1)))
            let rest = parts.dropFirst(kept.count).joined(separator: separator)
            return .success((kept + [rest]).joined(separator: separator))
        }
        return .success(parts.joined(separator: "\n"))
    }

    // MARK: - 공백 / 치환

    /// 앞뒤 공백 제거
    static func trimWhitespace(_ input: String) -> Outcome {
        guard !input.isEmpty else { return .failure(.emptyInput) }
        return .success(input.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// 모든 공백을 한 칸으로 축약
    static func collapseWhitespace(_ input: String) -> Outcome {
        guard !input.isEmpty else { return .failure(.emptyInput) }
        let collapsed = input
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return .success(collapsed)
    }

    /// 일반 문자열 교체 (정규식 아님)
    static func replace(_ input: String, search: String, replacement: String) -> Outcome {
        guard !input.isEmpty else { return .failure(.emptyInput) }
        guard !search.isEmpty else { return .failure(.missingSearchPattern) }
        guard input.contains(search) else { return .success(input) }
        return .success(input.replacingOccurrences(of: search, with: replacement))
    }

    // MARK: - 정규식

    /// 정규식 매치 결과 문자열
    ///
    /// - Parameters:
    ///   - allMatches: `true`면 전체 매치, `false`면 첫 매치만
    static func regex(_ input: String, pattern: String, allMatches: Bool) -> Outcome {
        guard !input.isEmpty else { return .failure(.emptyInput) }
        guard !pattern.isEmpty else { return .failure(.missingSearchPattern) }
        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern)
        } catch {
            return .failure(.invalidPattern(pattern))
        }
        let ns = input as NSString
        let range = NSRange(location: 0, length: ns.length)
        if allMatches {
            let matches = regex.matches(in: input, options: [], range: range)
            let values = matches.map { ns.substring(with: $0.range) }
            return .success(values.joined(separator: "\n"))
        }
        guard let first = regex.firstMatch(in: input, options: [], range: range) else {
            return .success("")
        }
        return .success(ns.substring(with: first.range))
    }

    /// 정규식 치환 — `$1` 등 역참조 지원
    static func regexReplace(_ input: String, pattern: String, replacement: String) -> Outcome {
        guard !input.isEmpty else { return .failure(.emptyInput) }
        guard !pattern.isEmpty else { return .failure(.missingSearchPattern) }
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let ns = input as NSString
            let range = NSRange(location: 0, length: ns.length)
            let result = regex.stringByReplacingMatches(in: input, options: [], range: range, withTemplate: replacement)
            return .success(result)
        } catch {
            return .failure(.invalidPattern(pattern))
        }
    }

    /// 정규식 매치 여부
    static func matches(_ input: String, pattern: String) -> Outcome {
        guard !input.isEmpty else { return .failure(.emptyInput) }
        guard !pattern.isEmpty else { return .failure(.missingSearchPattern) }
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let ns = input as NSString
            let range = NSRange(location: 0, length: ns.length)
            let found = regex.firstMatch(in: input, options: [], range: range) != nil
            return .success(found ? "true" : "false")
        } catch {
            return .failure(.invalidPattern(pattern))
        }
    }

    // MARK: - 개수

    static func count(_ input: String, unit: TextActionConfig.CountUnit) -> Outcome {
        guard !input.isEmpty else { return .failure(.emptyInput) }
        let n: Int
        switch unit {
        case .characters:
            n = input.count
        case .words:
            n = input.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        case .lines:
            n = input.components(separatedBy: .newlines).count
        case .sentences:
            // 종결부호 뒤 공백을 경계로 본다. 마침표 없는 입력이 0이 되지 않게 1로 본다
            let terminated = input.split(whereSeparator: { ".!?。！？".contains($0) }).count
            n = max(terminated, input.isEmpty ? 0 : 1)
        }
        return .success(String(n))
    }

    // MARK: - 숫자 형식

    /// 숫자 형식 지정
    ///
    /// **실패를 조용히 넘기지 않는다**: 입력이 숫자가 아니면 `nonNumericInput`을 돌려준다.
    /// 0을 조용히 반환하면 "서식이 이상하다"와 "입력이 잘못됐다"를 구분할 수 없다.
    static func formatNumber(
        _ input: String,
        style: TextActionConfig.NumberStyle,
        decimals: Int,
        grouping: Bool,
        locale: Locale = .current
    ) -> Outcome {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.emptyInput) }
        // 지수 표기와 천 단위 구분자·통화기호를 제거한 **순수 숫자**만 받는다
        let stripped = trimmed.replacingOccurrences(
            of: "[^0-9eE+\\-.]",
            with: "",
            options: .regularExpression
        )
        guard let value = Double(stripped) else {
            return .failure(.nonNumericInput(input))
        }

        switch style {
        case .decimal, .currency, .percent:
            let formatter = NumberFormatter()
            formatter.locale = locale
            formatter.numberStyle = style == .decimal ? .decimal : (style == .currency ? .currency : .percent)
            formatter.usesGroupingSeparator = grouping
            if style == .percent {
                // percent 스타일은 0.5를 50%로 보이게 하므로 값을 100배 한다
                formatter.maximumFractionDigits = max(0, decimals)
                formatter.minimumFractionDigits = 0
            } else {
                formatter.minimumFractionDigits = max(0, decimals)
                formatter.maximumFractionDigits = max(0, decimals)
            }
            guard let text = formatter.string(from: NSNumber(value: value)) else {
                return .failure(.nonNumericInput(input))
            }
            return .success(text)
        case .scientific:
            return .success(String(format: "%.\(max(0, decimals))e", value))
        case .words:
            // 로케일에 맞는 읽기 폼. 한국어 단위어(만/억/조)를 하드코딩하면
            // 영어 로케일에서 엉뚱한 값이 나오므로 시스템에 맡긴다.
            let formatter = NumberFormatter()
            formatter.locale = locale
            formatter.numberStyle = .spellOut
            formatter.maximumFractionDigits = max(0, decimals)
            guard let text = formatter.string(from: NSNumber(value: value)) else {
                return .failure(.nonNumericInput(input))
            }
            return .success(text)
        }
    }

    // MARK: - 클립보드

    /// 클립보드 읽기 — 주입 가능하게 뺀다. 테스트가 사용자 클립보드를 건드리지 않도록
    static func getClipboard(pasteboard: NSPasteboard = .general) -> Outcome {
        guard let text = pasteboard.string(forType: .string) else {
            return .failure(.clipboardUnavailable)
        }
        return .success(text)
    }

    /// 클립보드 쓰기
    @discardableResult
    static func setClipboard(_ text: String, pasteboard: NSPasteboard = .general) -> Outcome {
        guard !text.isEmpty else { return .failure(.emptyInput) }
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            return .failure(.clipboardUnavailable)
        }
        return .success(text)
    }
}
