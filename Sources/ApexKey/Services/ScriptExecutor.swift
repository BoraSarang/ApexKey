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
        // 동시 드레인 — 64KiB 초과 출력 시 교착 방지 (E-MAC-SCRIPT-6004)
        // osascript가 시스템 권한 프롬프트에서 멈추면 실행큐가 영구 점유되므로 상한 60초
        let run = ProcessRunner.run(
            executable: "/usr/bin/osascript",
            arguments: ["-l", "JavaScript", "-e", trimmed],
            timeout: 60
        )
        if let launchError = run.launchError {
            Logger.error("E-MAC-SCRIPT-6001", "JXA 실행 실패: \(launchError)")
            return Result(success: false, output: "", errorOutput: launchError)
        }
        let out = run.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        let err = run.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
        if run.succeeded {
            Logger.info("ScriptExecutor", "JXA 성공 (\(out.count)자)")
            return Result(success: true, output: out, errorOutput: err)
        } else {
            let suffix = run.timedOut ? " (timeout)" : ""
            Logger.error("E-MAC-SCRIPT-6001", "JXA 실패 (exit \(run.exitCode))\(suffix): \(err.prefix(500))")
            return Result(success: false, output: out, errorOutput: err)
        }
    }
}
