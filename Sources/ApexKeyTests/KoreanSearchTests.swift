import XCTest
@testable import ApexKey

/// 한글 초성 검색 공용 유틸(KoreanSearch) 단위 테스트
final class KoreanSearchTests: XCTestCase {

    // MARK: - 초성 시퀀스 추출

    func testChoSeongSequenceOfKoreanWord() {
        XCTAssertEqual("애펙스키".choSeongSequence, "ㅇㅍㅅㅋ")
        XCTAssertEqual("파인더".choSeongSequence, "ㅍㅇㄷ")
        XCTAssertEqual("한국어".choSeongSequence, "ㅎㄱㅇ")
    }

    func testChoSeongSequencePreservesNonKorean() {
        // 비한글(영문/숫자/공백)은 그대로 유지
        XCTAssertEqual("ApexKey".choSeongSequence, "ApexKey")
        XCTAssertEqual("메모 123".choSeongSequence, "ㅁㅁ 123")
        XCTAssertEqual("".choSeongSequence, "")
    }

    func testChoSeongSequenceOfSingleSyllable() {
        XCTAssertEqual("가".choSeongSequence, "ㄱ")
        XCTAssertEqual("힣".choSeongSequence, "ㅎ")
    }

    // MARK: - 자모(초성) 판별

    func testIsChosungOnly() {
        XCTAssertTrue(KoreanSearch.isChosungOnly("ㅇㅍㅋ"))
        XCTAssertTrue(KoreanSearch.isChosungOnly("ㄱ"))
        // 완성형 음절은 자모(초성)가 아님
        XCTAssertFalse(KoreanSearch.isChosungOnly("애"))
        XCTAssertFalse(KoreanSearch.isChosungOnly(""))
        XCTAssertFalse(KoreanSearch.isChosungOnly("abc"))
        // 초성 + 일반 혼합
        XCTAssertFalse(KoreanSearch.isChosungOnly("ㅇabc"))
    }

    // MARK: - 초성 매칭

    func testChosungFullMatch() {
        // 전체 초성으로 매칭
        XCTAssertTrue(KoreanSearch.matches(query: "ㅇㅍㅅㅋ", in: "애펙스키"))
        XCTAssertTrue(KoreanSearch.matches(query: "ㅍㅇㄷ", in: "파인더"))
    }

    func testChosungPartialMatch() {
        // 부분 초성으로 매칭 (중간 시작)
        XCTAssertTrue(KoreanSearch.matches(query: "ㅍㅋ", in: "애펙스키"))
        // 앞부분만 입력
        XCTAssertTrue(KoreanSearch.matches(query: "ㅇㅍ", in: "애펙스키"))
    }

    func testChosungNoMatch() {
        XCTAssertFalse(KoreanSearch.matches(query: "ㅁㅁㅁ", in: "애펙스키"))
    }

    func testChosungMatchesCombinedSpaces() {
        // 공백 포함 검색어도 trim 처리
        XCTAssertTrue(KoreanSearch.matches(query: " ㅇㅍㅋ ", in: "애펙스키"))
    }

    // MARK: - 일반(대소문자 무시) 매칭 유지

    func testRegularSubstringStillMatches() {
        XCTAssertTrue(KoreanSearch.matches(query: "펙스", in: "애펙스키"))
        XCTAssertTrue(KoreanSearch.matches(query: "애펙", in: "애펙스키"))
    }

    func testEnglishCaseInsensitiveStillMatches() {
        // English은 초성 대상이 아니라 일반 substring 매칭으로 회귀
        XCTAssertTrue(KoreanSearch.matches(query: "apex", in: "ApexKey"))
        XCTAssertTrue(KoreanSearch.matches(query: "APEX", in: "apexkey"))
        XCTAssertFalse(KoreanSearch.matches(query: "zzz", in: "ApexKey"))
    }

    func testEmptyQueryReturnsFalse() {
        XCTAssertFalse(KoreanSearch.matches(query: "", in: "애펙스키"))
        XCTAssertFalse(KoreanSearch.matches(query: "   ", in: "애펙스키"))
    }
}
