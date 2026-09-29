import XCTest
@testable import ApexKey

/// 수치·날짜·목록 보조 액션 12종 테스트 (E-MAC-TEXT-6002)
///
/// 특히 **계산기 파서**가 위험 요소다. `eval`을 쓰지 않고 재귀 하강으로 직접
/// 파싱하므로, 우선순위·괄호·단항 마이너스·나눗셈 경계를 테스트로 고정한다.
final class DataActionsTests: XCTestCase {

    // MARK: - 대소문자

    func testChangeCaseStyles() {
        XCTAssertEqual(DataActions.changeCase("hello", style: .uppercase).text, "HELLO")
        XCTAssertEqual(DataActions.changeCase("HeLLo", style: .lowercase).text, "hello")
        XCTAssertEqual(DataActions.changeCase("hello world", style: .capitalized).text, "Hello World")
        XCTAssertEqual(DataActions.changeCase("hello world", style: .sentence).text, "Hello world")
    }

    func testChangeCaseCamelAndKebab() {
        XCTAssertEqual(DataActions.changeCase("hello world foo", style: .camel).text, "helloWorldFoo")
        XCTAssertEqual(DataActions.changeCase("Hello World", style: .kebab).text, "hello-world")
        // 구분자 없는 한 단어도 그대로
        XCTAssertEqual(DataActions.changeCase("word", style: .camel).text, "word")
        XCTAssertEqual(DataActions.changeCase("word", style: .kebab).text, "word")
    }

    func testChangeCaseHandlesKorean() {
        // 한글은 uppercased/lowercased에서 변하지 않아야 한다 (터지지 않음)
        XCTAssertEqual(DataActions.changeCase("안녕", style: .uppercase).text, "안녕")
    }

    func testChangeCaseEmptyIsFailure() {
        XCTAssertEqual(DataActions.changeCase("", style: .uppercase), .failure(.emptyInput))
    }

    // MARK: - 정렬

    func testSortAscendingText() {
        XCTAssertEqual(DataActions.sort("banana\napple\ncherry", separator: "", order: .ascending, mode: .text).text,
                       "apple\nbanana\ncherry")
    }

    func testSortDescendingText() {
        XCTAssertEqual(DataActions.sort("banana\napple\ncherry", separator: "", order: .descending, mode: .text).text,
                       "cherry\nbanana\napple")
    }

    func testSortNumeric() {
        // 사전순이면 "10"이 "9"보다 앞에 온다 — 숫자순은 반대
        XCTAssertEqual(DataActions.sort("10\n9\n100", separator: "", order: .ascending, mode: .numeric).text,
                       "9\n10\n100")
    }

    func testSortNumericPutsNonNumbersLast() {
        // 숫자가 아닌 항목을 0으로 취급하면 순서가 거짓말이 된다
        let out = DataActions.sort("5\nabc\n3", separator: "", order: .ascending, mode: .numeric).text
        XCTAssertEqual(out, "3\n5\nabc", "숫자 아닌 항목이 뒤로 가지 않는다")
    }

    func testSortIgnoresEmptyLines() {
        XCTAssertEqual(DataActions.sort("b\n\n\na", separator: "", order: .ascending, mode: .text).text, "a\nb")
    }

    func testSortEmptyIsFailure() {
        XCTAssertEqual(DataActions.sort("", separator: "", order: .ascending, mode: .text), .failure(.emptyInput))
    }

    // MARK: - 감싸기 / 단어 수

    func testSurround() {
        XCTAssertEqual(DataActions.surround("안녕", prefix: "[", suffix: "]").text, "[안녕]")
        XCTAssertEqual(DataActions.surround("안녕", prefix: "", suffix: "!").text, "안녕!")
        XCTAssertEqual(DataActions.surround("안녕", prefix: "", suffix: "").text, "안녕")
    }

    func testWordCount() {
        XCTAssertEqual(DataActions.wordCount("one two three").text, "3")
        // "공백   많음" 은 공백 개수와 무관하게 단어 2개다
        XCTAssertEqual(DataActions.wordCount("  공백   많음  ").text, "2")
        XCTAssertEqual(DataActions.wordCount("하나").text, "1")
    }

    // MARK: - 계산기 (위험 구간)

    func testCalculateOperatorPrecedence() {
        // 곱셈이 덧셈보다 먼저
        XCTAssertEqual(DataActions.calculate("2+3*4").text, "14")
        XCTAssertEqual(DataActions.calculate("2*3+4").text, "10")
    }

