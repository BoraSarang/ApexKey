import Foundation

/// 호출을 **합쳐서** 나중에 한 번에 처리하는 스케줄러 (E-MAC-STORE-5011)
///
/// 왜 필요한가:
/// 단계 편집 UI는 `onChange(of: steps)`로 `updateShortcutSteps`를 부른다. 스텝 하나를
/// 추가하면 그 변화가 `syncShortcut` → **blob 4컬럼 전체 재인코딩 + SwiftData save**로
/// 직행한다. 사용자가 드래그로 스텝을 재배열하거나 텍스트를 한 글자씩 지우면
/// 그만큼 저장된다. 중간 상태(예: 5단계 중 3단계만 옮긴 상태)가 디스크에 남고,
/// SQLite 트랜잭션도 그만큼 쌓인다.
///
/// **주의 — 무엇을 합치느냐가 중요하다:**
/// 합치는 대상은 "여러 번 호출"이다. **동일 키의 연속 호출**을 합쳐 마지막 값만
/// 남긴다. 서로 다른 키를 합치면 안 된다 — 서로 다른 동작의 저장이 뒤로 밀리면
/// "저장 안 됨"으로 보인다. 그래서 키를 모아 실행 순서를 보존한다.
///
/// **만료 시간 뒤에는 반드시 flush한다.** `schedule`만 호출되고 끝나면 저장이 영영
/// 안 일어난다. 창을 닫을 때 `flushNow()`를 부르는 경로를 함께 둔다.
///
/// 스레드 안전: `NSLock`으로 상태를 보호한다. **`queue.sync`를 쓰지 않는다** —
/// 같은 큐에서 호출하면 즉시 데드락한다(테스트가 `@MainActor`이고 기본 큐가 `.main`
/// 이므로 반드시 만난다). 실행만 큐 위에서 하고, 상태는 잠금으로 지킨다.
final class CoalescingScheduler<Key: Hashable> {

    // MARK: - 설정

    private let delay: TimeInterval
    private let queue: DispatchQueue
    private let lock = NSLock()

    // MARK: - 상태 (항상 lock 아래에서만 접근)

    private var pending: [Key: () -> Void] = [:]
    private var order: [Key] = []
    private var workItem: DispatchWorkItem?
    private var _flushCount = 0

    /// 지금까지 실제 flush된 횟수 (테스트 관측 지점)
    var flushCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _flushCount
    }

    /// 대기 중인 작업 수 (테스트 관측)
    var pendingCount: Int {
        lock.lock(); defer { lock.unlock() }
        return pending.count
    }

    /// - Parameters:
    ///   - delay: 마지막 호출로부터 이 시간이 지나면 flush한다. 기본 0.4초 —
    ///     스텝 편집에서 사람이 멈추는 간격(수십~수백 ms)보다 길어야 중간 상태가 저장되지 않는다
    ///   - queue: flush를 실행할 큐. `ConfigStore`는 `@MainActor`라 기본값은 `.main`
    init(delay: TimeInterval = 0.4, queue: DispatchQueue = .main) {
        self.delay = delay
        self.queue = queue
    }

    deinit { workItem?.cancel() }

    // MARK: - 공개 API

    /// 작업을 예약한다. 같은 키가 이미 대기 중이면 **뒤의 값으로 대체**한다.
    func schedule(_ key: Key, action: @escaping () -> Void) {
        lock.lock()
        if pending[key] == nil { order.append(key) }
        pending[key] = action
        workItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.flushNow() }
        workItem = item
        lock.unlock()

        queue.asyncAfter(deadline: .now() + delay, execute: item)
    }

    /// 대기 중인 작업을 즉시 전부 실행한다 (창 닫기·앱 종료 경로)
    func flushNow() {
        lock.lock()
        guard !pending.isEmpty else { lock.unlock(); return }
        workItem?.cancel()
        workItem = nil
        // 순서를 보존한다 — 나중에 예약된 값이 나중에 실행되어야 한다
        let snapshot = order.compactMap { pending[$0] }
        pending.removeAll()
        order.removeAll()
        _flushCount += 1
        lock.unlock()

        for action in snapshot { action() }
    }

    /// 대기 중인 작업을 버린다 (테스트 격리·명시적 취소)
    func cancelAll() {
        lock.lock()
        workItem?.cancel()
        workItem = nil
        pending.removeAll()
        order.removeAll()
        lock.unlock()
    }
}
