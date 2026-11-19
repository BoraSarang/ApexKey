import XCTest
@testable import ApexKey

/// 터치 프레임 리플레이 — 스파이크에서 검증한 입력 모양을 JSON으로 고정해
/// 인식기 상태머신이 같은 순서로 반응하는지 확인한다.
///
/// fixture는 **합성**이다(실기 채집 프레임은 SPIKE 문서에 수치만 남고 원본은 보관하지 않았다).
/// 실기 채집이 생기면 같은 형식의 JSON으로 교체하면 된다 — 형식은 `TrackpadFrame` 그대로다.
final class TrackpadReplayTests: XCTestCase {

    // MARK: - 오른쪽 에지 · 한 손가락 · 위로 밀기 (v2 기본)

    private let edgeFixture = """
    [
      {"timestamp": 0.000, "touches": [{"x": 0.985, "y": 0.360}]},
      {"timestamp": 0.016, "touches": [{"x": 0.985, "y": 0.400}]},
      {"timestamp": 0.032, "touches": [{"x": 0.985, "y": 0.440}]},
      {"timestamp": 0.048, "touches": [{"x": 0.985, "y": 0.480}]},
      {"timestamp": 0.064, "touches": [{"x": 0.984, "y": 0.530}]},
      {"timestamp": 0.080, "touches": [{"x": 0.984, "y": 0.580}]},
      {"timestamp": 0.096, "touches": [{"x": 0.984, "y": 0.630}]},
      {"timestamp": 0.400, "touches": [{"x": 0.984, "y": 0.680}]},
      {"timestamp": 0.700, "touches": [{"x": 0.984, "y": 0.740}]},
      {"timestamp": 0.716, "touches": []}
    ]
    """

    func testEdgeSliderReplayProducesActivationThenContinuousDeltas() throws {
        var rule = EdgeSliderRule()
        rule.edge = .right
        rule.ignoreThumb = false
        let recognizer = EdgeSliderRecognizer(rule: rule)

        let frames = try JSONDecoder().decode([TrackpadFrame].self, from: Data(edgeFixture.utf8))
        let outputs = frames.flatMap { recognizer.feed($0) }

        let activations = outputs.filter { $0 == .activated }
        XCTAssertEqual(activations.count, 1, "활성화는 한 번이어야 한다: \(outputs)")

        let deltas = outputs.compactMap { output -> Float? in
            if case .valueDelta(let value) = output { return value }
            return nil
        }
        XCTAssertFalse(deltas.isEmpty, "위로 밀었는데 값 변화가 없다: \(outputs)")
        XCTAssertTrue(deltas.allSatisfy { $0 > 0 }, "위로 밀면 값이 커져야 한다: \(deltas)")
        XCTAssertEqual(outputs.last, .deactivated)

        // 연속 매핑 — 마지막 이동분(0.40 → 0.74 = 34%) × 감도 1.5 ≈ 51%
        // (활성화까지의 4%는 첫 점프 방지를 위해 버린다. 스텝처럼 1/16로 뭉개지지 않는다)
        let total = deltas.reduce(0, +)
        XCTAssertEqual(Double(total), 0.34 * 1.5, accuracy: 0.02)
    }