    func testCalculateParentheses() {
        XCTAssertEqual(DataActions.calculate("(2+3)*4").text, "20")
        XCTAssertEqual(DataActions.calculate("((1+2)*(3+4))").text, "21")
    }

    func testCalculateRightAssociativePower() {
        // 2^3^2 = 2^(3^2) = 512
        XCTAssertEqual(DataActions.calculate("2^3^2").text, "512")
        XCTAssertEqual(DataActions.calculate("2^10").text, "1024")
    }

    func testCalculateUnaryMinus() {
        XCTAssertEqual(DataActions.calculate("-5+3").text, "-2")
        XCTAssertEqual(DataActions.calculate("3*-2").text, "-6")
        XCTAssertEqual(DataActions.calculate("-(2+3)").text, "-5")
    }

    func testCalculateModulo() {
        XCTAssertEqual(DataActions.calculate("10%3").text, "1")
    }

    func testCalculateFloatingPointNoiseIsCleaned() {
        // 0.1+0.2 = 0.30000000000000004 를 그대로 노출하면 안 된다
        XCTAssertEqual(DataActions.calculate("0.1+0.2").text, "0.3")
    }

    func testCalculateDivisionByZeroIsFailure() {
        // IEEE 754는 inf를 만들지만 그건 오류가 아니라 조용히 이상한 값이다
        let result = DataActions.calculate("1/0")
        XCTAssertFalse(result.isSuccess, "0으로 나누기가 조용히 성공했다")
        XCTAssertEqual(DataActions.calculate("5%0").isSuccess, false)
    }

    func testCalculateMalformedIsFailure() {
        XCTAssertFalse(DataActions.calculate("2+").isSuccess)
        XCTAssertFalse(DataActions.calculate("(1+2").isSuccess)
        XCTAssertFalse(DataActions.calculate("1+2)").isSuccess)
        XCTAssertFalse(DataActions.calculate("abc").isSuccess)
        XCTAssertFalse(DataActions.calculate("2**3").isSuccess, "`**`는 미지원 — 조용히 처리되면 안 된다")
    }

    func testCalculateDeepNestingIsRejectedNotCrashed() {
        // 스택을 터뜨리는 입력. 크래시가 아니라 명시적 실패여야 한다
        let deep = String(repeating: "(", count: 500) + "1" + String(repeating: ")", count: 500)
        let result = DataActions.calculate(deep)
        XCTAssertFalse(result.isSuccess, "깊은 중첩이 제한 없이 처리됐다")
    }

    func testCalculateUnicodeOperators() {
        // 사용자가 복사해 붙일 만한 수학 기호
        XCTAssertEqual(DataActions.calculate("2×3").text, "6")
        XCTAssertEqual(DataActions.calculate("6÷2").text, "3")
        XCTAssertEqual(DataActions.calculate("5−3").text, "2")
    }

    func testCalculateEmptyIsFailure() {
        XCTAssertEqual(DataActions.calculate(""), .failure(.emptyInput))
    }

    // MARK: - 이항 수학

    func testMathOperations() {
        XCTAssertEqual(DataActions.math("3\n4", operation: .add, separator: "\n").text, "7")
        XCTAssertEqual(DataActions.math("3\n4", operation: .subtract, separator: "\n").text, "-1")
        XCTAssertEqual(DataActions.math("3\n4", operation: .multiply, separator: "\n").text, "12")
        XCTAssertEqual(DataActions.math("8\n2", operation: .divide, separator: "\n").text, "4")
        XCTAssertEqual(DataActions.math("10\n3", operation: .modulo, separator: "\n").text, "1")
        XCTAssertEqual(DataActions.math("2\n10", operation: .power, separator: "\n").text, "1024")
        XCTAssertEqual(DataActions.math("5\n3\n9", operation: .max, separator: "\n").text, "9")
        XCTAssertEqual(DataActions.math("5\n3\n9", operation: .min, separator: "\n").text, "3")
    }

    func testMathSumAcceptsManyOperands() {
        XCTAssertEqual(DataActions.math("1\n2\n3\n4", operation: .add, separator: "\n").text, "10")
        XCTAssertEqual(DataActions.math("1*2*3*4", operation: .multiply, separator: "*").text, "24")
    }

    func testMathRequiresTwoOperands() {
        XCTAssertFalse(DataActions.math("5", operation: .add, separator: "\n").isSuccess)
        XCTAssertFalse(DataActions.math("", operation: .add, separator: "\n").isSuccess)
    }

    func testMathNonNumberIsFailure() {
        XCTAssertEqual(
            DataActions.math("3\n앨범", operation: .add, separator: "\n"),
            .failure(.notANumber("앨범"))
        )
    }

