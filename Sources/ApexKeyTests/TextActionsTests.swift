import XCTest
import AppKit
@testable import ApexKey

/// 텍스트 액션 11종 테스트 (E-MAC-TEXT-6001)
///
/// 11종이 전부 `planned`(카탈로그에 "준비 중"으로만 노출)였다. 순수 로직이라
/// 의존성이 없고 실패 주기가 짧아 구현·검증 비용이 낮았다.
///
/// 설계 원칙을 여기서 지킨다: **실패를 빈 문자열로 뭉개지 않는다.**
/// 사용자가 "결과가 비었다"와 "패턴이 잘못됐다"를 구분할 수 있어야 하기 때문에
/// `Outcome`이 `failure(사유)`를 명시적으로 돌려준다.
final class TextActionsTests: XCTestCase {

    // MARK: - 통과 / 결합 / 분리

    func testTextPassesThrough() {
        XCTAssertEqual(TextActions.text("안녕").text, "안녕")
        XCTAssertEqual(TextActions.text("").text, "")
    }

    func testCombineJoinsWithSeparator() {
        XCTAssertEqual(TextActions.combine(["a", "b", "c"], separator: "-").text, "a-b-c")
        XCTAssertEqual(TextActions.combine(["a"], separator: "-").text, "a")
        // 구분자가 빈 문자열이면 이어 붙인다
        XCTAssertEqual(TextActions.combine(["a", "b"], separator: "").text, "ab")
    }

    func testCombineEmptyIsFailure() {
        XCTAssertEqual(TextActions.combine([], separator: "-"), .failure(.emptyInput))
    }

    func testSplitBySeparator() {
        XCTAssertEqual(TextActions.split("a,b,c", separator: ",").text, "a\nb\nc")
        XCTAssertEqual(TextActions.split("a", separator: ",").text, "a")
    }

    func testSplitEmptySeparatorKeepsInput() {
        // 구분자가 없으면 원본 그대로 — 조용히 문자 단위로 쪼개지지 않는다
        XCTAssertEqual(TextActions.split("abc", separator: "").text, "abc")
    }

    func testSplitEmptyInputIsFailure() {
        XCTAssertEqual(TextActions.split("", separator: ","), .failure(.emptyInput))
    }

    // MARK: - 공백 / 치환

    func testTrimWhitespace() {
        XCTAssertEqual(TextActions.trimWhitespace("  안녕  \n").text, "안녕")
        XCTAssertEqual(TextActions.trimWhitespace("안녕").text, "안녕")
        // 전부 공백이면 빈 문자열이 성공 결과다 (실패가 아니다)
        XCTAssertEqual(TextActions.trimWhitespace("   ").text, "")
        XCTAssertEqual(TextActions.trimWhitespace(""), .failure(.emptyInput))
    }

    func testCollapseWhitespace() {
        XCTAssertEqual(TextActions.collapseWhitespace("  a   b \n c  ").text, "a b c")
    }

    func testReplaceLiteral() {
        XCTAssertEqual(TextActions.replace("aXbXc", search: "X", replacement: "-").text, "a-b-c")
    }

    func testReplaceNotFoundReturnsOriginal() {
        // 없으면 원본 그대로가 성공이다 (실패가 아니다)
        XCTAssertEqual(TextActions.replace("abc", search: "Z", replacement: "-").text, "abc")
    }

    func testReplaceEmptySearchIsFailure() {
        // 빈 검색어는 모든 문자열에 매치돼 의도치 않은 삭제가 된다. 명시적으로 막는다
        XCTAssertEqual(TextActions.replace("abc", search: "", replacement: "-"), .failure(.missingSearchPattern))
    }

    // MARK: - 정규식

    func testRegexFirstMatch() {
        XCTAssertEqual(TextActions.regex("날짜 2026-09-29", pattern: "\\d{4}-\\d{2}-\\d{2}", allMatches: false).text, "2026-09-29")
    }