    /// 고급 경로 — 두 손가락 규칙도 같은 fixture(평균 위치)로 동작해야 한다.
    func testTwoFingerReplayStillWorks() throws {
        let fixture = """
        [
          {"timestamp": 0.000, "touches": [{"x": 0.94, "y": 0.360}, {"x": 0.90, "y": 0.380}]},
          {"timestamp": 0.016, "touches": [{"x": 0.94, "y": 0.400}, {"x": 0.90, "y": 0.420}]},
          {"timestamp": 0.032, "touches": [{"x": 0.94, "y": 0.440}, {"x": 0.90, "y": 0.460}]},
          {"timestamp": 0.048, "touches": [{"x": 0.94, "y": 0.480}, {"x": 0.90, "y": 0.500}]},
          {"timestamp": 0.064, "touches": []}
        ]
        """
        let rule = EdgeSliderRule(fingers: 2, sensitivity: 1.0, edgeWidth: 0.15, ignoreThumb: false)
        let recognizer = EdgeSliderRecognizer(rule: rule)

        let frames = try JSONDecoder().decode([TrackpadFrame].self, from: Data(fixture.utf8))
        let outputs = frames.flatMap { recognizer.feed($0) }

        XCTAssertEqual(outputs.filter { $0 == .activated }.count, 1, "\(outputs)")
        let deltas = outputs.compactMap { output -> Float? in
            if case .valueDelta(let value) = output { return value }
            return nil
        }
        XCTAssertFalse(deltas.isEmpty, "\(outputs)")
        XCTAssertTrue(deltas.allSatisfy { $0 > 0 }, "\(deltas)")
        XCTAssertEqual(outputs.last, .deactivated)
    }

    // MARK: - 네 손가락 스와이프 ↑

    private let swipeFixture = """
    [
      {"timestamp": 1.000, "touches": [
        {"x": 0.30, "y": 0.28}, {"x": 0.45, "y": 0.30},
        {"x": 0.60, "y": 0.28}, {"x": 0.75, "y": 0.30}
      ]},
      {"timestamp": 1.020, "touches": [
        {"x": 0.30, "y": 0.38}, {"x": 0.45, "y": 0.40},
        {"x": 0.60, "y": 0.38}, {"x": 0.75, "y": 0.40}
      ]},
      {"timestamp": 1.040, "touches": [
        {"x": 0.30, "y": 0.48}, {"x": 0.45, "y": 0.50},
        {"x": 0.60, "y": 0.48}, {"x": 0.75, "y": 0.50}
      ]},
      {"timestamp": 1.060, "touches": [
        {"x": 0.30, "y": 0.58}, {"x": 0.45, "y": 0.60},
        {"x": 0.60, "y": 0.58}, {"x": 0.75, "y": 0.60}
      ]}
    ]
    """

    func testFourFingerSwipeUpReplay() throws {
        let recognizer = GestureRecognizer()
        let frames = try JSONDecoder().decode([TrackpadFrame].self, from: Data(swipeFixture.utf8))
        let events = frames.flatMap { recognizer.feed($0) }
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.kind, .swipe(.up))
        XCTAssertEqual(events.first?.fingers, 4)
    }

    /// 판정 순간에 눌려 있던 수정자가 이벤트에 실린다 (M2 — 결정 시점 래치).
    func testFourFingerSwipeCarriesModifiers() throws {
        let recognizer = GestureRecognizer()
        let frames = try JSONDecoder().decode([TrackpadFrame].self, from: Data(swipeFixture.utf8))
        let events = frames.flatMap { recognizer.feed($0, modifiers: [.command]) }
        XCTAssertEqual(events.first?.modifiers, [.command])
    }

    // MARK: - 성능 예산

    /// 인식 비용은 프레임당 수 µs여야 한다. 10,000프레임을 1초 안에 처리하지 못하면
    /// 125Hz 입력에서 메인 스레드가 밀린다는 뜻이므로 예산 초과로 본다.
    func testRecognitionThroughputBudget() {
        let gesture = GestureRecognizer()
        let slider = EdgeSliderRecognizer(rule: EdgeSliderRule(ignoreThumb: false))
        let frames: [TrackpadFrame] = (0..<10_000).map { index in
            let phase = Float(index % 100) / 100
            return TrackpadFrame(
                timestamp: Double(index) * 0.008,
                touches: [TrackpadTouch(x: 0.985, y: 0.8 - phase * 0.2)]
            )
        }

        let started = CFAbsoluteTimeGetCurrent()
        for frame in frames {
            _ = slider.feed(frame)
            _ = gesture.feed(frame)
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - started
        XCTAssertLessThan(elapsed, 1.0, "10,000프레임 처리에 \(String(format: "%.3f", elapsed))초 — 예산 1초")
    }
}