    func testMathDivideByZeroIsFailure() {
        XCTAssertEqual(DataActions.math("3\n0", operation: .divide, separator: "\n"), .failure(.divisionByZero))
    }

    // MARK: - 숫자 변환 / 차이

    func testToNumber() {
        XCTAssertEqual(DataActions.toNumber("42", decimals: 0).text, "42")
        XCTAssertEqual(DataActions.toNumber("3.14159", decimals: 2).text, "3.14")
        XCTAssertEqual(DataActions.toNumber("3.7", decimals: 0).text, "4")
        XCTAssertEqual(DataActions.toNumber("1,234", decimals: 0).text, "1234")
    }

    func testToNumberRejectsNonNumeric() {
        XCTAssertEqual(DataActions.toNumber("앨범", decimals: 0), .failure(.notANumber("앨범")))
    }

    func testDifference() {
        XCTAssertEqual(DataActions.difference("10\n3", separator: "\n").text, "7")
        XCTAssertEqual(DataActions.difference("3\n10", separator: "\n").text, "-7")
    }

    func testDifferenceRequiresTwoValues() {
        XCTAssertFalse(DataActions.difference("10", separator: "\n").isSuccess)
    }

    // MARK: - Base64

    func testBase64RoundTrip() {
        let encoded = DataActions.base64("안녕", decode: false)
        XCTAssertTrue(encoded.isSuccess)
        XCTAssertEqual(DataActions.base64(encoded.text, decode: true).text, "안녕")
    }

    func testBase64DecodeFailure() {
        // "!!!" 은 base64가 아니다
        let r = DataActions.base64("!!!", decode: true)
        XCTAssertFalse(r.isSuccess, "잘못된 Base64가 조용히 성공했다")
    }

    func testBase64EmptyIsFailure() {
        XCTAssertEqual(DataActions.base64("", decode: false), .failure(.emptyInput))
    }

    // MARK: - 해시

    func testHashIsDeterministicAndHex() {
        let a = DataActions.hash("안녕", algorithm: .sha256)
        let b = DataActions.hash("안녕", algorithm: .sha256)
        XCTAssertEqual(a.text, b.text, "같은 입력은 같은 해시")
        XCTAssertEqual(a.text.count, 64, "SHA-256은 64자리 16진수")
        XCTAssertTrue(a.text.allSatisfy { $0.isHexDigit })
    }

    func testHashDiffersByInput() {
        XCTAssertNotEqual(
            DataActions.hash("a", algorithm: .sha256).text,
            DataActions.hash("b", algorithm: .sha256).text
        )
    }

    func testHashSha512Length() {
        XCTAssertEqual(DataActions.hash("a", algorithm: .sha512).text.count, 128)
    }

    // MARK: - UUID

    func testGenerateUUIDCount() {
        let one = DataActions.generateUUID(count: 1)
        XCTAssertEqual(one.text.split(separator: "\n").count, 1)
        let five = DataActions.generateUUID(count: 5)
        XCTAssertEqual(five.text.split(separator: "\n").count, 5)
        // 중복되지 않아야 한다
        XCTAssertEqual(Set(five.text.split(separator: "\n")).count, 5)
    }

    func testGenerateUUIDRejectsOutOfRange() {
        XCTAssertFalse(DataActions.generateUUID(count: 0).isSuccess)
        XCTAssertFalse(DataActions.generateUUID(count: 101).isSuccess)
    }

    // MARK: - 날짜

    func testFormatDateWithPattern() {
        let out = DataActions.formatDate("0", format: "yyyy").text
        XCTAssertEqual(out.count, 4, "연도 4자리가 아님: \(out)")
        XCTAssertTrue(out.allSatisfy(\.isNumber))
    }

    func testFormatDateWithTimestampInput() {
        // 0 = 1970-01-01 UTC
        let out = DataActions.formatDate("0", format: "yyyy-MM-dd").text
        XCTAssertTrue(out.contains("1970") || out.contains("1969"), "타임스탬프 해석 실패: \(out)")
    }

    func testFormatDateEmptyInputUsesNow() {
        let out = DataActions.formatDate("", format: "yyyy").text
        XCTAssertEqual(out.count, 4)
    }

    func testFormatDateEmptyPatternIsFailure() {
        XCTAssertFalse(DataActions.formatDate("0", format: "  ").isSuccess)
    }

    func testTimestamp() {
        let ts = DataActions.timestamp(Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(ts.text, "1700000000")
    }
}
