import Foundation

/// 시스템 제어 — Wi-Fi·집중 모드 (T-219)
///
/// **공개 경로만 사용한다.**
/// - Wi-Fi: `networksetup -listallhardwareports`로 Wi-Fi 인터페이스를 찾고
///   `-getairportpower`/`-setairportpower`로 상태를 읽고 바꾼다.
/// - 집중 모드: 공개 스크립팅 API가 없다. 사용자가 Shortcuts 앱에서 만든
///   "집중 모드 설정" 단축어를 `shortcuts run`으로 실행한다.
///
/// 모든 외부 실행은 주입 가능한 `Runner`로 분리해 테스트에서 실제 명령을 부르지 않는다.
enum SystemControls {

    typealias Runner = (_ executable: String, _ arguments: [String]) -> ProcessRunner.Result

    static let networksetupPath = "/usr/sbin/networksetup"
    static let shortcutsPath = "/usr/bin/shortcuts"

    static let defaultRunner: Runner = { executable, arguments in
        ProcessRunner.run(executable: executable, arguments: arguments, timeout: 15)
    }

    enum FailureReason: Equatable, Error {
        case commandFailed(String)
        case wifiInterfaceNotFound
        case wifiStateUnreadable
        case wifiStateUnchanged(Bool)
        case focusShortcutEmpty
        case focusShortcutMissing(String)
        case focusShortcutFailed(String)
        case automationDenied

        var message: String {
            switch self {
            case .commandFailed(let detail):
                return "error.user.system_command_failed".localizedFormat(detail)
            case .wifiInterfaceNotFound:
                return "error.user.wifi_interface_not_found".localized
            case .wifiStateUnreadable:
                return "error.user.wifi_state_unreadable".localized
            case .wifiStateUnchanged(let desired):
                return "error.user.wifi_state_unchanged".localizedFormat(
                    desired ? "ui.wifi.on".localized : "ui.wifi.off".localized
                )
            case .focusShortcutEmpty:
                return "error.user.focus_shortcut_empty".localized
            case .focusShortcutMissing(let name):
                return "error.user.focus_shortcut_missing".localizedFormat(name)
            case .focusShortcutFailed(let detail):
                return "error.user.focus_shortcut_failed".localizedFormat(detail)
            case .automationDenied:
                return "error.user.apple_denied".localized
            }
        }
    }

    typealias Outcome = Result<[String], FailureReason>

    // MARK: - Wi-Fi

    /// `networksetup -listallhardwareports` 출력에서 Wi-Fi 장치 이름을 찾는다.
    static func wifiInterface(from output: String) -> String? {
        let lines = output.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("Hardware Port:") else { continue }
            let port = trimmed
                .dropFirst("Hardware Port:".count)
                .trimmingCharacters(in: .whitespaces)
            guard port == "Wi-Fi" else { continue }

            for next in lines.dropFirst(index + 1) {
                let candidate = next.trimmingCharacters(in: .whitespaces)
                guard candidate.hasPrefix("Device:") else { continue }
                let device = candidate
                    .dropFirst("Device:".count)
                    .trimmingCharacters(in: .whitespaces)
                return device.isEmpty ? nil : device
            }
        }
        return nil
    }

    /// `Wi-Fi Power (en0): On` 형태의 출력을 Bool로 읽는다.
    static func parsePower(_ output: String) -> Bool? {
        guard let colon = output.lastIndex(of: ":") else { return nil }
        let value = output[output.index(after: colon)...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if value == "on" { return true }
        if value == "off" { return false }
        return nil
    }

    static func wifi(
        action: SystemControlConfig.WiFiAction,
        runner: Runner = defaultRunner
    ) -> Outcome {
        let ports = runner(networksetupPath, ["-listallhardwareports"])
        guard ports.succeeded else {
            return .failure(.commandFailed(detail(ports)))
        }
        guard let interface = wifiInterface(from: ports.standardOutput) else {
            return .failure(.wifiInterfaceNotFound)
        }

        switch action {
        case .status:
            let result = runner(networksetupPath, ["-getairportpower", interface])
            guard result.succeeded, let on = parsePower(result.standardOutput) else {
                return .failure(.wifiStateUnreadable)
            }
            return .success([on ? "ui.wifi.on".localized : "ui.wifi.off".localized])

        case .turnOn, .turnOff:
            let desired = action == .turnOn
            let set = runner(networksetupPath, ["-setairportpower", interface, desired ? "on" : "off"])
            guard set.succeeded else {
                return .failure(.commandFailed(detail(set)))
            }

            // setairportpower는 성공을 반환해도 실제 상태가 늦게 바뀔 수 있어 확인한다.
            let verify = runner(networksetupPath, ["-getairportpower", interface])
            guard verify.succeeded, let on = parsePower(verify.standardOutput) else {
                return .failure(.wifiStateUnreadable)
            }
            guard on == desired else {
                return .failure(.wifiStateUnchanged(desired))
            }
            return .success([on ? "ui.wifi.on".localized : "ui.wifi.off".localized])
        }
    }

    // MARK: - 집중 모드

    /// 사용자가 만든 집중 모드 단축어를 실행한다.
    ///
    /// `shortcuts list`로 이름을 먼저 확인한다. 목록 조회가 실패하는 환경(구버전)에서는
    /// 실행을 그대로 시도하고, `shortcuts run`의 실패 사유로 판단한다.
    static func focus(
        shortcutName: String,
        runner: Runner = defaultRunner
    ) -> Outcome {
        let name = shortcutName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return .failure(.focusShortcutEmpty) }

        let list = runner(shortcutsPath, ["list"])
        if list.succeeded {
            let names = AppleApps.parseLines(list.standardOutput)
            guard names.contains(name) else {
                return .failure(.focusShortcutMissing(name))
            }
        }

        let run = runner(shortcutsPath, ["run", name])
        guard run.succeeded else {
            let text = run.standardError + " " + run.standardOutput
            if AppleApps.isAutomationDenied(text) {
                return .failure(.automationDenied)
            }
            return .failure(.focusShortcutFailed(detail(run)))
        }
        return .success([name])
    }

    // MARK: - 공통

    private static func detail(_ result: ProcessRunner.Result) -> String {
        if result.timedOut { return "timeout" }
        if let launchError = result.launchError { return launchError }
        let error = result.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
        if !error.isEmpty { return String(error.prefix(200)) }
        let output = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !output.isEmpty { return String(output.prefix(200)) }
        return "exit \(result.exitCode)"
    }
}
