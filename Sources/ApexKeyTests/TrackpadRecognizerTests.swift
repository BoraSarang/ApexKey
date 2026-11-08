import XCTest
@testable import ApexKey

/// 트랙패드 인식기 단위 테스트 — 실제 하드웨어 없이 프레임을 합성해 검증한다.
///
/// 아날로그 입력은 손으로 만져야 알 수 있지만, **판정 규칙**은 순수 함수라
/// 여기서 회귀를 잡는다. 실기 확인은 `docs/FUNCTIONAL_CHECKLIST.md` 항목으로 분리.
final class TrackpadRecognizerTests: XCTestCase {

    // MARK: - 헬퍼

    private func frame(_ touches: [(Float, Float)], at time: Double) -> TrackpadFrame {
        TrackpadFrame(
            timestamp: time,
            touches: touches.map { TrackpadTouch(x: $0.0, y: $0.1) }
        )
    }

    private func rightEdgeRule(
        fingers: Int = 2,
        ignoreThumb: Bool = false,
        cooldown: Double = 0.1
    ) -> EdgeSliderRule {
        EdgeSliderRule(
            edge: .right,
            fingers: fingers,
            cooldown: cooldown,
            ignoreThumb: ignoreThumb
        )
    }

    // MARK: - EdgeZone

    func testEdgeZoneRightContainsOnlyRightBand() {
        let zone = EdgeZone(edge: .right, width: 0.12)
        XCTAssertTrue(zone.contains(TrackpadTouch(x: 0.95, y: 0.5)))
        XCTAssertTrue(zone.contains(TrackpadTouch(x: 0.90, y: 0.5)))
        XCTAssertFalse(zone.contains(TrackpadTouch(x: 0.80, y: 0.5)))
    }

    func testEdgeZoneAllEdges() {
        XCTAssertTrue(EdgeZone(edge: .left, width: 0.1).contains(TrackpadTouch(x: 0.05, y: 0.5)))
        // 원시 y는 아래가 0, 위가 1 — top 에지는 y가 1에 가깝다.
        XCTAssertTrue(EdgeZone(edge: .top, width: 0.1).contains(TrackpadTouch(x: 0.5, y: 0.95)))
        XCTAssertTrue(EdgeZone(edge: .bottom, width: 0.1).contains(TrackpadTouch(x: 0.5, y: 0.05)))
        XCTAssertFalse(EdgeZone(edge: .left, width: 0.1).contains(TrackpadTouch(x: 0.5, y: 0.5)))
        XCTAssertFalse(EdgeZone(edge: .top, width: 0.1).contains(TrackpadTouch(x: 0.5, y: 0.05)))
    }

    /// 두 손가락은 띠 두께보다 넓게 벌어질 수밖에 없다 — 평균 위치로 판정한다.
    func testEdgeZoneAcceptsSpreadTwoFingers() {
        let zone = EdgeZone(edge: .right, width: 0.12)
        let fingers = [TrackpadTouch(x: 0.86, y: 0.5), TrackpadTouch(x: 0.99, y: 0.5)]
        XCTAssertFalse(zone.contains(fingers[0]), "안쪽 손가락은 띠 밖이다")
        XCTAssertTrue(
            zone.containsCentroid(fingers, spread: EdgeSliderRecognizer.fingerSpread),
            "평균이 띠 안이면 두 손가락을 인정해야 한다"
        )
    }

    /// 손바닥처럼 넓게 걸친 입력은 여전히 거부한다.
    func testEdgeZoneRejectsHandSpanningIntoCenter() {
        let zone = EdgeZone(edge: .right, width: 0.15)
        let touches = [TrackpadTouch(x: 0.55, y: 0.5), TrackpadTouch(x: 0.99, y: 0.5)]
        XCTAssertFalse(zone.containsCentroid(touches, spread: EdgeSliderRecognizer.fingerSpread))
    }

