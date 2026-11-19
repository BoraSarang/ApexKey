import AppKit
import Combine

/// 트랙패드 엔진 — 원시 접점 → 규칙 판정 → 실행을 한 곳에서 조립한다.
///
/// 스레드 모델
/// - 접점 콜백은 **메인 스레드가 아니다**. 프레임을 코얼레싱 릴레이로 넘겨
///   메인에서 최신 프레임만 처리한다(밀린 프레임을 쌓지 않는다).
/// - 판정·실행·UI 갱신은 전부 메인 액터.
///
/// v2 (2026-11-19 재설계)
/// - 값은 **절대값 기준**으로 계산한다(`base + travel`). 증분 누적은 오차가 쌓인다.
/// - 포인터 고정·스크롤 억제·햅틱은 **모든 종료 경로**에서 푼다.
/// - 수정자는 프레임 시점 값으로 정확 일치 판정한다.
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
        /// 마지막으로 조절한 값 (볼륨·밝기 공통)
        var value: Float?
        var valueTarget: SliderTarget?
        var lastGesture: String?
        var isSliderActive: Bool = false
        var modifiers: GestureModifiers = []
        var updatedAt: Date = .distantPast
    }

    /// 진행 중인 슬라이더 세션 — 규칙 스냅샷과 절대값 기준점을 함께 들고 있다.
    private struct SliderSession {
        var ruleID: UUID
        var edge: TrackpadEdge
        var target: SliderTarget
        var suppressScroll: Bool
        var values: SliderValueAccumulator?
        var lastAppliedValue: Float?
        /// 워크플로우 연속 모드용 누적 — 값처럼 0...1로 자르지 않는다
        var shortcutTravel: Float = 0
        var lastHapticBucket: Int = Int.min
        var startedAt: TimeInterval
    }

    @Published private(set) var status: Status = .off
    @Published private(set) var preview = PreviewState()
    /// 스크롤 억제가 실제로 준비됐는지 (Accessibility 필요)
    @Published private(set) var suppressionReady = false

    private let bridge = MTBridge()
    private let suppressor = ScrollSuppressor()
    private let hud = TrackpadHUD()
    private let relay = FrameRelay()
    private let pointerAnchor = PointerAnchor()
    private let hapticPerformer = NSHapticFeedbackManager.defaultPerformer
    private var cancellables = Set<AnyCancellable>()

    private weak var store: ConfigStore?
    private var sliderRecognizers: [UUID: EdgeSliderRecognizer] = [:]
    private var sliderSession: SliderSession?
    private var isSuppressing = false
    private let gestureRecognizer = GestureRecognizer()
    /// 규칙ID → 이미 실행한 터치 세션 (반복 실행이 꺼진 규칙이 같은 스와이프에 여러 번 뜨는 것을 막는다)
    private var firedSessions: [UUID: Int] = [:]
    private var lastPreviewPush: TimeInterval = 0
    private var lastFrameAt: TimeInterval = 0
    private var lastHapticAt: TimeInterval = 0
    private var watchdogTimer: Timer?

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
                // 여기서 직접 풀지 않으면 스크롤·커서가 영구히 막힌다.
                self.forceCleanup()
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
        forceCleanup()
        bridge.stop()
        suppressor.stop()
        status = .off
        suppressionReady = false
        preview = PreviewState()
        Logger.info("Trackpad", "[TPAD] 엔진 정지")
    }

    /// 앱 종료 등 최후 경로 — 커서·억제·HUD를 무조건 되돌린다.
    func forceCleanup() {
        endSliderSession()
        suppressor.setSwallowing(false)
        isSuppressing = false
        hud.hide()
        resetRecognizers()
    }

    /// 규칙이 바뀌었을 때 인식기 캐시를 정리한다.
    func refreshRules() {
        guard let store else { return }
        let rules = store.trackpadSliders
        let ids = Set(rules.map(\.id))

        // 진행 중인 세션의 규칙이 사라졌거나 수정됐으면 즉시 종료한다
        if let session = sliderSession {
            guard let active = rules.first(where: { $0.id == session.ruleID }), active.enabled else {
                endSliderSession()
                sliderRecognizers = sliderRecognizers.filter { ids.contains($0.key) }
                return
            }
            if sliderRecognizers[active.id]?.currentRule != active {
                endSliderSession()
            }
        }

        sliderRecognizers = sliderRecognizers.filter { ids.contains($0.key) }
        for rule in rules {
            if let recognizer = sliderRecognizers[rule.id], recognizer.currentRule != rule {
                recognizer.update(rule: rule)
            }
        }
    }

    // MARK: - 프레임 처리 (메인)

    private func process(_ frame: TrackpadFrame) {
        guard status == .running, let store else { return }
        lastFrameAt = ProcessInfo.processInfo.systemUptime
        let modifiers = GestureModifiers.current()
        // @Published는 값이 같아도 매번 발행한다 — 125Hz로 뷰를 다시 그리지 않도록 비교한다
        if preview.modifiers != modifiers {
            preview.modifiers = modifiers
        }

        let sliderBusy = processSliders(frame: frame, store: store, modifiers: modifiers)
        if sliderBusy {
            gestureRecognizer.reset()
        } else {
            for event in gestureRecognizer.feed(frame, modifiers: modifiers) {
                handle(event, store: store)
            }
        }
        pushPreview(frame)
    }

    /// - Returns: 슬라이더가 입력을 점유하고 있는가 (제스처 인식에 넘기지 않는다)
    private func processSliders(
        frame: TrackpadFrame,
        store: ConfigStore,
        modifiers: GestureModifiers
    ) -> Bool {
        // 1) 진행 중인 세션
        if let session = sliderSession {
            guard let rule = store.trackpadSliders.first(where: { $0.id == session.ruleID }),
                  rule.enabled else {
                endSliderSession()
                updateSuppression(store: store)
                return false
            }
            let recognizer = recognizer(for: rule)
            for output in recognizer.feed(frame, modifiers: modifiers) {
                handleSliderOutput(output, rule: rule)
            }
            if !recognizer.isActive {
                endSliderSession()
            }
            updateSuppression(store: store)
            return sliderSession != nil
        }

        // 2) 새 세션 탐색 — 모든 규칙을 먹이고, 활성화된 규칙 하나만 채택한다
        var activated: EdgeSliderRule?
        for rule in store.trackpadSliders where rule.enabled {
            let recognizer = recognizer(for: rule)
            for output in recognizer.feed(frame, modifiers: modifiers) {
                if case .activated = output, activated == nil {
                    activated = rule
                }
            }
        }
        if let rule = activated {
            // 이 프레임에서 다른 인식기는 되돌린다 (동시에 두 규칙이 켜지는 것 방지)
            for (id, other) in sliderRecognizers where id != rule.id {
                other.reset()
            }
            if beginSliderSession(rule: rule) {
                // 활성화 프레임은 세션 생성과 같은 프레임이다 — 커서 고정·햅틱을 여기서 처리한다
                handleSliderOutput(.activated, rule: rule)
            } else {
                // 값 API를 쓸 수 없는 환경(밝기 미지원 등) — 입력을 붙잡지 않고 규칙만 건너뛴다
                sliderRecognizers[rule.id]?.reset()
            }
        }
        updateSuppression(store: store)
        return sliderSession != nil
            || sliderRecognizers.values.contains { $0.state != .idle }
    }

    // MARK: - 슬라이더 세션

    /// - Returns: 세션이 실제로 시작됐는가. 값 대상의 API를 쓸 수 없으면 `false`
    ///   (스크롤·커서를 붙잡지 않고 규칙만 조용히 건너뛴다).
    @discardableResult
    private func beginSliderSession(rule: EdgeSliderRule) -> Bool {
        var session = SliderSession(
            ruleID: rule.id,
            edge: rule.edge,
            target: rule.target,
            suppressScroll: rule.suppressScroll,
            values: nil,
            lastAppliedValue: nil,
            shortcutTravel: 0,
            lastHapticBucket: Int.min,
            startedAt: ProcessInfo.processInfo.systemUptime
        )

        let current: Float?
        switch rule.target {
        case .volume:
            current = SystemVolume.current()
        case .brightness:
            current = DisplayBrightness.shared.current()
        case .shortcut:
            current = nil
        }
        if rule.target != .shortcut {
            guard let current else { return false }
            session.values = SliderValueAccumulator(base: current)
            session.lastAppliedValue = current
            session.lastHapticBucket = bucket(of: current)
        }
        sliderSession = session
        preview.activeEdge = rule.edge
        preview.isSliderActive = true

        // 1손가락 슬라이드는 커서와 같은 입력이다. 여기서는 **위치만 기억**하고,
        // 실제 이동이 시작(활성화)될 때 붙잡는다 — 에지에 스치기만 한 입력이
        // 커서를 얼리지 않도록.
        if rule.fingers <= 1 {
            pointerAnchor.remember()
        }
        startWatchdog()
        return true
    }

    private func handleSliderOutput(_ output: SliderOutput, rule: EdgeSliderRule) {
        switch output {
        case .activated:
            guard sliderSession != nil else { return }
            if rule.fingers <= 1 {
                pointerAnchor.hold()
            }
            // 값 변경이 시작된 순간에만 HUD를 띄운다 — 에지를 스치기만 한 입력에
            // 볼륨 패널이 깜빡이면 "무언가 바뀌었다"는 오해를 준다.
            if let current = sliderSession?.lastAppliedValue {
                preview.value = current
                preview.valueTarget = rule.target
                hud.show(current, target: rule.target, edge: rule.edge)
            }
            haptic(.generic)
        case .valueDelta(let delta):
            applySliderValue(delta, rule: rule)
        case .deactivated:
            endSliderSession()
        }
    }

    private func applySliderValue(_ delta: Float, rule: EdgeSliderRule) {
        guard var session = sliderSession else { return }

        switch rule.target {
        case .volume, .brightness:
            guard var values = session.values else { return }
            let target = values.update(delta: delta)
            session.values = values
            // 0.5% 미만 변화는 무시 — 슬라이더 미세 떨림으로 인한 과호출 방지
            if let last = session.lastAppliedValue, abs(target - last) < 0.005 {
                sliderSession = session
                return
            }
            let applied = rule.target == .volume
                ? SystemVolume.set(target)
                : DisplayBrightness.shared.set(target)
            guard applied else {
                sliderSession = session
                return
            }
            session.lastAppliedValue = target
            sliderSession = session
            preview.value = target
            preview.valueTarget = rule.target
            hud.show(target, target: rule.target, edge: rule.edge)

            let currentBucket = bucket(of: target)
            if currentBucket != session.lastHapticBucket {
                session.lastHapticBucket = currentBucket
                sliderSession = session
                haptic(.alignment)
            }

        case .shortcut:
            guard let shortcutID = rule.shortcutID,
                  let store,
                  let shortcut = store.shortcuts.first(where: { $0.id == shortcutID }) else {
                return
            }
            if rule.mapping == .stepped {
                // 이미 1/16 단위로 온다 — 그대로 1회 실행
                ActionExecutor.shared.execute(shortcut)
                return
            }
            // 연속 모드: 1/16 경계를 넘을 때만 실행한다 (프레임마다 실행 금지)
            let before = session.shortcutTravel
            session.shortcutTravel += delta
            sliderSession = session
            if bucket(of: before) != bucket(of: session.shortcutTravel) {
                ActionExecutor.shared.execute(shortcut)
            }
        }
    }

    private func endSliderSession() {
        guard sliderSession != nil else { return }
        sliderSession = nil
        pointerAnchor.release()
        stopWatchdog()
        if isSuppressing {
            suppressor.setSwallowing(false)
            isSuppressing = false
        }
        preview.isSliderActive = false
        preview.activeEdge = nil
    }

    /// 스크롤 억제는 "손가락이 에지를 따라 움직이기 시작한 순간"부터 켠다.
    /// 에지에 손을 얹고만 있는 동안에는 켜지 않는다(스크롤 오작동 방지).
    /// 수정자가 맞지 않는 규칙은 인식기 쪽에서 스스로 `false`를 돌려준다.
    private func updateSuppression(store: ConfigStore) {
        let wanted: Bool
        if let session = sliderSession {
            let recognizer = sliderRecognizers[session.ruleID]
            wanted = session.suppressScroll && (recognizer?.wantsScrollSuppression ?? false)
        } else {
            wanted = store.trackpadSliders.contains { rule in
                guard rule.enabled, rule.suppressScroll else { return false }
                return sliderRecognizers[rule.id]?.wantsScrollSuppression ?? false
            }
        }
        let next = wanted && suppressionReady
        guard next != isSuppressing else { return }
        isSuppressing = next
        suppressor.setSwallowing(next)
    }

    // MARK: - 제스처

    private func handle(_ event: GestureEvent, store: ConfigStore) {
        let key: String
        switch event.kind {
        case .tap:
            key = "tap:\(event.fingers)"
        case .swipe(let direction):
            key = "swipe:\(event.fingers):\(direction.rawValue)"
        }
        let matchKey = "\(key):m\(event.modifiers.rawValue)"

        // 같은 제스처가 여러 규칙에 걸리면 **나중에 만든 규칙**만 실행한다
        guard let rule = store.trackpadGestures.last(where: {
            $0.enabled && $0.gestureKey == matchKey
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

    // MARK: - 테스트

    /// 시트의 "테스트" 버튼 — 실제 입력 없이 결과를 한 번 보여 준다.
    func runTest(_ rule: EdgeSliderRule) {
        switch rule.target {
        case .volume:
            if let value = SystemVolume.current() {
                hud.show(value, target: .volume, edge: rule.edge)
            }
        case .shortcut:
            guard let store, let id = rule.shortcutID,
                  let shortcut = store.shortcuts.first(where: { $0.id == id }) else { return }
            ActionExecutor.shared.execute(shortcut)
        case .brightness:
            if let value = DisplayBrightness.shared.current() {
                hud.show(value, target: .brightness, edge: rule.edge)
            }
        }
    }

    // MARK: - 햅틱

    private func bucket(of value: Float) -> Int {
        Int((value * 16).rounded(.down))
    }

    /// 햅틱은 30Hz로 제한한다 — 프레임마다 울리면 손끝이 피로하다.
    private func haptic(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastHapticAt >= 1.0 / 30.0 else { return }
        lastHapticAt = now
        hapticPerformer.perform(pattern, performanceTime: .now)
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
        firedSessions.removeAll()
    }

    // MARK: - 워치독

    /// 프레임이 끊겨도 포인터·억제가 잠긴 채 남지 않게 0.25초마다 확인한다.
    private func startWatchdog() {
        watchdogTimer?.invalidate()
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.watchdogTick()
            }
        }
    }

    private func stopWatchdog() {
        watchdogTimer?.invalidate()
        watchdogTimer = nil
    }

    private func watchdogTick() {
        guard sliderSession != nil else {
            stopWatchdog()
            return
        }
        let elapsed = ProcessInfo.processInfo.systemUptime - lastFrameAt
        guard elapsed > 0.5 else { return }
        Logger.error("E-MAC-TPAD-3002", "프레임 \(String(format: "%.2f", elapsed))초 끊김 — 슬라이더 세션을 강제 종료합니다")
        endSliderSession()
        resetRecognizers()
        suppressor.setSwallowing(false)
        isSuppressing = false
    }

    // MARK: - 미리보기 (30Hz)

    private func pushPreview(_ frame: TrackpadFrame) {
        // 손가락이 없고 미리보기도 비어 있으면 아무것도 하지 않는다.
        // (일부 드라이버는 손이 없을 때도 count 0 프레임을 계속 보낸다 —
        //  그대로 두면 유휴 상태에서 초당 30번 뷰를 다시 그린다)
        guard !frame.touches.isEmpty || !preview.touches.isEmpty else { return }
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
