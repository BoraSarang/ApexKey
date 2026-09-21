import Foundation

/// 팔레트 전용 한글 자소 매칭 (레퍼런스 KoreanMatch 이식, 순수·테스트 가능).
/// 초성·혼용·띄어쓰기 무시 + 매칭 범위 반환 (하이라이트용).
/// 앱 전역 KoreanSearch와 의미가 달라 분리 (기존 검색 동작 보존).
enum PaletteMatch {
    /// 19초성표 (U+3131 ㄱ ~ U+314E ㅎ 순서).
    static var choseongTable: [Character] {
        ["ㄱ", "ㄲ", "ㄴ", "ㄷ", "ㄸ", "ㄹ", "ㅁ", "ㅂ", "ㅃ",
         "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅉ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"]
    }

    /// 한 글자의 초성: 완성형 음절은 분해, 호환 자모 초성은 그대로, 그 외 nil.
    static func choseong(of ch: Character) -> Character? {
        guard let scalar = ch.unicodeScalars.first, ch.unicodeScalars.count == 1 else { return nil }
        let v = scalar.value
        if v >= 0xAC00, v <= 0xD7A3 {
            return choseongTable[Int((v - 0xAC00) / (21 * 28))]
        }
        if choseongTable.contains(ch) { return ch }
        return nil
    }

    /// 질의 글자가 초성 자모인지.
    static func isChoseong(_ ch: Character) -> Bool {
        choseongTable.contains(ch)
    }

    /// 질의 전체가 초성(자모)+공백으로만 이루어졌는지 (하이라이트 분기용).
    static func isChoseongQuery(_ query: String) -> Bool {
        let stripped = query.filter { !$0.isWhitespace }
        guard !stripped.isEmpty else { return false }
        return stripped.allSatisfy { isChoseong($0) || choseongTable.contains($0) }
    }

    /// 자소 단위 동등: 질의 자가 초성이면 텍스트 음절 초성과 비교, 완성형이면 소문자 동등 비교.
    static func charsEqual(textCh: Character, queryCh: Character) -> Bool {
        if isChoseong(queryCh) {
            return choseong(of: textCh) == queryCh
        }
        return String(textCh).lowercased() == String(queryCh).lowercased()
    }

    /// 매칭 여부: 정규 contains → 공백 제거 contains → 슬라이딩 자소 비교.
    static func matches(text: String, query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !text.isEmpty else { return false }
        let lower = text.lowercased()
        let lq = q.lowercased()
        if lower.range(of: lq) != nil { return true }
        let flat = lower.filter { !$0.isWhitespace }
        let flatQ = lq.filter { !$0.isWhitespace }
        if !flatQ.isEmpty, flat.contains(flatQ) { return true }
        return choseongWindow(in: text, query: q) != nil
    }

    /// 매칭 범위: 미리보기 중심용, 없으면 nil.
    static func matchRange(in text: String, query: String) -> Range<String.Index>? {
        let lower = text.lowercased()
        let q = query.lowercased()
        if let range = lower.range(of: q) {
            return range
        }
        return choseongWindow(in: text, query: query)
    }

    /// 초성 슬라이딩 윈도우: 질의 길이만큼 창을 밀며 자소 비교.
    static func choseongWindow(in text: String, query: String) -> Range<String.Index>? {
        let tChars = Array(text)
        let qChars = Array(query)
        guard !qChars.isEmpty, tChars.count >= qChars.count else { return nil }
        guard qChars.contains(where: isChoseong) else { return nil }
        for start in 0 ... (tChars.count - qChars.count) {
            var ok = true
            for offset in qChars.indices where ok {
                ok = charsEqual(textCh: tChars[start + offset], queryCh: qChars[offset])
            }
            if ok {
                let lo = text.index(text.startIndex, offsetBy: start)
                let hi = text.index(lo, offsetBy: qChars.count)
                return lo ..< hi
            }
        }
        return nil
    }

    /// 필터 판정 (레퍼런스 filteredCommands와 동일): 범위 매칭 존재 여부.
    /// 텍스트 공백은 건너뛰고 순서대로 소진되면 통과 ("ㅅㅊㅌ"→"새 채팅").
    static func matchesRanges(text: String, query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !text.isEmpty else { return false }
        return matchRanges(in: text, query: q) != nil
    }

    /// 매칭 글자 범위들: 공백 건너뛰기 순차 스캔. 없으면 nil.
    static func matchRanges(in text: String, query: String) -> [Range<String.Index>]? {
        let qc = Array(query.filter { !$0.isWhitespace })
        guard !qc.isEmpty else { return nil }
        let lower = text.lowercased()
        if let r = lower.range(of: String(qc).lowercased()),
           let lo = indexIn(text, offsetOf: lower, index: r.lowerBound),
           let hi = indexIn(text, offsetOf: lower, index: r.upperBound) {
            return [lo ..< hi]
        }
        let tChars = Array(text)
        for start in tChars.indices {
            if let hit = scanRanges(tChars: tChars, text: text, start: start, qc: qc) {
                return hit
            }
        }
        return nil
    }

    /// 단일 시작점 스캔: 순서대로 소진되면 구간 반환.
    static func scanRanges(tChars: [Character], text: String,
                           start: Int, qc: [Character]) -> [Range<String.Index>]? {
        var ranges: [Range<String.Index>] = []
        var qi = 0
        var ti = start
        while ti < tChars.count, qi < qc.count {
            if tChars[ti].isWhitespace {
                ti += 1
                continue
            }
            guard charsEqual(textCh: tChars[ti], queryCh: qc[qi]) else { return nil }
            let lo = text.index(text.startIndex, offsetBy: ti)
            ranges.append(lo ..< text.index(after: lo))
            qi += 1
            ti += 1
        }
        return qi == qc.count && !ranges.isEmpty ? ranges : nil
    }

    /// lowercased 문자열 인덱스를 원문 인덱스로 환산 (길이 불일치 시 nil).
    static func indexIn(_ text: String, offsetOf lower: String,
                        index: String.Index) -> String.Index? {
        let offset = lower.distance(from: lower.startIndex, to: index)
        return text.index(text.startIndex, offsetBy: offset, limitedBy: text.endIndex)
    }

    /// 매칭 문맥 미리보기: 일치 위치 앞뒤 20자, 잘림은 … 표기.
    static func contextPreview(_ text: String, query: String, context: Int = 20) -> String {
        let flat = text.replacingOccurrences(of: "\n", with: " ")
        guard let range = matchRange(in: flat, query: query) else {
            return String(flat.prefix(60))
        }
        let lo = flat.index(range.lowerBound, offsetBy: -context, limitedBy: flat.startIndex)
            ?? flat.startIndex
        let hi = flat.index(range.upperBound, offsetBy: context, limitedBy: flat.endIndex)
            ?? flat.endIndex
        var out = String(flat[lo ..< hi]).trimmingCharacters(in: .whitespaces)
        if lo > flat.startIndex { out = "…" + out }
        if hi < flat.endIndex { out += "…" }
        return out
    }
}
