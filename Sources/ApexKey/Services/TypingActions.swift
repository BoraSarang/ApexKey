import Foundation
import CoreGraphics
import AppKit

/// 텍스트·숫자 입력 액션 (E-MAC-TEXT-6003)
///
/// **설계 원칙 — 게시와 계획을 분리한다.**
/// `plan(_:)`은 순수 함수다: 접근성 권한·포커스·타이밍과 무관하게 "무엇을 보낼지"를
/// 계산만 한다. 그래서 **권한 없이도 전적으로 테스트 가능**하고, 권한이 없을 때의
/// 실패는 게시 단계에서만 결정된다.
///
/// 왜 이 분리가 필요한가: 키 입력은 `AXIsProcessTrusted()`가 없으면 **조용히 무응답**이
/// 된다. 그 상태를 테스트하면 "보냈지만 아무 일도 안 일어난" 성공처럼 보인다.
/// 계획 계층을 테스트하면 그 함정을 피할 수 있다.
enum TypingActions {

    /// 숫자 입력 결과 — Swift 표준 `Result`와 이름이 겹치므로 별칭을 쓴다
    typealias TypingOutcome = Result<String, FailureReason>

    /// 한 번의 CGEvent로 보낼 수 있는 길이 (UTF-16 코드유닛)
    ///
    /// `CGEventKeyboardSetUnicodeString`은 버퍼 길이가 유한하다. 20은 한글이
    /// 결합음자 때문에 UTF-16에서 2~3 유닛을 쓰기도 하는 점을 여유 있게 감당한다.
    /// 한글이 깨져 나가는 일이 "권한 문제"로 오해되기 쉬우므로 보수적으로 잡았다.
    static let maxUnitsPerEvent = 20

    /// 전송 계획 — 테스트 가능한 순수 결과
    struct Plan: Equatable {
        /// 그대로 보낼 문자열 조각들
        let chunks: [String]
        /// 보낼 문자 수 (UTF-16 유닛이 아니라 사람이 세는 글자)
        let characterCount: Int
    }

    /// 입력을 전송 가능한 조각으로 나눈다
    ///
    /// **잘라내지 않는다.** 중간에서 자르면 결합 한글이 분리되어 깨진다.
    /// 대신 **문자 경계(Character)**에서만 자르고, 한 문자가 한도보다 길면
    /// 어쩔 수 없이 그 문자를 단독으로 보낸다 (Extremely Rare Combining Mark).
    static func plan(_ input: String) -> Plan {
        var chunks: [String] = []
        var current = ""
        var currentUnits = 0

        for ch in input {
            let units = ch.utf16.count
            if currentUnits + units > maxUnitsPerEvent, !current.isEmpty {
                chunks.append(current)
                current = ""
                currentUnits = 0
            }
            current.append(ch)
            currentUnits += units
        }
        if !current.isEmpty { chunks.append(current) }
        return Plan(chunks: chunks, characterCount: input.count)
    }

    /// 실제 입력 전송
    ///
    /// - Returns: 전송 성공 여부. 권한이 없으면 false (조용히 실패하지 않는다)
    @discardableResult
    static func typeText(_ input: String, interval: TimeInterval = 0.01) -> Bool {
        guard !input.isEmpty else { return true }          // 빈 입력은 성공(노-op)
        guard AXIsProcessTrusted() else {
            Logger.error("E-MAC-TEXT-6004", "손쉬운 사용 권한 없음 — 텍스트 입력 불가. 시스템 설정 > 손쉬운 사용에서 ApexKey 허용 필요")
            return false
        }
        let chunks = plan(input).chunks
        let source = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
            Logger.error("E-MAC-TEXT-6004", "키 이벤트 생성 실패")
            return false
        }
        for chunk in chunks {
            var utf16 = Array(chunk.utf16)
            down.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
            down.post(tap: .cghidEventTap)
            if interval > 0 { Thread.sleep(forTimeInterval: interval) }
        }
        up.post(tap: .cghidEventTap)
        Logger.info("TypingActions", "텍스트 입력 완료: \(input.count)자 / \(chunks.count)청크")
        return true
    }

    /// 숫자 입력
    ///
    /// **숫자가 아니면 실패다.** 조용히 0으로 바꾸면 "입력했는데 왜 반영이 안 되지"
    /// 라는 symptom이 남는다. 앞뒤 공백은 용인한다 (사용자는 " 42 "로 입력한다).
    static func typeNumber(_ input: String, decimals: Int, interval: TimeInterval = 0.01) -> TypingOutcome {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(.emptyInput)
        }
        let stripped = trimmed.replacingOccurrences(
            of: "[^0-9eE+\\-.]", with: "", options: .regularExpression
        )
        guard let value = Double(stripped), value.isFinite else {
            return .failure(.notANumber(trimmed))
        }
        let factor = pow(10.0, Double(max(0, decimals)))
        let text = String((value * factor).rounded() / factor)
        guard typeText(text, interval: interval) else { return .failure(.noPermission) }
        return .success(text)
    }

    enum FailureReason: Equatable, Error {
        case emptyInput
        case notANumber(String)
        case noPermission

        var messageKey: String {
            switch self {
            case .emptyInput: return "error.user.text_empty"
            case .notANumber: return "error.user.text_not_number"
            case .noPermission: return "error.user.text_no_permission"
            }
        }
    }
}
