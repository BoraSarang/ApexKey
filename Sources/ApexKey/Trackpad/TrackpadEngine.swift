import AppKit
import Combine

/// 트랙패드 엔진 — 원시 접점 → 규칙 판정 → 실행을 한 곳에서 조립한다.
///
/// 스레드 모델
/// - 접점 콜백은 **메인 스레드가 아니다**. 프레임을 코얼레싱 릴레이로 넘겨
///   메인에서 최신 프레임만 처리한다(밀린 프레임을 쌓지 않는다).
/// - 판정·실행·UI 갱신은 전부 메인 액터.
@MainActor
final class TrackpadEngine: ObservableObject {
    static let shared = TrackpadEngine()

    enum Status: Equatable {
        case off
        case running
        /// 이 macOS에서 읽을 수 없음 (프레임워크·레이아웃)
        case unavailable(String)
    }

    /// 트랙패드 스테이션 라이브 미리보기 상태
    struct PreviewState: Equatable {
        var touches: [TrackpadTouch] = []
        var activeEdge: TrackpadEdge?
        var volume: Float?
        var lastGesture: String?
        var updatedAt: Date = .distantPast
    }

    @Published private(set) var status: Status = .off
    @Published private(set) var preview = PreviewState()
    /// 스크롤 억제가 실제로 준비됐는지 (Accessibility 필요)
    @Published private(set) var suppressionReady = false

    private let bridge = MTBridge()
    private let suppressor = ScrollSuppressor()
    private let hud = TrackpadHUD()
    private let relay = FrameRelay()
    private var cancellables = Set<AnyCancellable>()

    private weak var store: ConfigStore?
    private var sliderRecognizers: [UUID: EdgeSliderRecognizer] = [:]
    private var activeSliderID: UUID?
    private let gestureRecognizer = GestureRecognizer()
    /// 규칙ID → 이미 실행한 터치 세션 (반복 실행이 꺼진 규칙이 같은 스와이프에 여러 번 뜨는 것을 막는다)
    private var firedSessions: [UUID: Int] = [:]
    private var lastPreviewPush: TimeInterval = 0

