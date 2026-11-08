import Foundation

/// 규칙과 무관한 제스처 이벤트 — 라우터가 여기서 규칙을 찾는다.
struct GestureEvent: Equatable {
    enum Kind: Equatable {
        case tap
        case swipe(GestureDirection)
    }

    var kind: Kind
    var fingers: Int
    /// 같은 터치 세션(손을 대고 떼기까지)을 묶는 식별자
    var sessionID: Int
    var timestamp: Double
}

/// 탭·스와이프 인식기 — 규칙을 모른 채 "무슨 제스처였는지"만 판정한다.
///
/// - 탭: 시작 손가락 수가 유지되고, 이동 < 4%, 지속 < 0.35초
/// - 스와이프: 우세 축으로 16% 이상 이동하면 1회. 계속 밀면 16%마다 반복 발생
///   (반복 실행 여부는 규칙이 결정한다)
/// - 세션 도중 손가락 수가 바뀌면 그 세션은 취소
final class GestureRecognizer {
    /// 탭 최대 이동 거리
    private static let tapMovement: Double = 0.04
    /// 탭 최대 지속 시간(초)
    private static let tapDuration: Double = 0.35
    /// 스와이프 1회 인정 거리
    private static let swipeDistance: Double = 0.16

    private var sessionID = 0
    private var startCount = 0
    private var startTime: Double = 0
    private var startCentroid: (x: Double, y: Double) = (0, 0)
    private var lastCentroid: (x: Double, y: Double) = (0, 0)
    private var travel: (x: Double, y: Double) = (0, 0)
    private var cancelled = true
    private var isTracking = false

    func reset() {
        isTracking = false
        cancelled = true
        startCount = 0
        travel = (0, 0)
    }

    func feed(_ frame: TrackpadFrame) -> [GestureEvent] {
        let touches = frame.touches

        guard !touches.isEmpty else {
            return finishSession(timestamp: frame.timestamp)
        }

        let centroid = Self.centroid(touches)

        guard isTracking else {
            beginSession(touches: touches, centroid: centroid, timestamp: frame.timestamp)
            return []
        }

        // 손가락 수가 도중에 바뀌면 취소 (오작동 방지)
        if touches.count != startCount {
            cancelled = true
        }
        guard !cancelled else { return [] }

        let dx = centroid.x - lastCentroid.x
        let dy = centroid.y - lastCentroid.y
        lastCentroid = centroid
        travel.x += dx
        travel.y += dy

        return swipeEventsIfNeeded(timestamp: frame.timestamp)
    }

    // MARK: - 내부

    private func beginSession(touches: [TrackpadTouch], centroid: (x: Double, y: Double), timestamp: Double) {
        isTracking = true
        cancelled = false
        sessionID &+= 1
        startCount = touches.count
        startTime = timestamp
        startCentroid = centroid
        lastCentroid = centroid
        travel = (0, 0)
    }

    private func finishSession(timestamp: Double) -> [GestureEvent] {
        guard isTracking else { return [] }
        defer { reset() }
        guard !cancelled else { return [] }
        let distance = hypot(travel.x, travel.y)
        let duration = timestamp - startTime
        guard startCount >= 2,
              distance < Self.tapMovement,
              duration <= Self.tapDuration else { return [] }
        return [GestureEvent(kind: .tap, fingers: startCount, sessionID: sessionID, timestamp: timestamp)]
    }

    private func swipeEventsIfNeeded(timestamp: Double) -> [GestureEvent] {
        let horizontal = abs(travel.x) >= abs(travel.y)
        let dominant = horizontal ? travel.x : travel.y
        guard abs(dominant) >= Self.swipeDistance else { return [] }

        let direction: GestureDirection
        if horizontal {
            direction = dominant > 0 ? .right : .left
        } else {
            // 원시 좌표는 아래가 0, 위가 1 — 위로 민 것이 dy > 0
            direction = dominant > 0 ? .up : .down
        }

        // 다음 1회를 위해 그 방향 성분만 소비
        if horizontal {
            travel.x -= dominant > 0 ? Self.swipeDistance : -Self.swipeDistance
        } else {
            travel.y -= dominant > 0 ? Self.swipeDistance : -Self.swipeDistance
        }

        return [GestureEvent(kind: .swipe(direction), fingers: startCount, sessionID: sessionID, timestamp: timestamp)]
    }

    private static func centroid(_ touches: [TrackpadTouch]) -> (x: Double, y: Double) {
        guard !touches.isEmpty else { return (0, 0) }
        let sumX = touches.reduce(0.0) { $0 + Double($1.x) }
        let sumY = touches.reduce(0.0) { $0 + Double($1.y) }
        return (sumX / Double(touches.count), sumY / Double(touches.count))
    }
}
