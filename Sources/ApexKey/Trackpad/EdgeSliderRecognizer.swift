import Foundation

/// 가장자리 띠 판정 — 순수 구조체(단위 테스트 대상).
///
/// 좌표계: 원시 접점은 **왼쪽 아래가 (0,0), 오른쪽 위가 (1,1)** 이다.
/// 즉 `y`는 위로 갈수록 **커진다**(2026-11-08 실기 확정 — Jitouch 등 실제 앱의
/// 스와이프 방향 판정과 동일). 이 구조체 안에서만 뒤집어 쓰고, 화면 표시는
/// `TrackpadView`가 `1 - y`로 변환한다.
struct EdgeZone {
    let edge: TrackpadEdge
    /// 트랙패드 폭/높이 대비 띠 두께 (0.06 ... 0.25)
    let width: Double

    /// 가장자리에서 안쪽으로의 거리 (0 = 가장자리, 1 = 반대편)
    func depth(_ touch: TrackpadTouch) -> Double {
        switch edge {
        case .right: return 1 - Double(touch.x)
        case .left: return Double(touch.x)
        case .top: return 1 - Double(touch.y)
        case .bottom: return Double(touch.y)
        }
    }

    /// 여유(margin)를 주면 띠 바깥으로 살짝 벗어나도 유지된다(히스테리시스).
    func contains(_ touch: TrackpadTouch, margin: Double = 0) -> Bool {
        depth(touch) <= width + margin
    }

    /// 여러 손가락 입력 — 손가락의 **평균 위치**가 띠 안에 있으면 인정한다.
    ///
    /// 두 손가락은 손가락 굵기 때문에 띠 두께(기본 15% ≈ 2cm)보다 넓게 벌어질 수밖에
    /// 없다. "전부 띠 안"을 요구하면 두 손가락 규칙은 사실상 쓸 수 없다(실기 피드백).
    /// `spread`는 띠 밖으로 허용하는 손가락 간격 상한으로, 손바닥 전체가 걸치는
    /// 오탐을 막는다.
    func containsCentroid(_ touches: [TrackpadTouch], margin: Double = 0, spread: Double = 0) -> Bool {
        guard !touches.isEmpty else { return false }
        let depths = touches.map(depth)
        let mean = depths.reduce(0, +) / Double(depths.count)
        guard mean <= width + margin else { return false }
        return depths.allSatisfy { $0 <= width + margin + spread }
    }

    /// 슬라이더가 움직이는 축의 좌표.
    /// 세로(좌/우 에지)는 y — **위로 밀면 커진다**. 가로(위/아래 에지)는 x.
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
/// 규칙(스파이크 §1-7 합성 검증 + 실기 피드백 반영)
/// 1. 손가락의 평균 위치가 에지 띠 안에 있어야 추적 시작 (두 손가락은 조금 벌어져도 됨)
/// 2. 축 방향으로 `startThreshold` 이상 움직여야 활성화 (오탐 방지)
/// 3. 활성 후 `stepDistance`(14%) 움직일 때마다 1스텝 — **한 번에 1스텝만** 내보낸다.
///    빠른 스와이프는 남은 누적분을 `cooldown` 간격으로 이어서 소화한다(부드러운 체감).
/// 4. 손가락 수가 바뀌거나 띠를 크게 벗어나면 종료
final class EdgeSliderRecognizer {
    enum State: Equatable { case idle, tracking, active }

    /// 1스텝 = 14% 이동 (v0.33.1: 12% → 14%, 실기에서 너무 예민하다는 피드백)
    static let stepDistance: Double = 0.14
    /// 1스텝당 볼륨 변화 (1/16 ≈ 6.25%)
    static let stepValue: Float = 1.0 / 16.0
    /// 빠른 스와이프에서 보관하는 최대 누적분(스텝 수)
    private static let maxResidualSteps = 2
    /// 두 손가락이 띠 밖으로 벌어질 수 있는 허용 폭
    static let fingerSpread: Double = 0.10
    /// 하단 팜 리젝트 영역 (원시 y는 아래가 0)
    private static let thumbZone: Double = 0.15

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
            // 띠를 크게 벗어나면 취소
            guard zone.containsCentroid(touches, margin: 0.06, spread: Self.fingerSpread) else {
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
            guard zone.containsCentroid(touches, margin: 0.10, spread: Self.fingerSpread) else {
                return stopIfNeeded()
            }
            return trackValue(touches: touches, timestamp: frame.timestamp)
        }
    }

    // MARK: - 내부

    private func beginTrackingIfPossible(touches: [TrackpadTouch]) -> [SliderOutput] {
        guard zone.containsCentroid(touches, spread: Self.fingerSpread) else { return [] }
        // 엄지 무시 — 하단 15%에 있는 손가락이 섞여 있으면 이번 터치는 통째로 무시
        if currentRule.ignoreThumb, touches.contains(where: { Double($0.y) < Self.thumbZone }) {
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
        // 원시 y는 위로 갈수록 커진다 → 위로 밀면 (position - last) > 0 = 값 증가
        var movement = position - lastPosition
        lastPosition = position
        if currentRule.inverted { movement = -movement }
        movement *= currentRule.sensitivity

        residual += movement
        // 너무 빠른 스와이프로 누적분이 무한히 쌓이지 않게 제한
        let cap = Self.stepDistance * Double(Self.maxResidualSteps)
        residual = min(max(residual, -cap), cap)

        guard abs(residual) >= Self.stepDistance else { return [] }
        guard timestamp - lastFireTime >= currentRule.cooldown else { return [] }

        let sign: Double = residual > 0 ? 1 : -1
        residual -= sign * Self.stepDistance
        lastFireTime = timestamp
        return [.valueDelta(Float(sign) * Self.stepValue)]
    }

    private func stopIfNeeded() -> [SliderOutput] {
        guard state != .idle else { return [] }
        reset()
        return [.deactivated]
    }
}
