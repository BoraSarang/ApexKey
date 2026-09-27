import Foundation

/// 하위 프로세스 공용 실행기.
///
/// **왜 있는가 (E-MAC-SCRIPT-6004)**: 기존 코드는 `waitUntilExit()` **뒤에** `readDataToEndOfFile()`를
/// 호출했다. 파이프 버퍼(macOS 64KiB)를 초과하는 출력을 가진 자식 프로세스는 write에서 블로크된 채
/// 종료되지 않고, 부모는 종료를 기다리므로 **영구 교착**한다. 핫키 실행 경로가 메인 스레드라
/// 이 교착이 일어나면 핫키·패널·메뉴바가 전부 정지한다(강제종료 외 복구 불가).
///
/// 트리거가 되는 흔한 스크립트: `cat 큰 로그`, `find /`, `adb logcat -d`, `curl`, `git log -p`.
///
/// **해법**: 프로세스 종료 대기와 **출력 드레인을 병렬로** 수행한다. `readabilityHandler`는
/// Foundation이 관리하는 내부 큐에서 호출되므로 호출 스레드를 점유하지 않는다.
enum ProcessRunner {
    struct Result {
        var exitCode: Int32 = -1
        var standardOutput: String = ""
        var standardError: String = ""
        /// 타임아웃으로 강제 종료되었는지
        var timedOut: Bool = false
        /// `Process.run()` 자체가 실패한 경우의 메시지
        var launchError: String?
        /// 종료코드 0이면서 타임아웃·실행 실패가 없는 경우
        var succeeded: Bool { launchError == nil && !timedOut && exitCode == 0 }
    }

    /// 바이트 버퍼 축적기 — `readabilityHandler`가 다른 큐에서 호출되므로 락으로 보호
    private final class Accumulator {
        private let lock = NSLock()
        private var data = Data()

        func append(_ chunk: Data) {
            guard !chunk.isEmpty else { return }
            lock.lock()
            data.append(chunk)
            lock.unlock()
        }

        func snapshot() -> Data {
            lock.lock()
            defer { lock.unlock() }
            return data
        }
    }

    /// 프로세스 실행 + 동시 출력 드레인.
    ///
    /// - Parameters:
    ///   - executable: 절대 경로 (셸을 거치지 않으므로 공백·따옴표가 있어도 안전)
    ///   - arguments: 인자 배열 (셸 미경유)
    ///   - environment: 자식 프로세스 환경. nil이면 현재 프로세스 환경 상속
    ///   - timeout: 초 단위 데드라인. nil이면 무제한(사용자 스크립트 의도 존중)
    ///     - 지정 시 초과 시 `SIGTERM`을 보내고 최대 1초만 더 기다린 뒤 강제 종료
    @discardableResult
    static func run(
        executable: String,
        arguments: [String],
        environment: [String: String]? = nil,
        timeout: TimeInterval? = nil
    ) -> Result {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = arguments
        if let environment {
            task.environment = environment
        }

        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe

        let outAccumulator = Accumulator()
        let errAccumulator = Accumulator()

        // 종료 대기와 병렬로 읽는다 — 순서 대기 교착 방지의 핵심
        outPipe.fileHandleForReading.readabilityHandler = { handle in
            outAccumulator.append(handle.availableData)
        }
        errPipe.fileHandleForReading.readabilityHandler = { handle in
            errAccumulator.append(handle.availableData)
        }

        let exited = DispatchSemaphore(value: 0)
        task.terminationHandler = { _ in exited.signal() }

        do {
            try task.run()
        } catch {
            detachHandlers(outPipe: outPipe, errPipe: errPipe)
            var result = Result()
            result.launchError = error.localizedDescription
            return result
        }

        var timedOut = false
        if let timeout {
            if exited.wait(timeout: .now() + timeout) == .timedOut {
                timedOut = true
                task.terminate()
                // SIGTERM을 무시하는 자식 대비 상한 — 무한 대기 금지
                _ = exited.wait(timeout: .now() + 1.0)
                if task.isRunning { kill(task.processIdentifier, SIGKILL) }
            }
        } else {
            exited.wait()
        }

        detachHandlers(outPipe: outPipe, errPipe: errPipe)
        // 핸들러가 읽지 못한 잔여 버퍼를 확정적으로 회수 (자식은 이미 종료되어 EOF가 보장됨)
        outAccumulator.append(outPipe.fileHandleForReading.availableData)
        errAccumulator.append(errPipe.fileHandleForReading.availableData)

        var result = Result()
        result.timedOut = timedOut
        result.exitCode = task.terminationStatus
        result.standardOutput = decode(outAccumulator.snapshot())
        result.standardError = decode(errAccumulator.snapshot())
        return result
    }

    private static func detachHandlers(outPipe: Pipe, errPipe: Pipe) {
        outPipe.fileHandleForReading.readabilityHandler = nil
        errPipe.fileHandleForReading.readabilityHandler = nil
    }

    private static func decode(_ data: Data) -> String {
        String(data: data, encoding: .utf8) ?? ""
    }
}
