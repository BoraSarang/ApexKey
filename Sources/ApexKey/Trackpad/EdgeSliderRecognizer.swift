import Foundation

/// 가장자리 띠 판정 — 순수 구조체(단위 테스트 대상).
struct EdgeZone {
    let edge: TrackpadEdge
    /// 트랙패드 폭/높이 대비 띠 두께 (0.06 ... 0.25)
    let width: Double

    /// 여유(margin)를 주면 띠 바깥으로 살짝 벗어나도 유지된다(히스테리시스).
    func contains(_ touch: TrackpadTouch, margin: Double = 0) -> Bool {
        let w = width + margin
        switch edge {
        case .right: return Double(touch.x) >= 1 - w
        case .left: return Double(touch.x) <= w
        case .top: return Double(touch.y) <= w
        case .bottom: return Double(touch.y) >= 1 - w
        }
    }

    /// 슬라이더가 움직이는 축의 좌표.
    /// 세로(좌/우 에지)는 y — 위로 밀면 작아진다. 가로(위/아래 에지)는 x.
    func axisPosition(_ touch: TrackpadTouch) -> Double {
        edge.isVertical ? Double(touch.y) : Double(touch.x)
    }

    func averageAxisPosition(_ touches: [TrackpadTouch]) -> Double {
        guard !touches.isEmpty else { return 0 }
        return touches.map(axisPosition).reduce(0, +) / Double(touches.count)
    }
}

/// 에지 슬라이더 상태머신 결과
enum SliderOutput: Equatable {
    /// 임계값을 넘어 슬라이더가 켜졌다 (이때부터 스크롤 억제)
    case activated
    /// 값 변화 누적분 (음수 = 감소)
    case valueDelta(Float)
    /// 손을 떼거나 조건을 벗어나 꺼졌다
    case deactivated
}

/// 가장자리 슬라이더 인식기 — 프레임 단위로 먹이고 이벤트를 받는다.
///
/// 규칙(스파이크 §1-7 합성 검증 기준)
/// 1. 손가락이 **전부** 에지 띠 안에 있어야 추적 시작
/// 2. 축 방향으로 `startThreshold` 이상 움직여야 활성화 (오탐 방지)
/// 3. 활성 후 `stepDistance`(12%) 움직일 때마다 1스텝, `cooldown` 간격 제한
/// 4. 손가락 수가 바뀌거나 띠를 크게 벗어나면 종료
final class EdgeSliderRecognizer {
    enum State: Equatable { case idle, tracking, active }

    /// 1스텝 = 12% 이동
    static let stepDistance: Double = 0.12
    /// 1스텝당 볼륨 변화 (1/16 ≈ 6.25%)
    static let stepValue: Float = 1.0 / 16.0

    private(set) var state: State = .idle
    var isActive: Bool { state == .active }

    private(set) var currentRule: EdgeSliderRule
    private var zone: EdgeZone
    private var analogFingers: Int

    private var startPosition: Double = 0
    private var lastPosition: Double = 0
    private var residual: Double = 0
    private var lastFireTime: Double = 0

    init(rule: EdgeSliderRule) {
        self.currentRule = rule
        self.zone = EdgeZone(edge: rule.edge, width: rule.edgeWidth)
        self.analogFingers = rule.fingers
    }

    func update(rule: EdgeSliderRule) {
        self.currentRule = rule
        self.zone = EdgeZone(edge: rule.edge, width: rule.edgeWidth)
        self.analogFingers = rule.fingers
        reset()
    }

    func reset() {
        state = .idle
        residual = 0
        lastPosition = 0
    }

    /// 프레임 하나를 처리하고, 발생한 이벤트를 반환한다.
    func feed(_ frame: TrackpadFrame) -> [SliderOutput] {
        let touches = frame.touches

        guard !touches.isEmpty else { return stopIfNeeded() }

        // 손가락 수가 다르면 이 슬라이더의 입력이 아니다
        guard touches.count == analogFingers else { return stopIfNeeded() }

        switch state {
        case .idle:
            return beginTrackingIfPossible(touches: touches)

        case .tracking:
            // 띠를 완전히 벗어나면 취소
            guard touches.allSatisfy({ zone.contains($0, margin: 0.06) }) else {
                return stopIfNeeded()
            }
            let position = zone.averageAxisPosition(touches)
            guard abs(position - startPosition) >= currentRule.startThreshold else { return [] }
            // 임계값 통과 → 활성화. 그때까지의 이동분은 버린다(첫 점프 방지)
            state = .active
            lastPosition = position
            lastFireTime = frame.timestamp
            return [.activated]

        case .active:
            guard touches.allSatisfy({ zone.contains($0, margin: 0.10) }) else {
                return stopIfNeeded()
            }
            return trackValue(touches: touches, timestamp: frame.timestamp)
        }
    }

    // MARK: - 내부

    private func beginTrackingIfPossible(touches: [TrackpadTouch]) -> [SliderOutput] {
        guard touches.allSatisfy({ zone.contains($0) }) else { return [] }
        // 엄지 무시 — 하단 15%에서 시작한 손가락이 섞여 있으면 이번 터치는 통째로 무시
        if currentRule.ignoreThumb, touches.contains(where: { $0.y > 0.85 }) {
            return []
        }
        reset()
        state = .tracking
        startPosition = zone.averageAxisPosition(touches)
        lastPosition = startPosition
        return []
    }

    private func trackValue(touches: [TrackpadTouch], timestamp: Double) -> [SliderOutput] {
        let position = zone.averageAxisPosition(touches)
        // 위로 밀면 y가 작아진다 → 증가로 만들기 위해 (last - current)
        var movement = lastPosition - position
        lastPosition = position
        if currentRule.inverted { movement = -movement }
        movement *= currentRule.sensitivity

        residual += movement
        // 너무 빠른 스와이프로 스텝이 무한히 쌓이지 않게 3스텝까지만 보관
        let cap = Self.stepDistance * 3
        residual = min(max(residual, -cap), cap)

        guard abs(residual) >= Self.stepDistance else { return [] }
        guard timestamp - lastFireTime >= currentRule.cooldown else { return [] }

        let steps = max(1, min(3, Int(abs(residual) / Self.stepDistance)))
        let sign: Double = residual > 0 ? 1 : -1
        residual -= sign * Double(steps) * Self.stepDistance
        lastFireTime = timestamp
        return [.valueDelta(Float(sign) * Float(steps) * Self.stepValue)]
    }

    private func stopIfNeeded() -> [SliderOutput] {
        guard state != .idle else { return [] }
        reset()
        return [.deactivated]
    }
}
