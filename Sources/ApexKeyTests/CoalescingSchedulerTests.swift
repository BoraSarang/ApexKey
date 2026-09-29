import XCTest
@testable import ApexKey

/// 저장 debounce (`CoalescingScheduler`) 테스트 (E-MAC-STORE-5011)
///
/// 스레드 모델 주의 (이 테스트 스위트에서 이미 한 번 배웠다):
/// `RunLoop.main.run`으로 수동 펌프를 돌리면 전체 스위트에서 XCTest 루프와 충돌해
/// 불안정해진다. 여기서는 **백그라운드 큐 + `XCTestExpectation`**으로 대기한다.
/// 펌프가 필요 없으므로 특정 테스트에만 영향이 아니라 전체 실행이 안정적이다.
final class CoalescingSchedulerTests: XCTestCase {

    private let queue = DispatchQueue(label: "scheduler-tests")

    /// 지정된 시간이 지나면 flush되는지 기다린다
    private func waitForFlush<K: Hashable>(_ scheduler: CoalescingScheduler<K>, timeout: TimeInterval) {
        let exp = expectation(description: "flush")
        let poll = DispatchQueue(label: "poll")
        poll.asyncAfter(deadline: .now() + timeout) {
            if scheduler.flushCount > 0 { exp.fulfill() }
            else { XCTFail("시간 내에 flush되지 않았다 — 예약이 유실된다") }
        }
        wait(for: [exp], timeout: timeout + 1.0)
    }

    // MARK: - 핵심: 여러 번 호출 → 한 번

    func testRapidCallsCoalesceIntoOneFlush() {
        // 50번 호출 → flush 1회. 이것이 debounce의 존재 이유다.
        let s = CoalescingScheduler<Int>(delay: 0.15, queue: queue)
        defer { s.cancelAll() }

        var executed: [Int] = []
        for i in 0..<50 {
            s.schedule(i % 5) { executed.append(i) }
        }

        waitForFlush(s, timeout: 0.6)
        Thread.sleep(forTimeInterval: 0.2)      // 추가 flush가 없는지 확인

        XCTAssertEqual(s.flushCount, 1, "50번 호출이 1회로 합쳐지지 않았다")
        XCTAssertEqual(executed.count, 5, "서로 다른 키는 모두 실행돼야 한다 (중복 합침 금지)")
    }

    func testSameKeyKeepsOnlyTheLatestValue() {
        // 같은 키 3번 → 마지막 값만 실행. "마지막에 편집한 내용"이 저장돼야 한다.
        let s = CoalescingScheduler<String>(delay: 0.15, queue: queue)
        defer { s.cancelAll() }

        var executed: [String] = []
        s.schedule("k") { executed.append("1단계") }
        s.schedule("k") { executed.append("2단계") }
        s.schedule("k") { executed.append("3단계") }

        waitForFlush(s, timeout: 0.6)
        XCTAssertEqual(executed, ["3단계"], "마지막 값만 남지 않았다 — 중간 상태가 저장된다")
    }

    // MARK: - 키 격리

    func testDistinctKeysAllRun() {
        // 서로 다른 키를 합치면 "저장 안 됨"으로 보인다
        let s = CoalescingScheduler<UUID>(delay: 0.15, queue: queue)
        defer { s.cancelAll() }

        let ids = (0..<4).map { _ in UUID() }
        var executed: [UUID] = []
        for id in ids { s.schedule(id) { executed.append(id) } }

        waitForFlush(s, timeout: 0.6)
        XCTAssertEqual(Set(executed), Set(ids), "일부 키가 유실됐다")
    }

    func testExecutionOrderFollowsScheduleOrder() {
        // 나중에 예약한 값이 나중에 실행돼야 한다 (순서가 뒤집히면 옛 값이 이긴다)
        let s = CoalescingScheduler<Int>(delay: 0.2, queue: queue)
        defer { s.cancelAll() }

        var executed: [Int] = []
        for i in [3, 1, 2] { s.schedule(i) { executed.append(i) } }

        waitForFlush(s, timeout: 0.8)
        XCTAssertEqual(executed, [3, 1, 2], "실행 순서가 예약 순서와 다르다")
    }

    // MARK: - 유실 방지 (이게 없으면 debounce가 데이터 손실을 만든다)

    func testFlushNowRunsPendingImmediately() {
        // 창을 닫을 때 호출하는 경로. 이것이 없으면 "저장 안 됨" 버그가 된다.
        let s = CoalescingScheduler<Int>(delay: 10.0, queue: queue)   // 자동 flush는 기다리지 않음
        defer { s.cancelAll() }

        var executed: [Int] = []
        s.schedule(1) { executed.append(1) }
        s.schedule(2) { executed.append(2) }
        XCTAssertEqual(s.pendingCount, 2)

        s.flushNow()
        XCTAssertEqual(executed.sorted(), [1, 2], "flushNow가 대기 작업을 실행하지 않았다")
        XCTAssertEqual(s.pendingCount, 0, "flush 후에도 대기 목록이 남아 있다")
    }

    func testFlushNowOnEmptySchedulerIsNoOp() {
        let s = CoalescingScheduler<Int>(delay: 0.1, queue: queue)
        s.flushNow()
        XCTAssertEqual(s.flushCount, 0, "빈 스케줄러에서 flush가 세어졌다")
    }

    func testScheduledWorkAlwaysEventuallyFlushes() {
        // "schedule만 호출되고 끝나면 저장이 영영 안 된다"는 실패 모드를 막는다
        let s = CoalescingScheduler<Int>(delay: 0.1, queue: queue)
        defer { s.cancelAll() }

        let exp = expectation(description: "실행됨")
        var ran = false
        s.schedule(7) {
            ran = true
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
        XCTAssertTrue(ran)
    }

    func testCancelAllDiscardsPending() {
        let s = CoalescingScheduler<Int>(delay: 0.1, queue: queue)
        var executed: [Int] = []
        s.schedule(1) { executed.append(1) }
        s.cancelAll()
        Thread.sleep(forTimeInterval: 0.3)
        XCTAssertTrue(executed.isEmpty, "취소된 작업이 실행됐다")
        XCTAssertEqual(s.flushCount, 0)
    }

    // MARK: - 관측 지점 자체

    func testPendingCountTracksScheduling() {
        // 관측 지점이 틀리면 위 테스트들이 통과할 수 있다
        let s = CoalescingScheduler<Int>(delay: 5.0, queue: queue)
        defer { s.cancelAll() }
        XCTAssertEqual(s.pendingCount, 0)
        s.schedule(1) {}
        XCTAssertEqual(s.pendingCount, 1)
        s.schedule(1) {}          // 같은 키 재예약 → 증가하지 않아야 함
        XCTAssertEqual(s.pendingCount, 1, "같은 키 재예약이 중복으로 세어진다")
        s.schedule(2) {}
        XCTAssertEqual(s.pendingCount, 2)
    }
}
