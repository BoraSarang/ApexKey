import XCTest
@testable import ApexKey

/// 절대값 슬라이더 누적 — 볼륨·밝기가 같은 규칙(경계 클램프)을 쓰는지 검증한다.
final class TrackpadValueTests: XCTestCase {

    func testMovesFromBase() {
        var acc = SliderValueAccumulator(base: 0.4)
        XCTAssertEqual(acc.update(delta: 0.2), 0.6, accuracy: 0.0001)
        XCTAssertEqual(acc.travel, 0.2, accuracy: 0.0001)
    }

    /// 100%에서 더 밀어도 이동분이 쌓이지 않아야 반대로 밀 때 즉시 반응한다.
    func testClampsAtOneAndReversesImmediately() {
        var acc = SliderValueAccumulator(base: 0.9)
        XCTAssertEqual(acc.update(delta: 0.5), 1.0, accuracy: 0.0001)
        XCTAssertEqual(acc.travel, 0.1, accuracy: 0.0001)
        XCTAssertEqual(acc.update(delta: -0.1), 0.9, accuracy: 0.0001)
    }

    /// 0%에서도 같은 규칙.
    func testClampsAtZeroAndReversesImmediately() {
        var acc = SliderValueAccumulator(base: 0.1)
        XCTAssertEqual(acc.update(delta: -0.5), 0.0, accuracy: 0.0001)
        XCTAssertEqual(acc.travel, -0.1, accuracy: 0.0001)
        XCTAssertEqual(acc.update(delta: 0.1), 0.1, accuracy: 0.0001)
    }

    func testBaseIsClamped() {
        XCTAssertEqual(SliderValueAccumulator(base: 1.4).base, 1.0, accuracy: 0.0001)
        XCTAssertEqual(SliderValueAccumulator(base: -1).base, 0.0, accuracy: 0.0001)
    }

    /// 밝기는 v2에서 새로 동작하는 대상이다 — 모델에서 빠지지 않았는지 확인.
    func testBrightnessTargetIsAvailable() {
        XCTAssertTrue(SliderTarget.allCases.contains(.brightness))
        XCTAssertFalse(SliderTarget.brightness.displayName.isEmpty)
    }

    /// 실제 밝기 API 경로가 이 러너에서 동작하는지 확인한다.
    /// 디스플레이가 없는 CI 러너에서는 건너뛴다 — 실패가 아니라 측정 불가다.
    func testBrightnessProbeIfAvailable() throws {
        let brightness = DisplayBrightness.shared
        guard brightness.isAvailable else {
            throw XCTSkip("밝기 제어가 가능한 디스플레이가 없습니다")
        }
        let value = try XCTUnwrap(brightness.current())
        XCTAssertTrue((0...1).contains(value), "밝기 값은 0...1 이어야 한다: \(value)")
    }
}
