import XCTest
@testable import ApexKey

/// PaletteMatch (레퍼런스 KoreanMatch 이식) 단위 테스트
final class PaletteMatchTests: XCTestCase {

    func testPlainContains() {
        XCTAssertTrue(PaletteMatch.matches(text: "새 채팅", query: "채팅"))
        XCTAssertTrue(PaletteMatch.matches(text: "Safari", query: "saf"))
        XCTAssertFalse(PaletteMatch.matches(text: "Safari", query: "도서"))
    }

    func testWhitespaceInsensitive() {
        XCTAssertTrue(PaletteMatch.matches(text: "새 채팅", query: "새채팅"))
    }

    func testChosungWindow() {
        XCTAssertTrue(PaletteMatch.matches(text: "작업 시작", query: "ㅈㅇ"))
        XCTAssertFalse(PaletteMatch.matches(text: "볼륨 처리", query: "ㅈㅇ"))
        // 공백 외 문자 건너뛰기는 불가 (연속 소진만 통과)
        XCTAssertFalse(PaletteMatch.matches(text: "애펙스키", query: "ㅇㅍㅋ"))
        XCTAssertFalse(PaletteMatch.matchesRanges(text: "애펙스키", query: "ㅇㅍㅋ"))
        XCTAssertTrue(PaletteMatch.matchesRanges(text: "애펙스키", query: "ㅇㅍㅅㅋ"))
    }

    func testEmptyQueryNeverMatches() {
        XCTAssertFalse(PaletteMatch.matches(text: "작업", query: ""))
        XCTAssertFalse(PaletteMatch.matches(text: "", query: "작업"))
    }

    func testMatchRangesPlain() {
        let ranges = PaletteMatch.matchRanges(in: "새 채팅", query: "채팅")
        XCTAssertEqual(ranges?.count, 1)
    }

    func testMatchRangesChosung() {
        // "ㅅㅊㅌ" → 새·채·팅 3구간
        let ranges = PaletteMatch.matchRanges(in: "새 채팅", query: "ㅅㅊㅌ")
        XCTAssertEqual(ranges?.count, 3)
    }

    func testMatchRangesEmptyQueryNil() {
        XCTAssertNil(PaletteMatch.matchRanges(in: "새 채팅", query: "  "))
    }

    func testContextPreviewMarksTruncation() {
        let long = String(repeating: "가", count: 100) + "찾기" + String(repeating: "나", count: 100)
        let preview = PaletteMatch.contextPreview(long, query: "찾기")
        XCTAssertTrue(preview.hasPrefix("…"))
        XCTAssertTrue(preview.hasSuffix("…"))
        XCTAssertTrue(preview.contains("찾기"))
        XCTAssertLessThan(preview.count, long.count)
    }
}
