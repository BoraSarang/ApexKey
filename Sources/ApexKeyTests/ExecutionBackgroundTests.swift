import XCTest
import SwiftData
@testable import ApexKey

/// 실행 엔진 백그라운드화 테스트 (E-MAC-ACT-3006)
///
/// 이전에는 핫키 콜백이 메인 스레드에서 `executeWithDetail`을 **동기로** 호출했다.
/// `wait 60초` 단계 하나면 UI가 60초 정지했고, `Process.waitUntilExit`·`pauseUntilInput`도
/// 마찬가지였다. v0.20에서 남긴 `E-MAC-ACT-3006` "호출부 백그라운드화는 후속 과제"가 이것이다.
///
/// 이 테스트는 **멀티스레드 동작을 실제로 재현해 검증한다.** 실행이 우연히 빠르게 끝나면
/// 통과해 버릴 수 있으므로, 실행 시간이 충분히 긴 단계를 쓴다.
@MainActor
final class ExecutionBackgroundTests: XCTestCase {

    private var storeDirectory: URL!
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() async throws {
        try await super.setUp()
        storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ApexKeyExecBgTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        suiteName = "ApexKeyExecBgTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        HotKeyService.shared.unregisterAll()
        defaults?.removePersistentDomain(forName: suiteName)
        if let dir = storeDirectory { try? FileManager.default.removeItem(at: dir) }
        try await super.tearDown()
    }

    private func makeStore() -> ConfigStore {
        ConfigStore(
            storeDirectory: storeDirectory,
            defaults: defaults,
            seedInstalledApps: false,
            registerSystemIntegrations: false
        )
    }

    /// `n`초 대기하는 단계를 갖는 동작
    private func waitShortcut(seconds: String, name: String = "대기") -> ShortcutItem {
        ShortcutItem(
            name: name,
            steps: [ShortcutStep(type: .wait, target: seconds, title: "대기 \(seconds)")]
        )
    }

    // MARK: - 핵심: 호출이 메인을 막지 않는다

    func testExecuteShortcutStatsReturnsBeforeExecutionFinishes() async throws {
        // 1.5초 대기 단계를 던지고, 호출이 **즉시** 돌아오는지 본다.
        // 동기 실행이었다면 여기서 1.5초가 블로킹되어 임계값을 넘는다.
        let store = makeStore()
        let shortcut = waitShortcut(seconds: "1.5")

        let start = Date()
        store.executeShortcutStats(shortcut)
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertLessThan(
            elapsed, 0.4,
            "executeShortcutStats가 메인 스레드를 \(elapsed)초 블록했다 — 백그라운드화되지 않았다"
        )
    }

    func testHandleHotKeyDoesNotBlockOnLongStep() async throws {
        // 핫키 경로도 같은 큐를 타야 한다 (핫키가 동작의 대표 경로)
        let store = makeStore()
        let shortcut = store.addShortcut(name: "긴 동작")
        store.updateShortcutSteps(store.shortcuts[0], steps: [
            ShortcutStep(type: .wait, target: "1.5", title: "대기")
        ])
        let id = try XCTUnwrap(shortcut?.id)

        let start = Date()
        store.handleHotKey(id)
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertLessThan(
            elapsed, 0.4,
            "handleHotKey가 메인 스레드를 \(elapsed)초 블록했다"
        )
    }

