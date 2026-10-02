import Foundation
import os

/// ApexKey 디버그 로거
/// 에러 코드 형식: E-MAC-{CATEGORY}-{NUM4}
enum LogLevel: String {
    case info = "[INFO]"
    case error = "[ERROR]"
    case perf = "[PERF]"
}

enum Logger {
    private static let subsystem = "com.borasarang.ApexKey"
    private static let log = OSLog(subsystem: subsystem, category: "ApexKey")
    /// XCTest 실행 중에는 콘솔 print를 생략한다 — 수백 줄 로그가 터미널을 뒤덮어
    /// 작업 방해가 된다. os_log + 링버퍼는 유지되므로 디버그 정보는 안 잃는다.
    private static var isTestRun: Bool { NSClassFromString("XCTestCase") != nil }
    private static func emit(_ line: String) {
        #if DEBUG
        if !isTestRun { print(line) }
        #endif
    }

    /// 디버그 패널용 링버퍼 (최대 2000줄)
    private static let maxBufferLines = 2000
    private static var buffer: [String] = []
    private static var bufferLock = NSLock()
    /// 링버퍼 갱신 알림 (디버그 뷰 갱신용)
    static var onBufferChange: (() -> Void)?

    static func info(_ tag: String, _ message: String) {
        let line = "[INFO] [\(tag)] \(message)"
        append(line)
        os_log("%{public}@", log: log, type: .info, line)
        emit(line)
    }

    static func error(_ code: String, _ message: String) {
        let line = "[ERROR] [\(code)] \(message)"
        append(line)
        os_log("%{public}@", log: log, type: .error, line)
        emit(line)
    }

    static func perf(_ message: String) {
        let line = "[PERF] [ApexKey] \(message)"
        append(line)
        os_log("%{public}@", log: log, type: .info, line)
        emit(line)
    }

    // MARK: - 디버그 링버퍼

    /// 현재 버퍼에 담긴 전체 로그 (디버그 패널 전용)
    static func allLogs() -> [String] {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        return buffer
    }

    /// 링버퍼 비우기 (디버그 패널 '지우기')
    static func clearBuffer() {
        bufferLock.lock()
        buffer.removeAll()
        bufferLock.unlock()
        DispatchQueue.main.async { onBufferChange?() }
    }

    private static func append(_ line: String) {
        let stamped = "\(Self.timestamp()) \(line)"
        bufferLock.lock()
        buffer.append(stamped)
        if buffer.count > maxBufferLines {
            buffer.removeFirst(buffer.count - maxBufferLines)
        }
        bufferLock.unlock()
        DispatchQueue.main.async { onBufferChange?() }
    }

    private static func timestamp() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss.SSS"
        return fmt.string(from: Date())
    }
}
