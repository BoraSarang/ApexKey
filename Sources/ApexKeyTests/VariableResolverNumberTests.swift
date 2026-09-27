import XCTest
@testable import ApexKey

/// VariableResolver 수치 변환 회귀 테스트 (PLAN_v0.21 T-142 / E-MAC-VAR-1002)
///
/// 기존 구현은 `if v == v.rounded() { return String(Int(v)) }`였다.
/// `inf`와 `NaN`은 `v == v.rounded()`가 **참**인데 `String(Int(_))`는
/// `fatalError("Double value cannot be converted to Int because it is either
/// infinite or NaN")`로 프로세스를 죽인다.
final class VariableResolverNumberTests: XCTestCase {

    private func stringValue(_ number: Double) -> String {
        VariableResolver.stringValue(.number(number))
    }

    /// 무한대는 크래시 대신 "inf"로 표시되어야 한다
    func testPositiveInfinityDoesNotCrash() {
        XCTAssertEqual(stringValue(Double.infinity), "inf")
    }

    func testNegativeInfinityDoesNotCrash() {
        XCTAssertEqual(stringValue(-Double.infinity), "-inf")
    }

    func testNaNDoesNotCrash() {
        // NaN은 자신과 비교해도 false지만, 경로 보장을 위해 명시 검증
        let result = stringValue(Double.nan)
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.lowercased().contains("nan"))
    }

    /// 2^53 이상은 Double이 정수를 정확히 표현하지 못하므로 정수 포맷 대상이 아니다.
    /// 경계 부근에서 Int(_ ) 변환 트랩이 없어야 한다.
    func testOutOfExactIntegerRangeDoesNotCrash() {
        let boundary = VariableResolver.exactlyRepresentableIntegerBound
        XCTAssertEqual(boundary, 9_007_199_254_740_992.0)
        // 경계값 자체는 정수처럼 보이지만 2^53이라 Double 정밀도 경계 — 크래시 없이 통과해야 한다
        XCTAssertFalse(stringValue(boundary).isEmpty)
        XCTAssertFalse(stringValue(boundary * 2).isEmpty)
        XCTAssertFalse(stringValue(1e300).isEmpty)
        XCTAssertFalse(stringValue(-1e300).isEmpty)
    }

    /// 정상 정수는 기존처럼 ".0" 없이 표시 (회귀 방지)
    func testIntegerFormattingUnchanged() {
        XCTAssertEqual(stringValue(2), "2")
        XCTAssertEqual(stringValue(0), "0")
        XCTAssertEqual(stringValue(-7), "-7")
    }

    /// 정수가 아닌 값은 소수점 표기 유지
    func testFractionalFormattingUnchanged() {
        XCTAssertEqual(stringValue(2.5), "2.5")
        XCTAssertEqual(stringValue(-0.25), "-0.25")
    }

    /// list/dictionary 재귀 경로에서도 크래시가 없어야 한다
    /// (stringValue가 재귀 호출하므로 내부 항목에 inf가 있으면 동일한 결함 발생)
    func testRecursionThroughListAndDictionary() {
        let list = VariableResolver.stringValue(.list([.text("a"), .number(.infinity), .number(3)]))
        XCTAssertEqual(list, "a, inf, 3")

        let dict = VariableResolver.stringValue(.dictionary(["k": .number(.infinity)]))
        XCTAssertEqual(dict, "k: inf")
    }

    /// 디코딩된 blob에 임의의 수치 JSON이 들어와도 크래시 없어야 한다
    /// (PersistedShortcut의 stepsData/variablesData는 값 범위 검증이 없다)
    func testArbitraryDecodedNumbersAreSafe() {
        let raw = #"{"type":"number","value":1e400}"#.data(using: .utf8)!
        let decoded = try? JSONDecoder().decode(VariableValue.self, from: raw)
        // JSONDecoder가 1e400을 inf로 해석하는지 여부는 Swift 버전에 따라 다르므로,
        // 해석되더라도 stringValue가 살아있기만 하면 된다.
        if let value = decoded {
            XCTAssertFalse(VariableResolver.stringValue(value).isEmpty)
        }
    }
}