    func testAxisPositionUsesYForVerticalAndXForHorizontal() {
        let touch = TrackpadTouch(x: 0.91, y: 0.23)
        XCTAssertEqual(EdgeZone(edge: .right, width: 0.1).axisPosition(touch), 0.23, accuracy: 0.0001)
        XCTAssertEqual(EdgeZone(edge: .top, width: 0.1).axisPosition(touch), 0.91, accuracy: 0.0001)
    }

    // MARK: - 에지 슬라이더 상태머신

    func testSliderActivatesAfterThresholdAndEmitsValue() {
        let recognizer = EdgeSliderRecognizer(rule: rightEdgeRule())
        let start: [(Float, Float)] = [(0.95, 0.60), (0.92, 0.58)]

        XCTAssertEqual(recognizer.feed(frame(start, at: 1.0)), [])
        XCTAssertEqual(recognizer.state, .tracking)

        // 임계값(7%) 통과 → 활성화, 값 변화는 버린다 (위로 밀면 y가 커진다)
        let activate = recognizer.feed(frame([(0.95, 0.68), (0.92, 0.66)], at: 1.1))
        XCTAssertEqual(activate, [.activated])
        XCTAssertTrue(recognizer.isActive)

        // 14% 더 위로 → 1스텝 증가
        let step = recognizer.feed(frame([(0.95, 0.85), (0.92, 0.83)], at: 1.3))
        XCTAssertEqual(step.count, 1)
        if case .valueDelta(let delta) = step[0] {
            XCTAssertEqual(delta, 1.0 / 16.0, accuracy: 0.0001)
        } else {
            XCTFail("valueDelta가 아니다: \(step)")
        }
    }

    /// 실기 피드백의 핵심 — 위로 밀면 커지고 아래로 밀면 작아져야 한다.
    func testSliderUpIncreasesDownDecreases() {
        let up = EdgeSliderRecognizer(rule: rightEdgeRule(cooldown: 0.05))
        _ = up.feed(frame([(0.95, 0.40), (0.92, 0.40)], at: 1.0))
        _ = up.feed(frame([(0.95, 0.50), (0.92, 0.50)], at: 1.05))
        let upStep = up.feed(frame([(0.95, 0.66), (0.92, 0.66)], at: 1.1))
        if case .valueDelta(let delta)? = upStep.first {
            XCTAssertGreaterThan(delta, 0, "위로 밀면 증가")
        } else {
            XCTFail("valueDelta가 아니다: \(upStep)")
        }

        let down = EdgeSliderRecognizer(rule: rightEdgeRule(cooldown: 0.05))
        _ = down.feed(frame([(0.95, 0.70), (0.92, 0.70)], at: 2.0))
        _ = down.feed(frame([(0.95, 0.60), (0.92, 0.60)], at: 2.05))
        let downStep = down.feed(frame([(0.95, 0.44), (0.92, 0.44)], at: 2.1))
        if case .valueDelta(let delta)? = downStep.first {
            XCTAssertLessThan(delta, 0, "아래로 밀면 감소")
        } else {
            XCTFail("valueDelta가 아니다: \(downStep)")
        }
    }

    /// 두 손가락이 띠 밖으로 조금 벌어져도 추적을 시작해야 한다(실기 피드백).
    func testSliderStartsWithSpreadTwoFingers() {
        let recognizer = EdgeSliderRecognizer(rule: rightEdgeRule())
        XCTAssertEqual(recognizer.feed(frame([(0.86, 0.50), (0.99, 0.50)], at: 1.0)), [])
        XCTAssertEqual(recognizer.state, .tracking)
    }

    func testSliderIgnoresWrongFingerCount() {
        let recognizer = EdgeSliderRecognizer(rule: rightEdgeRule(fingers: 2))
        XCTAssertEqual(recognizer.feed(frame([(0.95, 0.6)], at: 1.0)), [])
        XCTAssertEqual(recognizer.state, .idle)
    }

