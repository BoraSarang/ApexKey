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

    func averageDepth(_ touches: [TrackpadTouch]) -> Double {
        guard !touches.isEmpty else { return 0 }
        return touches.map(depth).reduce(0, +) / Double(touches.count)
    }
}

/// 에지 슬라이더 상태머신 결과
enum SliderOutput: Equatable {
    /// 임계값을 넘어 슬라이더가 켜졌다 (이때부터 포인터 고정·햅틱)
    case activated
    /// 값 변화분 (음수 = 감소). 연속 모드는 매 프레임, 스텝 모드는 1/16 단위.
    case valueDelta(Float)
    /// 손을 떼거나 조건을 벗어나 꺼졌다
    case deactivated
}

/// 가장자리 슬라이더 인식기 — 프레임 단위로 먹이고 이벤트를 받는다.
///
/// v2 규칙 (2026-11-19 재설계)
/// 1. **진입 판정** — 접점이 0 → 1이 되는 순간, 첫 접점이 에지 띠 안에
///    있어야 한다. 손가락을 패드 안쪽에 대고 에지로 걸어오면 시작하지 않는다.
/// 2. **방향 잠금** — 축 방향 이동이 안쪽 이동보다 우세해야 한다. 커서를
///    에지 근처로 옮기는 동작과 구분하기 위해서다.
/// 3. **연속 매핑** — 활성 후 이동량을 그대로 값 변화로 내보낸다(감도 배율만 적용).
/// 4. **최근접 추적** — 슬라이드 중 손바닥·엄지가 얹혀도 처음 손가락을 계속 따라간다.
/// 5. **실패 시 양보** — 애매하면 즉시 세션을 버린다. 스크롤·커서는 건드리지 않는다.
final class EdgeSliderRecognizer {
    enum State: Equatable { case idle, tracking, active }

    // MARK: - 상수

    /// 스텝 모드: 1스텝 = 14% 이동
    static let stepDistance: Double = 0.14
    /// 스텝 모드: 1스텝당 값 변화 (1/16 ≈ 6.25%)
    static let stepValue: Float = 1.0 / 16.0
    /// 두 손가락이 띠 밖으로 벌어질 수 있는 허용 폭
    static let fingerSpread: Double = 0.10
    /// 추적 중 띠 밖 허용 폭 (활성 전)
    static let trackingMargin: Double = 0.06
    /// 활성 후 띠 밖 허용 폭 — 손가락이 조금 흔들려도 유지
    static let activeMargin: Double = 0.10
    /// 축 방향이 안쪽 이동보다 이만큼 우세해야 활성화
    static let axisDominance: Double = 1.2
    /// ⇧ 미세 조정 배율
    static let fineAdjustScale: Double = 0.25
    /// 프레임이 이만큼 끊기면 세션을 버린다 (값 점프 방지)
    static let gapTimeout: Double = 0.5
    /// 하단 팜 리젝트 영역 (원시 y는 아래가 0)
    static let thumbZone: Double = 0.15
    /// 프레임 간 추적점 최대 이동 — 손가락이 바뀐 것으로 판단하는 거리
    static let maxFingerJump: Double = 0.18

    // MARK: - 상태

    private(set) var state: State = .idle
    var isActive: Bool { state == .active }

    private(set) var currentRule: EdgeSliderRule
    private var zone: EdgeZone

    /// 세션 시작 시각(프레임 타임스탬프)
    private var lastFrameTime: Double = 0
    /// 진입 시점의 에지 깊이
    private var entryDepth: Double = 0
    /// 진입 시점의 축 좌표
    private var startAxis: Double = 0
    /// 마지막으로 추적한 접점 (최근접 추적 기준점)
    private var lastPoint: (x: Double, y: Double) = (0, 0)
    /// 마지막 축 좌표
    private var lastAxis: Double = 0
    /// 활성화 시점에 래치한 수정자 (M2)
    private(set) var latchedModifiers: GestureModifiers = []
    /// 마지막 프레임의 수정자 — 억제 여부를 수정자 일치와 함께 판단한다
    private var lastModifiers: GestureModifiers = []
    /// 같은 터치 세션에서 진입에 실패했는가 — 손을 모두 뗄 때까지 재심사하지 않는다
    private var rejectedSession = false

