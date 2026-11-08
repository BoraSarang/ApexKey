import XCTest
@testable import ApexKey

/// 터치 프레임 리플레이 — 스파이크에서 검증한 입력 모양을 JSON으로 고정해
/// 인식기 상태머신이 같은 순서로 반응하는지 확인한다.
///
/// fixture는 **합성**이다(실기 채집 프레임은 SPIKE 문서에 수치만 남고 원본은 보관하지 않았다).
/// 실기 채집이 생기면 같은 형식의 JSON으로 교체하면 된다 — 형식은 `TrackpadFrame` 그대로다.
final class TrackpadReplayTests: XCTestCase {

    // MARK: - 오른쪽 에지 · 두 손가락 · 위로 밀기

    private let edgeFixture = """
    [
      {"timestamp": 0.000, "touches": [{"x": 0.94, "y": 0.640}, {"x": 0.90, "y": 0.620}]},
      {"timestamp": 0.016, "touches": [{"x": 0.94, "y": 0.600}, {"x": 0.90, "y": 0.580}]},
      {"timestamp": 0.032, "touches": [{"x": 0.94, "y": 0.560}, {"x": 0.90, "y": 0.540}]},
      {"timestamp": 0.048, "touches": [{"x": 0.94, "y": 0.520}, {"x": 0.90, "y": 0.500}]},
      {"timestamp": 0.064, "touches": [{"x": 0.94, "y": 0.470}, {"x": 0.90, "y": 0.450}]},
      {"timestamp": 0.080, "touches": [{"x": 0.94, "y": 0.420}, {"x": 0.90, "y": 0.400}]},
      {"timestamp": 0.096, "touches": [{"x": 0.94, "y": 0.370}, {"x": 0.90, "y": 0.350}]},
      {"timestamp": 0.400, "touches": [{"x": 0.94, "y": 0.320}, {"x": 0.90, "y": 0.300}]},
      {"timestamp": 0.700, "touches": [{"x": 0.94, "y": 0.260}, {"x": 0.90, "y": 0.240}]},
      {"timestamp": 0.716, "touches": []}
    ]
    """

    func testEdgeSliderReplayProducesActivationThenVolumeSteps() throws {
        var rule = EdgeSliderRule()
        rule.edge = .right
        rule.fingers = 2
        rule.cooldown = 0.25
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
    }

    // MARK: - 네 손가락 스와이프 ↑

    private let swipeFixture = """
    [
      {"timestamp": 1.000, "touches": [
        {"x": 0.30, "y": 0.72}, {"x": 0.45, "y": 0.70},
        {"x": 0.60, "y": 0.72}, {"x": 0.75, "y": 0.70}
      ]},
      {"timestamp": 1.020, "touches": [
        {"x": 0.30, "y": 0.62}, {"x": 0.45, "y": 0.60},
        {"x": 0.60, "y": 0.62}, {"x": 0.75, "y": 0.60}
      ]},
      {"timestamp": 1.040, "touches": [
        {"x": 0.30, "y": 0.52}, {"x": 0.45, "y": 0.50},
        {"x": 0.60, "y": 0.52}, {"x": 0.75, "y": 0.50}
      ]},
      {"timestamp": 1.060, "touches": [
        {"x": 0.30, "y": 0.42}, {"x": 0.45, "y": 0.40},
        {"x": 0.60, "y": 0.42}, {"x": 0.75, "y": 0.40}
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

    // MARK: - 성능 예산

    /// 인식 비용은 프레임당 수 µs여야 한다. 10,000프레임을 1초 안에 처리하지 못하면
    /// 125Hz 입력에서 메인 스레드가 밀린다는 뜻이므로 예산 초과로 본다.
    func testRecognitionThroughputBudget() {
        let recognizer = GestureRecognizer()
        let slider = EdgeSliderRecognizer(rule: EdgeSliderRule(ignoreThumb: false))
        let frames: [TrackpadFrame] = (0..<10_000).map { index in
            let phase = Float(index % 100) / 100
            return TrackpadFrame(
                timestamp: Double(index) * 0.008,
                touches: [
                    TrackpadTouch(x: 0.94, y: 0.7 - phase * 0.2),
                    TrackpadTouch(x: 0.90, y: 0.69 - phase * 0.2)
                ]
            )
        }

        let started = CFAbsoluteTimeGetCurrent()
        for frame in frames {
            _ = slider.feed(frame)
            _ = recognizer.feed(frame)
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - started
        XCTAssertLessThan(elapsed, 1.0, "10,000프레임 처리에 \(String(format: "%.3f", elapsed))초 — 예산 1초")
    }
}