    func testSliderThumbIgnoreRejectsBottomStart() {
        let recognizer = EdgeSliderRecognizer(rule: rightEdgeRule(ignoreThumb: true))
        // 원시 y는 아래가 0 — 하단 15%는 y < 0.15
        XCTAssertEqual(recognizer.feed(frame([(0.95, 0.10), (0.92, 0.08)], at: 1.0)), [])
        XCTAssertEqual(recognizer.state, .idle)
    }

    func testSliderDeactivatesWhenFingersLift() {
        let recognizer = EdgeSliderRecognizer(rule: rightEdgeRule())
        _ = recognizer.feed(frame([(0.95, 0.60), (0.92, 0.58)], at: 1.0))
        _ = recognizer.feed(frame([(0.95, 0.68), (0.92, 0.66)], at: 1.1))
        XCTAssertEqual(recognizer.feed(frame([], at: 1.2)), [.deactivated])
        XCTAssertEqual(recognizer.state, .idle)
    }

    func testSliderCooldownSuppressesRapidSteps() {
        let recognizer = EdgeSliderRecognizer(rule: rightEdgeRule(cooldown: 0.5))
        _ = recognizer.feed(frame([(0.95, 0.60), (0.92, 0.60)], at: 1.0))
        _ = recognizer.feed(frame([(0.95, 0.70), (0.92, 0.70)], at: 1.1))   // 활성화
        let first = recognizer.feed(frame([(0.95, 0.90), (0.92, 0.90)], at: 1.7))
        XCTAssertEqual(first.count, 1)
        let tooSoon = recognizer.feed(frame([(0.95, 1.00), (0.92, 1.00)], at: 1.8))
        XCTAssertEqual(tooSoon, [])
    }

    /// 한 번에 1스텝만 — 빠른 스와이프가 여러 스텝을 한꺼번에 점프하지 않는다.
    func testSliderEmitsAtMostOneStepPerFrame() {
        let recognizer = EdgeSliderRecognizer(rule: rightEdgeRule(cooldown: 0.0))
        _ = recognizer.feed(frame([(0.95, 0.20), (0.92, 0.20)], at: 1.0))
        _ = recognizer.feed(frame([(0.95, 0.30), (0.92, 0.30)], at: 1.1))   // 활성화
        let fast = recognizer.feed(frame([(0.95, 0.90), (0.92, 0.90)], at: 1.15))
        XCTAssertEqual(fast.count, 1, "프레임당 1스텝만 내보낸다")
        if case .valueDelta(let delta)? = fast.first {
            XCTAssertEqual(delta, 1.0 / 16.0, accuracy: 0.0001)
        }
    }

    func testSliderInvertedFlipsDirection() {
        var rule = rightEdgeRule(cooldown: 0.05)
        rule.inverted = true
        let recognizer = EdgeSliderRecognizer(rule: rule)
        _ = recognizer.feed(frame([(0.95, 0.60), (0.92, 0.58)], at: 1.0))
        _ = recognizer.feed(frame([(0.95, 0.68), (0.92, 0.66)], at: 1.1))
        let step = recognizer.feed(frame([(0.95, 0.85), (0.92, 0.83)], at: 1.2))
        if case .valueDelta(let delta)? = step.first {
            XCTAssertLessThan(delta, 0, "반전이면 위로 밀 때 감소해야 한다")
        } else {
            XCTFail("valueDelta가 아니다: \(step)")
        }
    }

    // MARK: - 제스처 인식기