    func testRegexAllMatches() {
        let out = TextActions.regex("a1b22c333", pattern: "\\d+", allMatches: true).text
        XCTAssertEqual(out, "1\n22\n333")
    }

    func testRegexNoMatchReturnsEmpty() {
        // 패턴이 유효하지만 매치가 없으면 빈 문자열이 **성공**이다
        XCTAssertEqual(TextActions.regex("abc", pattern: "\\d+", allMatches: false).text, "")
    }

    func testRegexInvalidPatternIsFailure() {
        // 잘못된 패턴을 조용히 빈 결과로 넘기면 사용자는 "패턴이 틀렸다"를 알 수 없다
        let result = TextActions.regex("abc", pattern: "[unclosed", allMatches: false)
        XCTAssertEqual(result, .failure(.invalidPattern("[unclosed")))
        XCTAssertFalse(result.isSuccess)
    }

    func testRegexEmptyPatternIsFailure() {
        XCTAssertEqual(TextActions.regex("abc", pattern: "", allMatches: false), .failure(.missingSearchPattern))
    }

    func testRegexReplaceWithBackReference() {
        let out = TextActions.regexReplace("2026-09-29", pattern: "(\\d{4})-(\\d{2})-(\\d{2})", replacement: "$3/$2/$1")
        XCTAssertEqual(out.text, "29/09/2026")
    }

    func testMatchesReportsTrueFalse() {
        XCTAssertEqual(TextActions.matches("abc123", pattern: "\\d+").text, "true")
        XCTAssertEqual(TextActions.matches("abc", pattern: "\\d+").text, "false")
    }

    func testMatchesInvalidPatternIsFailure() {
        XCTAssertFalse(TextActions.matches("abc", pattern: "(").isSuccess)
    }

    // MARK: - 개수

    func testCountCharacters() {
        XCTAssertEqual(TextActions.count("안녕", unit: .characters).text, "2")
        // 한글이므로 유니코드 스칼라 기준이다
        XCTAssertEqual(TextActions.count("abc", unit: .characters).text, "3")
    }

    func testCountWords() {
        XCTAssertEqual(TextActions.count("  hello   world  ", unit: .words).text, "2")
        XCTAssertEqual(TextActions.count("여러    공백 사이", unit: .words).text, "3")
    }

    func testCountLines() {
        XCTAssertEqual(TextActions.count("a\nb\nc", unit: .lines).text, "3")
    }

    func testCountSentences() {
        XCTAssertEqual(TextActions.count("하나. 둘. 셋.", unit: .sentences).text, "3")
        // 종결부호가 없어도 0이 되지 않는다 — 0으로 보고하면 데이터 손상으로 보인다
        XCTAssertEqual(TextActions.count("끝맺음이 없음", unit: .sentences).text, "1")
    }

    func testCountEmptyIsFailure() {
        XCTAssertEqual(TextActions.count("", unit: .characters), .failure(.emptyInput))
    }

    // MARK: - 숫자 형식

    func testFormatNumberDecimalWithGrouping() {
        let out = TextActions.formatNumber("1234567", style: .decimal, decimals: 0, grouping: true, locale: Locale(identifier: "en_US"))
        XCTAssertTrue(out.text.contains("1,234,567"), "천 단위 구분이 빠짐: \(out.text)")
    }

