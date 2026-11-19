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

    /// v2 기본값(1손가락·폭 7%·임계값 1.5%·감도 1.5·연속)을 쓰는 규칙
    private func rule(
        modifiers: GestureModifiers = [],
        mapping: SliderMapping = .continuous,
        cooldown: Double = 0.12,
        ignoreThumb: Bool = false
    ) -> EdgeSliderRule {
        EdgeSliderRule(
            cooldown: cooldown,
            ignoreThumb: ignoreThumb,
            modifiers: modifiers,
            mapping: mapping
        )
    }

    /// 오른쪽 에지 최외곽에서 시작해 `startThreshold`를 넘긴 상태까지 진행한다.
    @discardableResult
    private func activate(
        _ recognizer: EdgeSliderRecognizer,
        at time: Double = 1.0,
        modifiers: GestureModifiers = []
    ) -> [SliderOutput] {
        _ = recognizer.feed(frame([(0.98, 0.40)], at: time), modifiers: modifiers)
        return recognizer.feed(frame([(0.98, 0.42)], at: time + 0.02), modifiers: modifiers)
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

    // MARK: - 진입 판정

    /// 패드 안쪽에서 시작한 손가락은 슬라이더가 아니다 — 손을 뗄 때까지 재심사하지 않는다.
    func testSliderRejectsEntryThatStartsInsideThePad() {
        let recognizer = EdgeSliderRecognizer(rule: rule())

        XCTAssertEqual(recognizer.feed(frame([(0.90, 0.50)], at: 1.0)), [])
        XCTAssertEqual(recognizer.state, .idle)

        // 에지로 걸어와도 이번 세션은 시작하지 않는다
        XCTAssertEqual(recognizer.feed(frame([(0.985, 0.50)], at: 1.02)), [])
        XCTAssertEqual(recognizer.state, .idle)

        // 손을 뗀 뒤 새로 대면 인정
        _ = recognizer.feed(frame([], at: 1.04))
        _ = recognizer.feed(frame([(0.985, 0.50)], at: 1.06))
        XCTAssertEqual(recognizer.state, .tracking)
    }

    /// 인식 띠(기본 7%) 안에서 시작하면 인정한다 — 띠 가장자리(6%)도 포함.
    func testEntryAcceptsWholeRecognitionBand() {
        let recognizer = EdgeSliderRecognizer(rule: rule())
        _ = recognizer.feed(frame([(0.94, 0.50)], at: 1.0))
        XCTAssertEqual(recognizer.state, .tracking, "6% 깊이는 기본 띠(7%) 안이다")
    }

    /// 커서를 옮기려고 에지에서 안쪽으로 미는 동작은 양보한다.
    func testSliderYieldsWhenFingerMovesInward() {
        let recognizer = EdgeSliderRecognizer(rule: rule())
        _ = recognizer.feed(frame([(0.97, 0.50)], at: 1.0))
        XCTAssertEqual(recognizer.state, .tracking)

        XCTAssertEqual(recognizer.feed(frame([(0.93, 0.50)], at: 1.02)), [.deactivated])
        XCTAssertEqual(recognizer.state, .idle)
    }

    func testSliderThumbIgnoreRejectsBottomStart() {
        let recognizer = EdgeSliderRecognizer(rule: rule(ignoreThumb: true))
        // 원시 y는 아래가 0 — 하단 15%는 y < 0.15
        XCTAssertEqual(recognizer.feed(frame([(0.98, 0.10)], at: 1.0)), [])
        XCTAssertEqual(recognizer.state, .idle)
    }

    // MARK: - 활성화·연속 매핑

    func testSliderActivatesAfterSmallThreshold() {
        let recognizer = EdgeSliderRecognizer(rule: rule())
        XCTAssertEqual(recognizer.feed(frame([(0.98, 0.40)], at: 1.0)), [])
        XCTAssertEqual(recognizer.state, .tracking)

        XCTAssertEqual(recognizer.feed(frame([(0.98, 0.42)], at: 1.02)), [.activated])
        XCTAssertTrue(recognizer.isActive)
    }

    /// v2의 핵심 — 이동량 × 감도가 그대로 값 변화가 된다(스텝 아님).
    func testContinuousMappingIsProportionalToMovement() {
        let recognizer = EdgeSliderRecognizer(rule: rule())
        activate(recognizer)

        // 4% 이동 × 감도 1.5 = 0.06
        let outputs = recognizer.feed(frame([(0.98, 0.46)], at: 1.04))
        XCTAssertEqual(outputs.count, 1)
        if case .valueDelta(let delta)? = outputs.first {
            XCTAssertEqual(delta, 0.06, accuracy: 0.001)
        } else {
            XCTFail("valueDelta가 아니다: \(outputs)")
        }
    }

    /// 위로 밀면 커지고 아래로 밀면 작아진다.
    func testSliderUpIncreasesDownDecreases() {
        let up = EdgeSliderRecognizer(rule: rule())
        activate(up)
        let upOut = up.feed(frame([(0.98, 0.50)], at: 1.04))
        if case .valueDelta(let delta)? = upOut.first {
            XCTAssertGreaterThan(delta, 0)
        } else {
            XCTFail("valueDelta가 아니다: \(upOut)")
        }

        let down = EdgeSliderRecognizer(rule: rule())
        activate(down, at: 2.0)
        let downOut = down.feed(frame([(0.98, 0.30)], at: 2.04))
        if case .valueDelta(let delta)? = downOut.first {
            XCTAssertLessThan(delta, 0)
        } else {
            XCTFail("valueDelta가 아니다: \(downOut)")
        }
    }

    /// ⇧를 누르고 있는 동안은 4배 정밀.
    func testShiftIsFineAdjust() {
        let recognizer = EdgeSliderRecognizer(rule: rule())
        activate(recognizer)

        let outputs = recognizer.feed(
            frame([(0.98, 0.46)], at: 1.04),
            modifiers: [.shift]
        )
        if case .valueDelta(let delta)? = outputs.first {
            XCTAssertEqual(Double(delta), 0.06 * EdgeSliderRecognizer.fineAdjustScale, accuracy: 0.001)
        } else {
            XCTFail("valueDelta가 아니다: \(outputs)")
        }
    }

    /// 슬라이드 중 손바닥이 얹혀도 처음 손가락을 계속 따라간다.
    func testPalmTouchDoesNotHijackTracking() {
        let recognizer = EdgeSliderRecognizer(rule: rule())
        activate(recognizer)

        let outputs = recognizer.feed(frame([(0.98, 0.46), (0.45, 0.90)], at: 1.04))
        if case .valueDelta(let delta)? = outputs.first {
            XCTAssertEqual(delta, 0.06, accuracy: 0.001, "가까운 손가락(0.98)을 따라가야 한다")
        } else {
            XCTFail("valueDelta가 아니다: \(outputs)")
        }
    }

    func testSliderDeactivatesWhenFingersLift() {
        let recognizer = EdgeSliderRecognizer(rule: rule())
        activate(recognizer)
        XCTAssertEqual(recognizer.feed(frame([], at: 1.2)), [.deactivated])
        XCTAssertEqual(recognizer.state, .idle)
    }

    /// 프레임이 끊겼다 돌아오면 값이 튀지 않도록 세션을 버린다.
    func testGapResetsSession() {
        let recognizer = EdgeSliderRecognizer(rule: rule())
        activate(recognizer)
        XCTAssertEqual(recognizer.feed(frame([(0.98, 0.60)], at: 3.0)), [.deactivated])
        XCTAssertEqual(recognizer.state, .idle)
    }

    // MARK: - 수정자 레이어

    func testModifierRuleRequiresExactMatch() {
        let recognizer = EdgeSliderRecognizer(rule: rule(modifiers: [.option]))

        _ = recognizer.feed(frame([(0.98, 0.40)], at: 1.0))
        XCTAssertEqual(recognizer.feed(frame([(0.98, 0.42)], at: 1.02)), [.deactivated],
                       "⌥ 없이는 발동하지 않는다")

        let matching = EdgeSliderRecognizer(rule: rule(modifiers: [.option]))
        _ = matching.feed(frame([(0.98, 0.40)], at: 1.0))
        XCTAssertEqual(matching.feed(frame([(0.98, 0.42)], at: 1.02), modifiers: [.option]), [.activated])
    }

    /// 수정자가 없는 규칙은 수정자를 누르면 발동하지 않는다 (M3 — 자연스러운 회피구).
    func testUnmodifiedRuleYieldsToModifier() {
        let recognizer = EdgeSliderRecognizer(rule: rule())
        _ = recognizer.feed(frame([(0.98, 0.40)], at: 1.0))
        XCTAssertEqual(recognizer.feed(frame([(0.98, 0.42)], at: 1.02), modifiers: [.command]), [.deactivated])
    }

    // MARK: - 억제 시점

    /// 손을 에지에 얹기만 하면 페이지를 막지 않는다 — 움직이기 시작해야 켠다.
    func testScrollSuppressionWaitsForMovement() {
        let recognizer = EdgeSliderRecognizer(rule: rule())
        _ = recognizer.feed(frame([(0.98, 0.50)], at: 1.0))
        XCTAssertFalse(recognizer.wantsScrollSuppression, "접촉만으로는 억제하지 않는다")

        _ = recognizer.feed(frame([(0.98, 0.502)], at: 1.02))
        XCTAssertFalse(recognizer.wantsScrollSuppression, "0.2% 이동은 아직 아니다")

        _ = recognizer.feed(frame([(0.98, 0.51)], at: 1.04))
        XCTAssertTrue(recognizer.wantsScrollSuppression, "1% 이동하면 억제를 켠다")
    }

    /// 수정자가 맞지 않는 규칙은 억제도 켜지 않는다 (M1).
    func testModifierRuleDoesNotSuppressWithoutModifier() {
        let recognizer = EdgeSliderRecognizer(rule: rule(modifiers: [.option]))
        _ = recognizer.feed(frame([(0.98, 0.50)], at: 1.0))
        _ = recognizer.feed(frame([(0.98, 0.51)], at: 1.02))
        XCTAssertFalse(recognizer.wantsScrollSuppression, "⌥ 없이는 이 규칙의 입력이 아니다")

        let matching = EdgeSliderRecognizer(rule: rule(modifiers: [.option]))
        _ = matching.feed(frame([(0.98, 0.50)], at: 1.0), modifiers: [.option])
        _ = matching.feed(frame([(0.98, 0.51)], at: 1.02), modifiers: [.option])
        XCTAssertTrue(matching.wantsScrollSuppression)
    }

    // MARK: - 고급 경로

    /// 두 손가락 규칙(고급)도 평균 위치로 동작해야 한다.
    func testTwoFingerRuleStillWorks() {
        let rule = EdgeSliderRule(
            fingers: 2,
            sensitivity: 1.0,
            edgeWidth: 0.15,
            ignoreThumb: false
        )
        let recognizer = EdgeSliderRecognizer(rule: rule)

        _ = recognizer.feed(frame([(0.94, 0.40), (0.90, 0.42)], at: 1.0))
        XCTAssertEqual(recognizer.state, .tracking)
        XCTAssertEqual(recognizer.feed(frame([(0.94, 0.43), (0.90, 0.45)], at: 1.02)), [.activated])

        let outputs = recognizer.feed(frame([(0.94, 0.47), (0.90, 0.49)], at: 1.04))
        if case .valueDelta(let delta)? = outputs.first {
            XCTAssertEqual(delta, 0.04, accuracy: 0.001)
        } else {
            XCTFail("valueDelta가 아니다: \(outputs)")
        }
    }

    /// 스텝 모드(고급)는 v0.33 동작을 그대로 유지한다.
    func testSteppedMappingEmitsSixteenths() {
        let recognizer = EdgeSliderRecognizer(rule: rule(mapping: .stepped, cooldown: 0.0))
        activate(recognizer)

        // 14% 이동 = 1스텝
        let outputs = recognizer.feed(frame([(0.98, 0.56)], at: 1.04))
        XCTAssertEqual(outputs.count, 1)
        if case .valueDelta(let delta)? = outputs.first {
            XCTAssertEqual(delta, 1.0 / 16.0, accuracy: 0.0001)
        } else {
            XCTFail("valueDelta가 아니다: \(outputs)")
        }
    }

    func testSteppedMappingRespectsCooldown() {
        let recognizer = EdgeSliderRecognizer(rule: rule(mapping: .stepped, cooldown: 0.5))
        activate(recognizer)
        XCTAssertEqual(recognizer.feed(frame([(0.98, 0.56)], at: 1.04)).count, 1)
        XCTAssertEqual(recognizer.feed(frame([(0.98, 0.70)], at: 1.06)), [])
    }

    // MARK: - 제스처 인식기

    func testFourFingerTap() {
        let recognizer = GestureRecognizer()
        _ = recognizer.feed(frame([(0.4, 0.4), (0.5, 0.5), (0.6, 0.4), (0.7, 0.5)], at: 2.0))
        let events = recognizer.feed(frame([], at: 2.1))
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.kind, .tap)
        XCTAssertEqual(events.first?.fingers, 4)
    }

    /// 탭은 손을 떼는 순간의 수정자를 래치한다 (M2).
    func testTapLatchesModifiersAtRelease() {
        let recognizer = GestureRecognizer()
        _ = recognizer.feed(frame([(0.4, 0.4), (0.5, 0.5), (0.6, 0.4), (0.7, 0.5)], at: 2.0))
        let events = recognizer.feed(frame([], at: 2.1), modifiers: [.option])
        XCTAssertEqual(events.first?.modifiers, [.option])
    }

    func testFiveFingerSwipeLeft() {
        let recognizer = GestureRecognizer()
        let start: [(Float, Float)] = [(0.6, 0.4), (0.7, 0.4), (0.8, 0.4), (0.9, 0.4), (0.5, 0.5)]
        let moved: [(Float, Float)] = [(0.3, 0.4), (0.4, 0.4), (0.5, 0.4), (0.6, 0.4), (0.2, 0.5)]
        _ = recognizer.feed(frame(start, at: 3.0))
        let events = recognizer.feed(frame(moved, at: 3.1))
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.kind, .swipe(.left))
        XCTAssertEqual(events.first?.fingers, 5)
    }

    /// 스와이프로 판정된 세션은 손을 뗄 때 **탭으로 중복 판정하지 않는다**.
    func testSwipeDoesNotAlsoEmitTapOnRelease() {
        let recognizer = GestureRecognizer()
        _ = recognizer.feed(frame([(0.6, 0.4), (0.7, 0.4), (0.8, 0.4), (0.9, 0.4)], at: 4.0))
        let swipes = recognizer.feed(frame([(0.4, 0.4), (0.5, 0.4), (0.6, 0.4), (0.7, 0.4)], at: 4.05))
        XCTAssertEqual(swipes.count, 1)
        XCTAssertEqual(swipes.first?.kind, .swipe(.left))
        XCTAssertEqual(recognizer.feed(frame([], at: 4.2)), [], "스와이프 후 탭이 또 나오면 안 된다")
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
        rule.modifiers = [.option, .command]
        rule.mapping = .stepped
        let data = try JSONEncoder().encode(rule)
        let decoded = try JSONDecoder().decode(EdgeSliderRule.self, from: data)
        XCTAssertEqual(decoded, rule)
    }

    /// v1.8.1까지 저장된 JSON에는 `modifiers`·`mapping` 키가 없다 — 롤백 안전.
    func testLegacySliderJSONDecodesAsSteppedWithoutModifiers() throws {
        let json = """
        {"id":"11111111-1111-1111-1111-111111111111","enabled":true,"edge":"right",
         "fingers":2,"target":"volume","sensitivity":1.0,"inverted":false,
         "edgeWidth":0.15,"startThreshold":0.07,"cooldown":0.12,
         "ignoreThumb":true,"suppressScroll":true}
        """.data(using: .utf8)!
        let rule = try JSONDecoder().decode(EdgeSliderRule.self, from: json)
        XCTAssertEqual(rule.modifiers, [])
        XCTAssertEqual(rule.mapping, .stepped, "기존 규칙은 기존 동작(스텝)을 유지해야 한다")
        XCTAssertEqual(rule.fingers, 2)
    }

    func testGestureRuleCodableRoundTripWithParameter() throws {
        let rule = GestureRule(
            kind: .swipe,
            fingers: 5,
            direction: .down,
            action: GestureAction(
                kind: .system,
                systemAction: .activateApp,
                systemText: "com.apple.Safari"
            ),
            scope: .apps,
            appBundleIDs: ["com.apple.Safari", "com.apple.finder"],
            modifiers: [.control, .shift]
        )
        let data = try JSONEncoder().encode(rule)
        let decoded = try JSONDecoder().decode(GestureRule.self, from: data)
        XCTAssertEqual(decoded, rule)
        XCTAssertEqual(decoded.action.systemText, "com.apple.Safari")
        XCTAssertEqual(decoded.modifiers, [.control, .shift])
    }

    /// 이전 버전(수정자 키 없음)으로 저장된 규칙도 읽혀야 한다.
    func testLegacyGestureJSONDecodesWithoutModifiers() throws {
        let json = """
        {"id":"22222222-2222-2222-2222-222222222222","enabled":true,"kind":"tap",
         "fingers":3,"direction":"left","repeats":false,
         "action":{"kind":"system","menuPath":[],"systemAction":"mute"},
         "scope":"global","appBundleIDs":[]}
        """.data(using: .utf8)!
        let rule = try JSONDecoder().decode(GestureRule.self, from: json)
        XCTAssertEqual(rule.modifiers, [])
        XCTAssertEqual(rule.action.systemAction, .mute)
    }

    // MARK: - 메타데이터

    func testVolumeStepIsSixteenth() {
        XCTAssertEqual(EdgeSliderRecognizer.stepValue, 1.0 / 16.0, accuracy: 0.0001)
    }

    func testGestureKeyIncludesModifiers() {
        var rule = GestureRule(kind: .tap, fingers: 4)
        XCTAssertEqual(rule.gestureKey, "tap:4:m0")
        rule.modifiers = [.option]
        XCTAssertEqual(rule.gestureKey, "tap:4:m2", "⌥ = rawValue 2")
    }

    func testSystemConflictOnlyForThreeOrFourFingerSwipes() {
        XCTAssertTrue(GestureRule(kind: .swipe, fingers: 3).hasSystemConflict)
        XCTAssertTrue(GestureRule(kind: .swipe, fingers: 4).hasSystemConflict)
        XCTAssertFalse(GestureRule(kind: .swipe, fingers: 5).hasSystemConflict)
        XCTAssertFalse(GestureRule(kind: .tap, fingers: 4).hasSystemConflict)
    }

    func testModifierSymbolStringFollowsMacOrder() {
        XCTAssertEqual(GestureModifiers([.command, .option]).symbolString, "⌥⌘")
        XCTAssertEqual(GestureModifiers([]).summaryPrefix, "")
        XCTAssertEqual(GestureModifiers([.control]).symbolString, "⌃")
    }
}