    private init() {
        relay.sink = { [weak self] frame in
            self?.process(frame)
        }
        // 레이아웃이 바뀌어 브리지가 스스로 멈추면 상태도 같이 내린다.
        // (안 그러면 UI가 계속 "사용 가능"으로 보인다)
        NotificationCenter.default.publisher(for: .trackpadUnavailable)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                // 프레임이 끊기면 엔진이 억제를 풀 기회를 영영 잃는다 →
                // 여기서 직접 풀지 않으면 스크롤이 영구히 막힌다.
                self.suppressor.setSwallowing(false)
                self.resetRecognizers()
                self.suppressionReady = false
                self.preview = PreviewState()
                self.status = .unavailable(self.bridge.lastError ?? "layout-mismatch")
            }
            .store(in: &cancellables)
    }

    // MARK: - 수명주기

    /// 저장소 상태에 맞춰 엔진을 켜고 끈다.
    func apply(enabled: Bool, store: ConfigStore) {
        self.store = store
        if enabled {
            start()
        } else {
            stop()
        }
    }

    func start() {
        guard !bridge.isAvailable else {
            status = .running
            return
        }
        guard let store, store.trackpadEnabled else {
            status = .off
            return
        }
        bridge.onFrame = { [relay] frame in relay.push(frame) }
        guard bridge.start() else {
            status = .unavailable(bridge.lastError ?? "unknown")
            Logger.error("E-MAC-TPAD-1010", "트랙패드 시작 실패: \(bridge.lastError ?? "?")")
            return
        }
        status = .running
        suppressionReady = suppressor.prepare()
        resetRecognizers()
        Logger.info("Trackpad", "[TPAD] 엔진 시작 (억제 준비: \(suppressionReady))")
    }

    func stop() {
        guard status != .off else { return }
        bridge.stop()
        suppressor.stop()
        suppressor.setSwallowing(false)
        hud.hide()
        resetRecognizers()
        status = .off
        suppressionReady = false
        preview = PreviewState()
        Logger.info("Trackpad", "[TPAD] 엔진 정지")
    }

    /// 규칙이 바뀌었을 때 인식기 캐시를 정리한다.
    func refreshRules() {
        guard let store else { return }
        let ids = Set(store.trackpadSliders.map(\.id))
        sliderRecognizers = sliderRecognizers.filter { ids.contains($0.key) }
        for rule in store.trackpadSliders {
            if let recognizer = sliderRecognizers[rule.id], recognizer.currentRule != rule {
                recognizer.update(rule: rule)
            }
        }
        if let activeID = activeSliderID, !ids.contains(activeID) {
            activeSliderID = nil
            suppressor.setSwallowing(false)
        }
    }

    // MARK: - 프레임 처리 (메인)

    private func process(_ frame: TrackpadFrame) {
        guard status == .running, let store else { return }
        // ⌥를 누른 채 쓰면 이번 입력은 실행하지 않는다(목업 v4 고급 안내).
        if NSEvent.modifierFlags.contains(.option) {
            pushPreview(frame)
            return
        }

        let sliderActive = processSliders(frame: frame, store: store)
        if sliderActive {
            gestureRecognizer.reset()
        } else {
            for event in gestureRecognizer.feed(frame) {
                handle(event, store: store)
            }
        }
        pushPreview(frame)
    }

    /// - Returns: 어떤 슬라이더든 활성인가
    private func processSliders(frame: TrackpadFrame, store: ConfigStore) -> Bool {
        if let activeID = activeSliderID {
            guard let rule = store.trackpadSliders.first(where: { $0.id == activeID }) else {
                activeSliderID = nil
                suppressor.setSwallowing(false)
                return false
            }
            let recognizer = recognizer(for: rule)
            for output in recognizer.feed(frame) {
                switch output {
                case .activated:
                    break
                case .valueDelta(let delta):
                    apply(delta: delta, rule: rule)
                case .deactivated:
                    break
                }
            }
            // 이벤트가 없는 프레임에도 인식기 상태는 계속 active다 — 상태로 판정한다.
            if !recognizer.isActive {
                activeSliderID = nil
                suppressor.setSwallowing(false)
            }
            return activeSliderID != nil
        }

        // 활성 슬라이더가 없을 때만 새 활성화를 찾는다 (동시에 두 규칙이 켜지는 것 방지)
        var anyTracking = false
        for rule in store.trackpadSliders where rule.enabled {
            let recognizer = recognizer(for: rule)
            for output in recognizer.feed(frame) {
                switch output {
                case .activated:
                    activeSliderID = rule.id
                    // 같은 프레임을 이미 먹인 다른 인식기는 되돌린다
                    for (id, other) in sliderRecognizers where id != rule.id {
                        other.reset()
                    }
                    if rule.suppressScroll, suppressionReady {
                        suppressor.setSwallowing(true)
                    }
                    preview.activeEdge = rule.edge
                    return true
                case .valueDelta(let delta):
                    // 활성화 직후 같은 프레임에 값이 올 수 있다
                    apply(delta: delta, rule: rule)
                case .deactivated:
                    break
                }
            }
            if recognizer.state != .idle {
                anyTracking = true
            }
        }
        // 에지에서 추적 중인 손가락을 제스처로 오인하지 않는다
        return anyTracking
    }

    /// 시트의 "테스트" 버튼 — 실제 입력 없이 결과를 한 번 보여 준다.
    func runTest(_ rule: EdgeSliderRule) {
        switch rule.target {
        case .volume:
            if let value = SystemVolume.current() {
                hud.showVolume(value)
            }
        case .shortcut:
            guard let store, let id = rule.shortcutID,
                  let shortcut = store.shortcuts.first(where: { $0.id == id }) else { return }
            ActionExecutor.shared.execute(shortcut)
        case .brightness:
            break
        }
    }

    private func apply(delta: Float, rule: EdgeSliderRule) {
        switch rule.target {
        case .volume:
            guard let newValue = SystemVolume.adjust(by: delta) else { return }
            hud.showVolume(newValue)
            preview.volume = newValue
        case .shortcut:
            guard let store, let shortcutID = rule.shortcutID,
                  let shortcut = store.shortcuts.first(where: { $0.id == shortcutID }) else { return }
            ActionExecutor.shared.execute(shortcut)
        case .brightness:
            // v0.33 범위 아님 — 규칙 생성 단계에서 막는다
            break
        }
    }

    private func handle(_ event: GestureEvent, store: ConfigStore) {
        let key: String
        switch event.kind {
        case .tap:
            key = "tap:\(event.fingers)"
        case .swipe(let direction):
            key = "swipe:\(event.fingers):\(direction.rawValue)"
        }

        // 같은 제스처가 여러 규칙에 걸리면 **나중에 만든 규칙**만 실행한다
        guard let rule = store.trackpadGestures.last(where: {
            $0.enabled && $0.gestureKey == key
        }) else { return }

        if !rule.repeats {
            if firedSessions[rule.id] == event.sessionID { return }
            firedSessions[rule.id] = event.sessionID
        }

        preview.lastGesture = rule.gestureSummary
        if let failure = TrackpadRouter.execute(rule, store: store) {
            TrackpadRouter.reportFailure(title: rule.gestureSummary, message: failure)
        }
    }

    // MARK: - 인식기 캐시

    private func recognizer(for rule: EdgeSliderRule) -> EdgeSliderRecognizer {
        if let existing = sliderRecognizers[rule.id] {
            if existing.currentRule != rule { existing.update(rule: rule) }
            return existing
        }
        let created = EdgeSliderRecognizer(rule: rule)
        sliderRecognizers[rule.id] = created
        return created
    }

    private func resetRecognizers() {
        sliderRecognizers.values.forEach { $0.reset() }
        sliderRecognizers.removeAll()
        gestureRecognizer.reset()
        activeSliderID = nil
        firedSessions.removeAll()
    }

    // MARK: - 미리보기 (30Hz)

    private func pushPreview(_ frame: TrackpadFrame) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastPreviewPush >= 1.0 / 30.0 else { return }
        lastPreviewPush = now
        var next = preview
        next.touches = frame.touches
        next.updatedAt = Date()
        if next.touches.isEmpty {
            next.activeEdge = nil
        }
        preview = next
    }
}

/// 접점 콜백(백그라운드) → 메인 코얼레싱 릴레이.
/// 프레임이 밀리면 **가장 최근 것만** 전달한다(입력 지연 누적 방지).
private final class FrameRelay {
    private let lock = NSLock()
    private var pending: TrackpadFrame?
    private var scheduled = false
    /// 메인 스레드에서만 읽고 쓴다
    var sink: ((TrackpadFrame) -> Void)?

    func push(_ frame: TrackpadFrame) {
        lock.lock()
        pending = frame
        let needsSchedule = !scheduled
        if needsSchedule { scheduled = true }
        lock.unlock()
        guard needsSchedule else { return }
        DispatchQueue.main.async { [weak self] in
            self?.drain()
        }
    }

    private func drain() {
        lock.lock()
        let frame = pending
        pending = nil
        scheduled = false
        lock.unlock()
        if let frame { sink?(frame) }
    }
}
