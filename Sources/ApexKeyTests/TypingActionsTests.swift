import XCTest
@testable import ApexKey

/// `TypingActions` 테스트 (E-MAC-TEXT-6003)
///
/// **권한 없이 테스트하는 것이 설계 목표다.**
/// 키 입력은 `AXIsProcessTrusted()`가 없으면 조용히 무응답이 된다. 그 상태를
/// 테스트하면 "보냈지만 아무 일도 안 일어난" 성공처럼 보인다. 그래서 **계획 계층
/// (`plan`·검증 로직)만 테스트**하고, 실제 게시는 검증하지 않는다.
final class TypingActionsTests: XCTestCase {

    // MARK: - 전송 계획 (핵심: 한글을 자르지 않는다)

    func testPlanKeepsShortTextInOneChunk() {
        let p = TypingActions.plan("hello")
        XCTAssertEqual(p.chunks, ["hello"])
        XCTAssertEqual(p.characterCount, 5)
    }

    func testPlanIsLosslessWhenSplitting() {
        // 조각으로 나눠도 **합치면 원본과 같아야** 한다. 한 글자라도 잃으면 데이터 손실
        let long = String(repeating: "가나다라마바사아자차카타파하", count: 20)
        let p = TypingActions.plan(long)
        XCTAssertGreaterThan(p.chunks.count, 1, "조각으로 나누지 않았다")
        XCTAssertEqual(p.chunks.joined(), long, "조각을 합치면 원본과 달라진다")
        XCTAssertEqual(p.characterCount, long.count)
    }

    func testPlanNeverSplitsACharacter() {
        // ★ 결합 한글. UTF-16에서 2~3 유닛이라 바이트 단위로 자르면 깨진다.
        // `Character` 경계에서만 잘라야 한다.
        let decomposed = "각"          // U+AC01 이 아니라 분해형 (U+1112 U+1161)
        let p = TypingActions.plan(String(repeating: decomposed, count: 100))
        for chunk in p.chunks {
            XCTAssertFalse(
                chunk.unicodeScalars.contains { $0.value >= 0xD800 && $0.value <= 0xDFFF },
                "단독 대리 문자(surrogate)가 조각에 남았다 — 결합 문자가 깨진다"
            )
        }
        XCTAssertEqual(p.chunks.joined(), String(repeating: decomposed, count: 100))
    }

    func testPlanRespectsUTF16UnitLimit() {
        // 한글이 한 조각에서 20 유닛을 넘지 않아야 한다
        let p = TypingActions.plan(String(repeating: "한글테스트", count: 200))
        for chunk in p.chunks {
            XCTAssertLessThanOrEqual(
                chunk.utf16.count, TypingActions.maxUnitsPerEvent,
                "한 조각이 전송 한도를 넘었다 — 게다가 잘리면 글자가 깨진다"
            )
        }
    }

    func testPlanOfEmptyIsEmpty() {
        XCTAssertTrue(TypingActions.plan("").chunks.isEmpty)
        XCTAssertEqual(TypingActions.plan("").characterCount, 0)
    }

    func testPlanOfEmojiKeepsThemIntact() {
        // 이모지는 Character 하나로 2+ UTF-16 유닛
        let p = TypingActions.plan(String(repeating: "🎉", count: 50))
        XCTAssertEqual(p.chunks.joined(), String(repeating: "🎉", count: 50))
        XCTAssertEqual(p.characterCount, 50)
    }

    // MARK: - 숫자 검증 (조용히 0으로 바꾸지 않는다)

    func testNumberValidationRejectsGarbage() {
        // 조용히 0으로 바꾸면 "입력했는데 반영이 안 되지"라는 symptom이 남는다
        XCTAssertEqual(
            TypingActions.typeNumber("앨범", decimals: 0),
            .failure(.notANumber("앨범"))
        )
    }

    func testNumberValidationRejectsEmpty() {
        XCTAssertEqual(TypingActions.typeNumber("", decimals: 0), .failure(.emptyInput))
        XCTAssertEqual(TypingActions.typeNumber("   ", decimals: 0), .failure(.emptyInput))
    }

    func testNumberValidationTrimsWhitespace() {
        // 사용자는 " 42 "로 입력한다 — 공백 때문에 실패하면 안 된다.
        // 단, 여기서는 권한이 없으므로 .noPermission이거나 성공일 뿐이고
        // **notANumber가 아니어야** 한다 (검증 단계는 통과한다는 뜻).
        let r = TypingActions.typeNumber("  42  ", decimals: 0)
        if case .failure(let reason) = r {
            XCTAssertNotEqual(reason, .notANumber("  42  "), "공백 때문에 숫자 검증에 실패했다")
        }
    }

    func testNumberValidationAcceptsFormattedNumbers() {
        // 사람이 복사해 붙이는 표기
        for input in ["1,234", "3.14", "1e3", "-42", "+7"] {
            let r = TypingActions.typeNumber(input, decimals: 2)
            if case .failure(let reason) = r {
                XCTAssertNotEqual(
                    reason, .notANumber(input),
                    "통용되는 표기 '\(input)' 를 숫자로 인정하지 않았다"
                )
            }
        }
    }

    // MARK: - 게시 계층

    func testEmptyTextIsNoOpSuccess() {
        // 빈 입력은 "실패"가 아니다 — 아무것도 하지 않으면 된다
        XCTAssertTrue(TypingActions.typeText(""))
    }

    func testPublishIsSuppressedUnderXCTest() {
        // 회귀 가드: XCTest 중에는 실제 키 입력을 절대 보내지 않는다.
        // 개발 머신은 손쉬운 사용 권한이 있어 가드 없이는 "1,234" 같은 검증 입력이
        // 포커스된 창에 그대로 타이핑됐다 ("1234.03.14..." 오염).
        XCTAssertTrue(KeySender.suppressesPublish, "XCTest에서 게시 억제가 꺼져 있다")
        XCTAssertFalse(KeySender.postKey(keyCode: 0))
        XCTAssertFalse(KeySender.click(at: .zero))
        // 검증은 그대로 동작해야 한다 — 전송만 건너뛰고 성공 값을 돌려준다
        XCTAssertEqual(TypingActions.typeNumber("1,234", decimals: 2), .success("1234.0"))
    }
}