    func testFormatNumberDecimalWithoutGrouping() {
        let out = TextActions.formatNumber("1234567", style: .decimal, decimals: 0, grouping: false, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(out.text, "1234567")
    }

    func testFormatNumberDecimals() {
        let out = TextActions.formatNumber("3.14159", style: .decimal, decimals: 2, grouping: false, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(out.text, "3.14")
    }

    func testFormatNumberPercent() {
        // percent 스타일은 값을 100배로 본다 — 0.5는 50%로 나와야 한다
        let out = TextActions.formatNumber("0.5", style: .percent, decimals: 0, grouping: false, locale: Locale(identifier: "en_US"))
        XCTAssertTrue(out.text.contains("50"), "백분율 변환이 안 됨: \(out.text)")
    }

    func testFormatNumberScientific() {
        let out = TextActions.formatNumber("12345", style: .scientific, decimals: 2, grouping: false, locale: Locale(identifier: "en_US"))
        XCTAssertTrue(out.text.lowercased().contains("e"), "지수 표기가 아님: \(out.text)")
    }

    func testFormatNumberAcceptsFormattedInput() {
        // 통화 기호와 구분자가 붙은 입력을 받아야 한다
        let out = TextActions.formatNumber("$1,234.50", style: .decimal, decimals: 2, grouping: false, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(out.text, "1234.50")
    }

    func testFormatNumberRejectsNonNumeric() {
        // 조용히 0을 돌려주면 "서식이 이상하다"와 "입력이 틀렸다"를 구분할 수 없다
        XCTAssertEqual(
            TextActions.formatNumber("앨범", style: .decimal, decimals: 0, grouping: false),
            .failure(.nonNumericInput("앨범"))
        )
    }

    func testFormatNumberEmptyIsFailure() {
        XCTAssertEqual(TextActions.formatNumber("", style: .decimal, decimals: 0, grouping: false), .failure(.emptyInput))
    }

    // MARK: - 클립보드 (주입 가능 — 사용자 클립보드를 건드리지 않는다)

    private func makeTestPasteboard() -> NSPasteboard {
        let name = NSPasteboard.Name("ApexKeyTextActionsTests-\(UUID().uuidString)")
        return NSPasteboard(name: name)
    }

    func testClipboardRoundTrip() {
        let pb = makeTestPasteboard()
        XCTAssertTrue(TextActions.setClipboard("복사된 값", pasteboard: pb).isSuccess)
        XCTAssertEqual(TextActions.getClipboard(pasteboard: pb).text, "복사된 값")
    }

    func testClipboardEmptyIsFailure() {
        // 빈 문자열을 클립보드에 쓰면 기존 내용을 지워버린다
        let pb = makeTestPasteboard()
        _ = TextActions.setClipboard("기존 값", pasteboard: pb)
        XCTAssertEqual(TextActions.setClipboard("", pasteboard: pb), .failure(.emptyInput))
        XCTAssertEqual(TextActions.getClipboard(pasteboard: pb).text, "기존 값", "실패한 쓰기가 클립보드를 지웠다")
    }

    func testClipboardEmptyIsFailureToRead() {
        let pb = makeTestPasteboard()
        // 비어 있는 전용 클립보드 → 실패
        XCTAssertEqual(TextActions.getClipboard(pasteboard: pb), .failure(.clipboardUnavailable))
    }

    // MARK: - 설정 디코딩 관대성

    func testConfigDecodesFromEmptyAndGarbage() {
        // actionParameters가 없거나 깨져 있어도 기본 설정으로 떨어져야 한다
        XCTAssertEqual(TextActions.decodeProbe(), TextActionConfig())
    }

    func testConfigRoundTrip() {
        var config = TextActionConfig()
        config.search = "\\d+"
        config.replacement = "#"
        config.countUnit = .words
        config.numberStyle = .percent
        config.decimals = 2
        config.grouping = true
        let data = try? JSONEncoder().encode(config)
        XCTAssertEqual(TextActionConfig.decode(from: data), config)
    }

    func testConfigToleratesMissingKeys() {
        // 관대 디코딩과 같은 계약 — 필드가 빠져도 디코딩되어야 한다
        let json = "{\"search\":\"abc\"}"
        let config = TextActionConfig.decode(from: Data(json.utf8))
        XCTAssertEqual(config.search, "abc")
        XCTAssertNil(config.decimals)
        XCTAssertNil(config.countUnit)
    }
}

private extension TextActions {
    /// 테스트 가독용 헬퍼
    static func decodeProbe() -> TextActionConfig {
        TextActionConfig.decode(from: nil)
    }
}