    /// 스텝 모드 누적분
    private var residual: Double = 0
    private var lastFireTime: Double = 0
    /// 연속 모드 누적 이동 (진단·테스트용)
    private(set) var accumulated: Double = 0

    // MARK: - 초기화

    init(rule: EdgeSliderRule) {
        self.currentRule = rule
        self.zone = EdgeZone(edge: rule.edge, width: rule.edgeWidth)
    }

    func update(rule: EdgeSliderRule) {
        self.currentRule = rule
        self.zone = EdgeZone(edge: rule.edge, width: rule.edgeWidth)
        reset()
    }

    func reset() {
        state = .idle
        residual = 0
        accumulated = 0
        lastFrameTime = 0
        lastAxis = 0
        latchedModifiers = []
        lastModifiers = []
        rejectedSession = false
    }

    // MARK: - 파생 상태

    /// 스크롤 억제를 켜야 하는가 — 손가락이 에지를 따라 움직이기 시작한 순간부터.
    /// 단순히 에지에 손을 얹고만 있는 동안에는 켜지 않는다.
    var wantsScrollSuppression: Bool {
        switch state {
        case .idle:
            return false
        case .active:
            // 활성 후에는 래치를 따른다 — 슬라이드 도중 ⌥를 떼도 페이지가 움직이면 안 된다
            return latchedModifiers.intersection(.sliderMask) == currentRule.modifiers
        case .tracking:
            // 수정자가 맞지 않는 규칙은 애초에 이 입력의 주인이 아니다 —
            // ⌥ 규칙이 무수정자 슬라이드에 반응해 페이지를 막으면 안 된다 (M1).
            guard lastModifiers.intersection(.sliderMask) == currentRule.modifiers else { return false }
            return trackingProgress > 0.004
        }
    }

    /// 진입 후 축 방향 이동량 (절댓값)
    var trackingProgress: Double {
        guard state != .idle else { return 0 }
        return abs(lastAxis - startAxis)
    }

    // MARK: - 프레임 처리

    /// 프레임 하나를 처리하고, 발생한 이벤트를 반환한다.
    /// - Parameter modifiers: 이 프레임 시점에 눌린 수정자. 활성화 판정에만 쓴다.
    func feed(_ frame: TrackpadFrame, modifiers: GestureModifiers = []) -> [SliderOutput] {
        // 프레임 공백 — 값이 크게 점프하기 전에 세션을 버린다
        if state != .idle, lastFrameTime > 0, frame.timestamp - lastFrameTime > Self.gapTimeout {
            reset()
            return [.deactivated]
        }

        let touches = frame.touches

        guard !touches.isEmpty else {
            if state == .idle {
                rejectedSession = false
                return []
            }
            return endSession()
        }

        lastModifiers = modifiers
        switch state {
        case .idle:
            return beginSessionIfPossible(touches: touches, timestamp: frame.timestamp)
        case .tracking:
            return continueTracking(touches: touches, timestamp: frame.timestamp, modifiers: modifiers)
        case .active:
            return continueActive(touches: touches, timestamp: frame.timestamp, modifiers: modifiers)
        }
    }

    // MARK: - 세션 시작