    func testMainThreadRemainsResponsiveDuringExecution() async throws {
        // 위 두 테스트는 "빠르게 반환"만 본다. 더 직접적으로 **실행 구간 동안 메인 스레드가
        // 응답 가능한지** 관찰한다.
        //
        // 방법: 백그라운드에서 50ms마다 메인에 닿아본다(`await MainActor.run`).
        // 메인이 막히면 이 호출이 그만큼 밀린다. 최대 지연을 기록해 둔다.
        // - 비동리: 1초 실행 구간 내내 지연이 작다
        // - 동기:   1초 블로킹 동안 한 번의 핑이 ~1초 밀린다
        //
        // 처음엔 `RunLoop.main.run`을 직접 펌프하는 방식으로 썼는데, 전체 스위트에서
        // XCTest 자체 루프와 충돌해 불안정했다. 메인 럴루프에 개입하지 않는 이 방식이 안전하다.
        let store = makeStore()
        guard store.addShortcut(name: "응답성") != nil else { XCTFail(); return }
        store.updateShortcutSteps(store.shortcuts[0], steps: [
            ShortcutStep(type: .wait, target: "1.0", title: "대기")
        ])

        let probe = LatencyProbe()
        let probeTask = Task.detached {
            while !Task.isCancelled {
                let t0 = Date()
                await MainActor.run { _ = Date() }
                probe.record(Date().timeIntervalSince(t0))
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }
        defer { probeTask.cancel() }

        store.executeShortcutStats(store.shortcuts[0])
        let deadline = Date().addingTimeInterval(8)
        while store.shortcuts[0].runCount == 0 && Date() < deadline {
            await Task.yield()
        }
        // 잔여 핀 몇 개를 더 수집한다
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(store.shortcuts[0].runCount, 1, "실행이 완료되지 않았다")
        XCTAssertLessThan(
            probe.maxLatency, 0.5,
            "실행 중 메인 스레드가 \(probe.maxLatency)초간 응답하지 않았다 — UI가 정지했다"
        )
        XCTAssertGreaterThan(probe.samples, 5, "프로브가 충분히 표본을 못 얻었다 — 테스트 신뢰도 없음")
    }

    /// 메인 스레드 왕복 지연 기록기
    private final class LatencyProbe: @unchecked Sendable {
        private let lock = NSLock()
        private var latency: TimeInterval = 0
        private var count = 0
        var maxLatency: TimeInterval { lock.lock(); defer { lock.unlock() }; return latency }
        var samples: Int { lock.lock(); defer { lock.unlock() }; return count }
        func record(_ value: TimeInterval) {
            lock.lock(); latency = max(latency, value); count += 1; lock.unlock()
        }
    }

    // MARK: - 백그라운드로 옮겨도 실행은 여전히 완수된다

    func testExecutionStillCompletesAndUpdatesStats() async throws {
        // "메인을 안 막는다"만 통과해서는 불충분하다. 실제로 실행되어 결과가 반영돼야 한다.
        let store = makeStore()
        guard let created = store.addShortcut(name: "통계 확인") else {
            XCTFail("동작 생성 실패"); return
        }
        store.updateShortcutSteps(store.shortcuts[0], steps: [
            ShortcutStep(type: .wait, target: "0.2", title: "대기")
        ])
        XCTAssertEqual(store.shortcuts[0].runCount, 0)

        store.executeShortcutStats(store.shortcuts[0])

        // 통계 갱신은 메인 콜백이므로 실행 큐를 비워준 뒤 확인한다
        let deadline = Date().addingTimeInterval(5)
        while store.shortcuts[0].runCount == 0 && Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertEqual(
            store.shortcuts[0].runCount, 1,
            "실행이 완료되지 않았거나 통계 반영 콜백이 오지 않았다"
        )
        XCTAssertNotNil(store.shortcuts[0].lastRunAt)
    }

    func testFailureResultStillPropagatesToStats() async throws {
        // 실패한 실행은 통계를 올리지 않아야 한다 (성공 시에만 증가)
        let store = makeStore()
        guard store.addShortcut(name: "실패 동작") != nil else { XCTFail(); return }
        store.updateShortcutSteps(store.shortcuts[0], steps: [
            ShortcutStep(type: .launchApp, target: "", title: "빈 대상")
        ])

        store.executeShortcutStats(store.shortcuts[0])

        let deadline = Date().addingTimeInterval(5)
        while store.shortcuts[0].runCount == 0 && store.shortcuts[0].lastRunAt == nil && Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        // 실행은 끝났어야 한다 (성공이 아니므로 runCount는 0 유지)
        XCTAssertEqual(store.shortcuts[0].runCount, 0, "실패한 실행이 성공으로 집계됨")
        XCTAssertNil(store.shortcuts[0].lastRunAt, "실패한 실행에 lastRunAt이 찍힘")
    }

    // MARK: - 직렬성 보존

    func testExecutionsAreSerializedNotConcurrent() {
        // E-MAC-ACT-3006에서 가장 중요한 계약: 실행이 **겹치지 않는다.**
        // 사이보그 모드는 `ActionExecutor.pauseSemaphore` 하나만 갖기 때문에
        // 겹치면 나중 실행이 앞선 대기를 깨뜨린다. 큐를 `.global`로 바꾸면 이게 깨진다.
        XCTAssertFalse(
            ExecutionEngine.executionQueue === DispatchQueue.global(qos: .userInitiated),
            "실행 큐가 전역 동시 큐와 동일하다"
        )
        // 직렬 큐의 판별 방법: 큐 라벨이 고유해야 한다
        XCTAssertEqual(
            ExecutionEngine.executionQueue.label, "com.borasarang.ApexKey.execution",
            "실행 큐 라벨이 바뀌었다 — 단계 테스트와 핫키 실행이 같은 큐를 공유하는지 확인 필요"
        )
    }

    func testConcurrentInvocationsDoNotOverlap() {
        // 실제로 여러 실행을 겹쳐 요청하고, 실행 구간이 직렬인지 관찰한다.
        // 카운터(진입 시 ++, 종료 시 --)로 최대 동시 실행 수가 1인지 확인한다.
        let counter = OverlapCounter()
        let group = DispatchGroup()
        for _ in 0..<5 {
            ExecutionEngine.executionQueue.async(group: group) {
                counter.enter()
                Thread.sleep(forTimeInterval: 0.03)
                counter.leave()
            }
        }
        group.wait()
        XCTAssertEqual(
            counter.maxObserved, 1,
            "실행이 \(counter.maxObserved)개 동시에 겹쳤다 — 직렬성이 깨졌다"
        )
    }

    /// 동시 진입 횟수를 세는 헬퍼 (락으로 격리)
    private final class OverlapCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var current = 0
        private var peak = 0
        var maxObserved: Int { lock.lock(); defer { lock.unlock() }; return peak }
        func enter() {
            lock.lock(); current += 1; peak = max(peak, current); lock.unlock()
        }
        func leave() {
            lock.lock(); current -= 1; lock.unlock()
        }
    }
}
