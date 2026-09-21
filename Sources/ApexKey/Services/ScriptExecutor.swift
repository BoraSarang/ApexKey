import Foundation
import AppKit

/// AppleScript / JavaScript for Automation (JXA) 실행기 (P0).
/// 셸 스크립트(`ActionExecutor.runShellScript`)와 분리 — NSAppleScript 기반.
enum ScriptExecutor {
    struct Result {
        var success: Bool
        var output: String
        var errorOutput: String
    }

    /// AppleScript 소스 실행
    static func runAppleScript(_ source: String) -> Result {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            Logger.error("E-MAC-SCRIPT-6002", "빈 AppleScript — 실행 건너뜀")
            return Result(success: false, output: "", errorOutput: "error.user.empty_script".localized)
        }
        guard let script = NSAppleScript(source: trimmed) else {
            Logger.error("E-MAC-SCRIPT-6001", "AppleScript 컴파일 실패")
            return Result(success: false, output: "", errorOutput: "AppleScript compile failed")
        }
        var error: NSDictionary?
        let descriptor = script.executeAndReturnError(&error)
        if let error {
            let msg = error[NSAppleScript.errorMessage] as? String ?? "\(error)"
            Logger.error("E-MAC-SCRIPT-6001", "AppleScript 실패: \(msg.prefix(500))")
            return Result(success: false, output: "", errorOutput: msg)
        }
        let output = descriptor.stringValue ?? ""
        Logger.info("ScriptExecutor", "AppleScript 성공 (\(output.count)자)")
        return Result(success: true, output: output, errorOutput: "")
    }

    /// JXA (JavaScript for Automation) 실행 — osascript -l JavaScript 경유
    static func runJXA(_ source: String) -> Result {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            Logger.error("E-MAC-SCRIPT-6002", "빈 JXA — 실행 건너뜀")
            return Result(success: false, output: "", errorOutput: "error.user.empty_script".localized)
        }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-l", "JavaScript", "-e", trimmed]
        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe
        do {
            try task.run()
        } catch {
            Logger.error("E-MAC-SCRIPT-6001", "JXA 실행 실패: \(error.localizedDescription)")
            return Result(success: false, output: "", errorOutput: error.localizedDescription)
        }
        task.waitUntilExit()
        let out = (String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let err = (String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if task.terminationStatus == 0 {
            Logger.info("ScriptExecutor", "JXA 성공 (\(out.count)자)")
            return Result(success: true, output: out, errorOutput: err)
        } else {
            Logger.error("E-MAC-SCRIPT-6001", "JXA 실패 (exit \(task.terminationStatus)): \(err.prefix(500))")
            return Result(success: false, output: out, errorOutput: err)
        }
    }
}