    private func beginSessionIfPossible(touches: [TrackpadTouch], timestamp: Double) -> [SliderOutput] {
        guard !rejectedSession else { return [] }
        guard touches.count == currentRule.fingers else {
            // 손가락 수가 다르면 이 규칙의 입력이 아니다. 이번 세션은 건드리지 않는다.
            return []
        }

        // 하단 엄지 영역에서 시작한 입력은 팜으로 본다 (아래 에지 규칙은 예외)
        if currentRule.ignoreThumb, currentRule.edge != .bottom {
            let bottomMost = touches.map { Double($0.y) }.min() ?? 0
            if bottomMost < Self.thumbZone {
                rejectedSession = true
                return []
            }
        }

        guard isEntryAllowed(touches) else {
            // 에지 밖(패드 안쪽)에서 시작한 입력 — 손을 모두 뗄 때까지 재심사하지 않는다
            rejectedSession = true
            return []
        }

        let point = representativePoint(touches)
        state = .tracking
        lastFrameTime = timestamp
        entryDepth = zone.depth(point)
        startAxis = zone.axisPosition(point)
        lastAxis = startAxis
        lastPoint = (Double(point.x), Double(point.y))
        residual = 0
        accumulated = 0
        return []
    }

    /// "밖에서 에지로 들어온" 입력인가.
    /// 한 손가락은 **첫 접점**이 에지 띠 안이어야 하고, 두 손가락은 평균이 띠 안이면
    /// 인정한다(손가락 굵기 때문에 두 접점이 띠보다 넓게 벌어질 수밖에 없다).
    /// 진입은 세션의 첫 프레임에서만 심사하므로, 안쪽에서 시작해 에지로 걸어오는
    /// 커서 이동은 잡지 않는다.
    private func isEntryAllowed(_ touches: [TrackpadTouch]) -> Bool {
        guard let first = touches.first else { return false }
        if touches.count == 1 {
            return zone.depth(first) <= currentRule.edgeWidth
        }
        return zone.containsCentroid(touches, spread: Self.fingerSpread)
    }

    // MARK: - 추적

    private func continueTracking(
        touches: [TrackpadTouch],
        timestamp: Double,
        modifiers: GestureModifiers
    ) -> [SliderOutput] {
        guard let point = trackedPoint(touches) else { return endSession() }

        let depth = zone.depth(point)
        let axis = zone.axisPosition(point)
        lastFrameTime = timestamp
        lastPoint = (Double(point.x), Double(point.y))
        lastAxis = axis

        // 안쪽으로 너무 깊이 들어오면 커서 이동에 양보한다
        guard depth <= currentRule.edgeWidth + Self.trackingMargin else { return endSession() }

        let axisTravel = axis - startAxis
        let depthTravel = depth - entryDepth

        guard abs(axisTravel) >= currentRule.startThreshold else {
            // 축보다 안쪽으로 더 움직였으면 슬라이드 의도가 아니다
            if depthTravel > currentRule.startThreshold { return endSession() }
            return []
        }

        // 방향 잠금 — 축 방향이 우세해야 한다
        guard abs(axisTravel) >= abs(depthTravel) * Self.axisDominance else {
            return endSession()
        }

        // 수정자 정확 일치 (M1). 슬라이더 채널은 ⇧를 쓰지 않는다.
        guard modifiers.intersection(.sliderMask) == currentRule.modifiers else {
            return endSession()
        }

        // 활성화 — 여기까지의 이동분은 버린다(첫 점프 방지).
        // 스텝 모드의 쿨다운은 **스텝 사이** 간격이지 활성화 이후 대기가 아니다.
        state = .active
        latchedModifiers = modifiers
        lastFireTime = 0
        return [.activated]
    }

    private func continueActive(
        touches: [TrackpadTouch],
        timestamp: Double,
        modifiers: GestureModifiers
    ) -> [SliderOutput] {
        guard let point = trackedPoint(touches) else { return endSession() }

        let depth = zone.depth(point)
        let axis = zone.axisPosition(point)
        lastFrameTime = timestamp
        lastPoint = (Double(point.x), Double(point.y))

        // 활성 후에는 조금 더 너그럽게 — 손가락이 흔들려도 유지한다
        guard depth <= currentRule.edgeWidth + Self.activeMargin else { return endSession() }

        var movement = axis - lastAxis
        lastAxis = axis
        guard abs(movement) > 1e-6 else { return [] }

        if currentRule.inverted { movement = -movement }
        movement *= currentRule.sensitivity
        // ⇧는 누르고 있는 동안만 4배 정밀 (래치하지 않는다)
        if modifiers.contains(.shift) {
            movement *= Self.fineAdjustScale
        }

        accumulated += movement

        switch currentRule.mapping {
        case .continuous:
            return [.valueDelta(Float(movement))]
        case .stepped:
            return steppedOutput(movement: movement, timestamp: timestamp)
        }
    }

