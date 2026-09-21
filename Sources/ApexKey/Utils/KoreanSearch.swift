import Foundation

/// 한글 초성 검색 지원 공용 유틸
/// - 초성 시퀀스 추출(`choSeongSequence`)로 한글 음절을 검색 가능하게 함
/// - 검색어가 초성(자모) 문자로만 이루어졌으면 초성 매칭, 아니면 기존 대소문자 무시 substring 매칭
/// - 앱 검색 / HUD 메뉴 검색 / 명령 팔레트 매칭 로직을 한 곳으로 통합(DRY)
enum KoreanSearch {

    /// 한글 초성 19자 (가나다순, 자모 인덱스 순)
    fileprivate static let chosungTable: [Character] = [
        "ㄱ", "ㄲ", "ㄴ", "ㄷ", "ㄸ", "ㄹ", "ㅁ", "ㅂ", "ㅃ",
        "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅉ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ",
    ]

    /// 한글 음절 '가' (U+AC00)
    fileprivate static let hangulBase: UInt32 = 0xAC00
    /// 한글 음절 범위 끝 '힣' (U+D7A3)
    fileprivate static let hangulLast: UInt32 = 0xD7A3
    /// 중성 21 · 종성 28
    fileprivate static let jongseongCount: UInt32 = 28
    fileprivate static let jungseongCount: UInt32 = 21

    // MARK: - 초성 판별

    /// 한글 자모(초성/자모) 문자인지 여부
    /// macOS에서 한글 초성은 주로 Compatibility Jamo(U+3131~U+318E)로 입력됨.
    /// - Compatibility Jamo: ㄱ(0x3131)~ㅎ(0x314E), ㅏ(0x314F)~
    /// - 표준 Jamo: ㄱ(0x1100)~
    static func isChosungCharacter(_ scalar: Unicode.Scalar) -> Bool {
        let v = scalar.value
        // Compatibility Jamo 초성 ㄱ(0x3131) ~ ㅎ(0x314E)
        if (0x3131...0x314E).contains(v) { return true }
        // 표준(Hangul Jamo) 초성 ㄱ(0x1100) ~ ㅎ(0x1112)
        if (0x1100...0x1112).contains(v) { return true }
        return false
    }

    /// 문자열이 초성(자모) 문자로만 이루어졌는지
    static func isChosungOnly(_ string: String) -> Bool {
        guard !string.isEmpty else { return false }
        return string.unicodeScalars.allSatisfy { isChosungCharacter($0) }
    }

    // MARK: - 매칭

    /// 검색어가 대상 문자열과 매칭되는지 판정
    /// - 검색어가 초성(자모) 전용이면 → 대상 문자열의 초성 시퀀스에 검색어 초성 시퀀스가 포함되는지 (부분 초성 매칭)
    /// - 그 외(일반 텍스트/영문/대소문자) → 대소문자 무시 substring 매칭 (기존 동작 유지)
    static func matches(query: String, in target: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        // 검색어가 완전 초성(자모) 전용이면 → 대상 문자열의 초성 시퀀스에서 부분 순서(subsequence) 매칭
        // 예: "ㅇㅍㅋ" 로 "애펙스키"(초성 "ㅇㅍㅅㅋ") 매칭 (연속 불필요)
        if isChosungOnly(trimmed), !target.isEmpty {
            let targetChosung = target.choSeongSequence
            guard !targetChosung.isEmpty else { return false }
            let queryChosung = trimmed.choSeongSequence
            return isSubsequence(queryChosung, of: targetChosung)
        }

        // 그 외 → 기존 대소문자 무시 substring 매칭
        return target.localizedCaseInsensitiveContains(trimmed)
    }

    /// `needle`의 각 문자가 `haystack`에 순서대로(연속 불필요) 나타나는지
    /// 예: isSubsequence("ㅇㅍㅋ", of: "ㅇㅍㅅㅋ") == true
    static func isSubsequence(_ needle: String, of haystack: String) -> Bool {
        guard !needle.isEmpty else { return false }
        var haystackIndex = haystack.startIndex
        for ch in needle {
            guard let found = haystack[haystackIndex...].firstIndex(of: ch) else { return false }
            haystackIndex = haystack.index(after: found)
        }
        return true
    }
}

// MARK: - String 확장

extension String {
    /// 이 문자열의 한글 음절들을 초성만 추출해 이어붙인 문자열
    /// 예: "애펙스키" → "ㅇㅍㅅㅋ", "Apex" → "Apex" (비한글은 그대로 유지)
    var choSeongSequence: String {
        var result = ""
        for scalar in unicodeScalars {
            let value = scalar.value
            if value >= KoreanSearch.hangulBase && value <= KoreanSearch.hangulLast {
                // 초성 인덱스 = (code - 0xAC00) / (21 * 28)
                let index = Int((value - KoreanSearch.hangulBase) / (KoreanSearch.jungseongCount * KoreanSearch.jongseongCount))
                if index < KoreanSearch.chosungTable.count {
                    result.append(KoreanSearch.chosungTable[index])
                }
            } else {
                result.unicodeScalars.append(scalar)
            }
        }
        return result
    }
}
