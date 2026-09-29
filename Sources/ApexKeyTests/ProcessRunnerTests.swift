import XCTest
@testable import ApexKey

/// ProcessRunner 회귀 테스트 (PLAN_v0.21 T-141 / E-MAC-SCRIPT-6004)
///
/// 기존 구현은 `waitUntilExit()` 후 `readDataToEndOfFile()` 순서로 파이프를 읽었다.
/// macOS 파이프 버퍼(64KiB)를 넘는 출력을 가진 자식 프로세스는 write에서 블로크되어
/// 종료되지 않고, 부모는 종료 완료를 기다리므로 **영구 교착**했다.
/// 핫키 실행 경로가 메인 스레드이므로 이 교착은 앱 전체 정지로 이어진다.
final class ProcessRunnerTests: XCTestCase {

    /// 파이프 버퍼(64KiB)를 확실히 넘는 출력 — 기존 구현이면 교착, 현재 구현이면 정상 반환
    func testLargeOutputDoesNotDeadlock() {
        let byteCount = 512 * 1024
        let run = ProcessRunner.run(
            executable: "/bin/bash",
            arguments: ["-c", "head -c \(byteCount) /dev/zero | tr '\\0' 'a'"]
        )
        XCTAssertNil(run.launchError)
        XCTAssertFalse(run.timedOut)
        XCTAssertEqual(run.exitCode, 0, "종료코드 0이어야 함")
        XCTAssertEqual(run.standardOutput.count, byteCount, "출력이 잘리지 않아야 함")
        XCTAssertTrue(run.succeeded)
    }

    /// stderr도 함께 커야 교착이 안 난다 (stdout만 크면 우연히 통과할 수 있음)
    func testLargeStderrDoesNotDeadlock() {
        let byteCount = 512 * 1024
        let run = ProcessRunner.run(
            executable: "/bin/bash",
            arguments: ["-c", "head -c \(byteCount) /dev/zero | tr '\\0' 'b' 1>&2"]
        )
        XCTAssertEqual(run.exitCode, 0)
        XCTAssertEqual(run.standardError.count, byteCount)
    }

    /// stdout/stderr 동시 대량 출력 — 두 파이프가 모두 블로크되지 않아야 함
    func testBothStreamsLargeSimultaneously() {
        let byteCount = 256 * 1024
        let run = ProcessRunner.run(
            executable: "/bin/bash",
            arguments: [
                "-c",
                "head -c \(byteCount) /dev/zero | tr '\\0' 'o' & head -c \(byteCount) /dev/zero | tr '\\0' 'e' 1>&2; wait"
            ]
        )
        XCTAssertEqual(run.exitCode, 0)
        XCTAssertEqual(run.standardOutput.count, byteCount)
        XCTAssertEqual(run.standardError.count, byteCount)
    }

    /// UTF-8 멀티바이트 출력이 깨지지 않아야 함.
    /// ProcessRunner는 원본 그대로 반환한다(trim은 호출부 책임) — 개행이 보존되어야 한다.
    func testMultibyteOutputPreserved() {
        let run = ProcessRunner.run(
            executable: "/bin/bash",
            arguments: ["-c", "printf '한글출력\\n'"]
        )
        XCTAssertTrue(run.succeeded)
        XCTAssertEqual(run.standardOutput, "한글출력\n")
    }

    /// 종료코드는 그대로 전달되어야 함 (스크립트 실패 판정 근거)
    func testNonZeroExitCodePropagates() {
        let run = ProcessRunner.run(
            executable: "/bin/bash",
            arguments: ["-c", "echo out; echo err 1>&2; exit 42"]
        )
        XCTAssertEqual(run.exitCode, 42)
        XCTAssertFalse(run.succeeded)
        XCTAssertEqual(run.standardOutput, "out\n")
        XCTAssertEqual(run.standardError, "err\n")
    }

    /// 타임아웃이 실제로 동작하고, 무한 루프 프로세스가 데드라인 내 종료되는지
    func testTimeoutTerminatesLongRunningProcess() {
        let started = Date()
        let run = ProcessRunner.run(
            executable: "/bin/bash",
            arguments: ["-c", "sleep 30"],
            timeout: 1.0
        )
        let elapsed = Date().timeIntervalSince(started)
        XCTAssertTrue(run.timedOut, "타임아웃으로 판정되어야 함")
        XCTAssertLessThan(elapsed, 5.0, "데드라인(1초) + 강제 종료 여유(4초) 안에 끝나야 함")
    }

    /// 환경변수 주입이 반영되어야 함 (PATH 보완 경로가 이 메커니즘을 쓴다)
    func testEnvironmentIsApplied() {
        let run = ProcessRunner.run(
            executable: "/bin/bash",
            arguments: ["-c", "printf '%s' \"$APEXKEY_TEST_VAR\""],
            environment: ["APEXKEY_TEST_VAR": "injected", "PATH": "/usr/bin:/bin"]
        )
        XCTAssertTrue(run.succeeded)
        XCTAssertEqual(run.standardOutput, "injected")
    }

    /// 존재하지 않는 실행 파일 — launchError로 보고 (크래시 아님)
    func testMissingExecutableReportsLaunchError() {
        let run = ProcessRunner.run(
            executable: "/nonexistent/apexkey-does-not-exist",
            arguments: []
        )
        XCTAssertNotNil(run.launchError)
        XCTAssertFalse(run.succeeded)
    }

    /// 인자에 공백/따옴표가 있어도 셸을 거치지 않으므로 그대로 전달된다
    func testArgumentsWithSpecialCharactersNotShellInterpreted() {
        let tricky = "a b;c'd\"e$f`g\\h"
        let run = ProcessRunner.run(
            executable: "/bin/bash",
            arguments: ["-c", "printf '%s' \"$1\"", "--", tricky]
        )
        XCTAssertTrue(run.succeeded, "셸 재해석이 일어나면 실패해야 정상")
        XCTAssertEqual(run.standardOutput, tricky)
    }
}