    // MARK: - 스텝 모드 (고급)

    private func steppedOutput(movement: Double, timestamp: Double) -> [SliderOutput] {
        residual += movement
        // 너무 빠른 스와이프로 누적분이 무한히 쌓이지 않게 제한
        let cap = Self.stepDistance * 2
        residual = min(max(residual, -cap), cap)

        guard abs(residual) >= Self.stepDistance else { return [] }
        guard timestamp - lastFireTime >= currentRule.cooldown else { return [] }

        let sign: Double = residual > 0 ? 1 : -1
        residual -= sign * Self.stepDistance
        lastFireTime = timestamp
        return [.valueDelta(Float(sign) * Self.stepValue)]
    }

    // MARK: - 접점 추적

    /// 마지막 위치에 가장 가까운 접점을 고른다.
    ///
    /// 손가락 수가 늘어나도(손바닥이 얹혀도) 기준점에서 멀리 떨어진 접점은
    /// 후보에서 밀리므로, 원래 손가락을 계속 따라간다.
    private func trackedPoint(_ touches: [TrackpadTouch]) -> TrackpadTouch? {
        guard !touches.isEmpty else { return nil }

        if currentRule.fingers <= 1 {
            guard let nearest = touches.min(by: {
                distanceSquared($0, lastPoint) < distanceSquared($1, lastPoint)
            }) else { return nil }
            guard distance(nearest, lastPoint) <= Self.maxFingerJump else { return nil }
            return nearest
        }

        let sorted = touches.sorted {
            distanceSquared($0, lastPoint) < distanceSquared($1, lastPoint)
        }
        guard sorted.count >= currentRule.fingers else { return nil }
        let chosen = Array(sorted.prefix(currentRule.fingers))
        // 고른 접점들이 서로 멀리 떨어져 있으면 손가락이 바뀐 것으로 본다
        guard chosen.allSatisfy({ distance($0, lastPoint) <= Self.maxFingerJump * 2 }) else {
            return nil
        }
        let meanX = chosen.reduce(0.0) { $0 + Double($1.x) } / Double(chosen.count)
        let meanY = chosen.reduce(0.0) { $0 + Double($1.y) } / Double(chosen.count)
        return TrackpadTouch(x: Float(meanX), y: Float(meanY))
    }

    /// 세션의 대표 접점 (2손가락이면 평균)
    private func representativePoint(_ touches: [TrackpadTouch]) -> TrackpadTouch {
        guard touches.count > 1 else { return touches[0] }
        let meanX = touches.reduce(0.0) { $0 + Double($1.x) } / Double(touches.count)
        let meanY = touches.reduce(0.0) { $0 + Double($1.y) } / Double(touches.count)
        return TrackpadTouch(x: Float(meanX), y: Float(meanY))
    }

    private func distance(_ touch: TrackpadTouch, _ point: (x: Double, y: Double)) -> Double {
        sqrt(distanceSquared(touch, point))
    }

    private func distanceSquared(_ touch: TrackpadTouch, _ point: (x: Double, y: Double)) -> Double {
        let dx = Double(touch.x) - point.x
        let dy = Double(touch.y) - point.y
        return dx * dx + dy * dy
    }

    // MARK: - 종료

    private func endSession() -> [SliderOutput] {
        guard state != .idle else { return [] }
        reset()
        return [.deactivated]
    }
}