    func testThreeFingerTap() {
        let recognizer = GestureRecognizer()
        _ = recognizer.feed(frame([(0.4, 0.4), (0.5, 0.5), (0.6, 0.4)], at: 2.0))
        let events = recognizer.feed(frame([], at: 2.1))
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.kind, .tap)
        XCTAssertEqual(events.first?.fingers, 3)
    }

    func testFourFingerSwipeLeft() {
        let recognizer = GestureRecognizer()
        _ = recognizer.feed(frame([(0.6, 0.4), (0.7, 0.4), (0.8, 0.4), (0.9, 0.4)], at: 3.0))
        let events = recognizer.feed(frame([(0.3, 0.4), (0.4, 0.4), (0.5, 0.4), (0.6, 0.4)], at: 3.1))
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.kind, .swipe(.left))
    }

    func testSwipeUpAndDownDirections() {
        // 원시 y는 위로 갈수록 커진다 — 위로 민 것은 y 증가.
        let up = GestureRecognizer()
        _ = up.feed(frame([(0.4, 0.4), (0.5, 0.4)], at: 4.0))
        let upEvents = up.feed(frame([(0.4, 0.7), (0.5, 0.7)], at: 4.1))
        XCTAssertEqual(upEvents.first?.kind, .swipe(.up))

        let down = GestureRecognizer()
        _ = down.feed(frame([(0.4, 0.7), (0.5, 0.7)], at: 5.0))
        let downEvents = down.feed(frame([(0.4, 0.4), (0.5, 0.4)], at: 5.1))
        XCTAssertEqual(downEvents.first?.kind, .swipe(.down))
    }

    func testFingerCountChangeCancelsSession() {
        let recognizer = GestureRecognizer()
        _ = recognizer.feed(frame([(0.4, 0.4), (0.5, 0.5)], at: 6.0))
        _ = recognizer.feed(frame([(0.4, 0.4), (0.5, 0.5), (0.6, 0.4)], at: 6.1))
        let events = recognizer.feed(frame([], at: 6.2))
        XCTAssertTrue(events.isEmpty)
    }

    // MARK: - 저장 형식

    func testSliderRuleCodableRoundTrip() throws {
        var rule = EdgeSliderRule()
        rule.edge = .left
        rule.target = .shortcut
        rule.sensitivity = 1.4
        rule.cooldown = 0.4
        let data = try JSONEncoder().encode(rule)
        let decoded = try JSONDecoder().decode(EdgeSliderRule.self, from: data)
        XCTAssertEqual(decoded, rule)
    }

    func testGestureRuleCodableRoundTripWithParameter() throws {
        let rule = GestureRule(
            kind: .swipe,
            fingers: 4,
            direction: .down,
            action: GestureAction(
                kind: .system,
                systemAction: .activateApp,
                systemText: "com.apple.Safari"
            ),
            scope: .apps,
            appBundleIDs: ["com.apple.Safari", "com.apple.finder"]
        )
        let data = try JSONEncoder().encode(rule)
        let decoded = try JSONDecoder().decode(GestureRule.self, from: data)
        XCTAssertEqual(decoded, rule)
        XCTAssertEqual(decoded.action.systemText, "com.apple.Safari")
    }

    /// 이전 버전(파라미터 키 없음)으로 저장된 규칙도 읽혀야 한다 — 롤백 안전.
    func testGestureActionDecodesWithoutSystemText() throws {
        let json = """
        {"kind":"system","menuPath":[],"systemAction":"mute"}
        """.data(using: .utf8)!
        let action = try JSONDecoder().decode(GestureAction.self, from: json)
        XCTAssertEqual(action.systemAction, .mute)
        XCTAssertNil(action.systemText)
    }

    // MARK: - 시스템 볼륨 상수

    func testVolumeStepIsSixteenth() {
        XCTAssertEqual(EdgeSliderRecognizer.stepValue, 1.0 / 16.0, accuracy: 0.0001)
    }

    func testGestureKeyDistinguishesKindFingersAndDirection() {
        var rule = GestureRule(kind: .tap, fingers: 3)
        XCTAssertEqual(rule.gestureKey, "tap:3")
        rule.kind = .swipe
        rule.direction = .left
        XCTAssertEqual(rule.gestureKey, "swipe:3:left")
    }
}
