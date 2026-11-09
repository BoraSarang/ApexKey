import XCTest
@testable import ApexKey

/// T-219 시스템 제어 — Wi-Fi·집중 모드 검증.
///
/// 실제 Wi-Fi 전원을 끄거나 Shortcuts 단축어를 실행하지 않는다.
/// `networksetup`/`shortcuts` 실행기를 주입해 인자 구성과 실패 사유만 검사한다.
final class SystemControlsTests: XCTestCase {

    private func result(
        exitCode: Int32 = 0,
        output: String = "",
        error: String = "",
        timedOut: Bool = false
    ) -> ProcessRunner.Result {
        ProcessRunner.Result(
            exitCode: exitCode,
            standardOutput: output,
            standardError: error,
            timedOut: timedOut
        )
    }

    private let portsOutput = """
    Hardware Port: Ethernet
    Device: en5
    Ethernet Address: aa:bb:cc:dd:ee:ff

    Hardware Port: Wi-Fi
    Device: en0
    Ethernet Address: 11:22:33:44:55:66
    """

    // MARK: - 설정

    func testConfigDefaults() {
        let config = SystemControlConfig()
        XCTAssertEqual(config.resolvedWiFiAction, .status)
        XCTAssertNil(config.shortcutName)
    }

    func testConfigTolerantDecoding() throws {
        let data = Data(#"{"wifiAction":"turnOff","unknown":1}"#.utf8)
        let config = SystemControlConfig.decode(from: data)
        XCTAssertEqual(config.wifiAction, .turnOff)
        XCTAssertNil(config.shortcutName)
    }

    // MARK: - 파싱

    func testWifiInterfaceParsing() {
        XCTAssertEqual(SystemControls.wifiInterface(from: portsOutput), "en0")
        XCTAssertNil(SystemControls.wifiInterface(from: "Hardware Port: Ethernet\nDevice: en5"))
        XCTAssertNil(SystemControls.wifiInterface(from: ""))
    }

    func testParsePower() {
        XCTAssertEqual(SystemControls.parsePower("Wi-Fi Power (en0): On"), true)
        XCTAssertEqual(SystemControls.parsePower("Wi-Fi Power (en0): Off"), false)
        XCTAssertNil(SystemControls.parsePower("unknown"))
    }

    // MARK: - Wi-Fi

    func testWifiStatusReadsInterface() {
        var calls: [[String]] = []
        let outcome = SystemControls.wifi(action: .status) { _, args in
            calls.append(args)
            if args.contains("-listallhardwareports") { return self.result(output: self.portsOutput) }
            if args.contains("-getairportpower") { return self.result(output: "Wi-Fi Power (en0): On") }
            return self.result(exitCode: 1)
        }
        XCTAssertEqual(outcome, .success(["ui.wifi.on".localized]))
        XCTAssertEqual(calls, [["-listallhardwareports"], ["-getairportpower", "en0"]])
    }

    func testWifiTurnOffSetsAndVerifies() {
        var setArguments: [String]?
        let outcome = SystemControls.wifi(action: .turnOff) { _, args in
            if args.contains("-listallhardwareports") { return self.result(output: self.portsOutput) }
            if args.contains("-setairportpower") {
                setArguments = args
                return self.result()
            }
            if args.contains("-getairportpower") {
                return self.result(output: "Wi-Fi Power (en0): Off")
            }
            return self.result(exitCode: 1)
        }
        XCTAssertEqual(outcome, .success(["ui.wifi.off".localized]))
        XCTAssertEqual(setArguments, ["-setairportpower", "en0", "off"])
    }

    func testWifiSetFailureIsReported() {
        let outcome = SystemControls.wifi(action: .turnOn) { _, args in
            if args.contains("-listallhardwareports") { return self.result(output: self.portsOutput) }
            return self.result(exitCode: 1, error: "not permitted")
        }
        guard case .failure(.commandFailed(let detail)) = outcome else {
            return XCTFail("실패 사유가 commandFailed여야 함: \(outcome)")
        }
        XCTAssertTrue(detail.contains("not permitted"))
    }

    func testWifiMissingInterfaceFailsBeforeSetting() {
        let outcome = SystemControls.wifi(action: .turnOn) { _, args in
            XCTAssertEqual(args, ["-listallhardwareports"], "인터페이스가 없으면 설정 명령을 부르지 않는다")
            return self.result(output: "Hardware Port: Ethernet\nDevice: en5")
        }
        XCTAssertEqual(outcome, .failure(.wifiInterfaceNotFound))
    }

    func testWifiUnchangedStateIsReported() {
        let outcome = SystemControls.wifi(action: .turnOn) { _, args in
            if args.contains("-listallhardwareports") { return self.result(output: self.portsOutput) }
            if args.contains("-setairportpower") { return self.result() }
            return self.result(output: "Wi-Fi Power (en0): Off")
        }
        XCTAssertEqual(outcome, .failure(.wifiStateUnchanged(true)))
    }

    // MARK: - 집중 모드

    func testFocusRequiresShortcutName() {
        let outcome = SystemControls.focus(shortcutName: "  ") { _, _ in
            XCTFail("이름이 비면 명령을 실행하지 않는다")
            return self.result()
        }
        XCTAssertEqual(outcome, .failure(.focusShortcutEmpty))
    }

    func testFocusRejectsMissingShortcutBeforeRunning() {
        var ran = false
        let outcome = SystemControls.focus(shortcutName: "집중") { _, args in
            if args.first == "list" { return self.result(output: "다른 단축어\n") }
            ran = true
            return self.result()
        }
        XCTAssertEqual(outcome, .failure(.focusShortcutMissing("집중")))
        XCTAssertFalse(ran, "목록에 없으면 실행하지 않는다")
    }

    func testFocusRunsListedShortcut() {
        var runArguments: [String]?
        let outcome = SystemControls.focus(shortcutName: "집중") { _, args in
            if args.first == "list" { return self.result(output: "집중\n다른 단축어\n") }
            runArguments = args
            return self.result()
        }
        XCTAssertEqual(outcome, .success(["집중"]))
        XCTAssertEqual(runArguments, ["run", "집중"])
    }

    func testFocusMapsAutomationDenied() {
        let outcome = SystemControls.focus(shortcutName: "집중") { _, args in
            if args.first == "list" { return self.result(output: "집중\n") }
            return self.result(exitCode: 1, error: "Not authorized to send Apple events (-1743)")
        }
        XCTAssertEqual(outcome, .failure(.automationDenied))
    }

    func testFocusRunsEvenWhenListFails() {
        var runArguments: [String]?
        let outcome = SystemControls.focus(shortcutName: "집중") { _, args in
            if args.first == "list" { return self.result(exitCode: 1, error: "unsupported") }
            runArguments = args
            return self.result()
        }
        XCTAssertEqual(outcome, .success(["집중"]))
        XCTAssertEqual(runArguments, ["run", "집중"])
    }

    // MARK: - 엔진 배선

    private func run(_ step: ShortcutStep) -> ExecutionEngine.Result {
        var context = UseModelExecutor.ExecutionContext()
        return ExecutionEngine.shared.execute(steps: [step], context: &context)
    }

    func testSystemControlsAreWiredIntoEngine() {
        let unimplemented = "toast.reason.unimplemented".localized

        // 이름이 비면 실제 단축어를 부르지 않고 실패한다
        let focus = ShortcutStep(
            type: .focusMode,
            target: "",
            title: "",
            actionParameters: SystemControlConfig(shortcutName: "").encode()
        )
        let focusResult = run(focus)
        XCTAssertFalse(focusResult.success)
        XCTAssertNotEqual(focusResult.error, unimplemented)
        XCTAssertEqual(focusResult.error, "error.user.focus_shortcut_empty".localized)

        // 상태 확인은 읽기 전용이다 (Wi-Fi가 없는 환경이어도 미구현은 아니다)
        let network = ShortcutStep(
            type: .network,
            target: "",
            title: "",
            actionParameters: SystemControlConfig(wifiAction: .status).encode()
        )
        let networkResult = run(network)
        XCTAssertNotEqual(networkResult.error, unimplemented)
    }
}
