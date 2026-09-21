import XCTest
@testable import ApexKey

/// 셸 스크립트 실행 경로 단위 테스트 (T-130~132 회귀)
/// "실행" 버튼 → ActionExecutor.execute(shortcut) → runShellScript와 동일한 경로를 검증한다.
final class ApexKeyScriptTests: XCTestCase {

    func testRunShellScriptEcho() {
        XCTAssertTrue(ActionExecutor.shared.runShellScript("echo hello"))
    }

    func testRunShellScriptEmpty() {
        XCTAssertFalse(ActionExecutor.shared.runShellScript("   \n  "))
    }

    func testRunShellScriptFailure() {
        XCTAssertFalse(ActionExecutor.shared.runShellScript("exit 3"))
    }

    func testRunShellScriptResultCapturesOutput() {
        let result = ActionExecutor.shared.runShellScriptResult("echo hello")
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.output, "hello")
        XCTAssertEqual(result.exitCode, 0)
    }

    func testRunShellScriptResultCapturesFailure() {
        let result = ActionExecutor.shared.runShellScriptResult("echo oops >&2; exit 3")
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.exitCode, 3)
        XCTAssertEqual(result.errorOutput, "oops")
    }

    func testRunScriptInShellBindingExecutes() {
        // 기존엔 E-MAC-ACT-3005 미구현으로 조용히 실패했던 타입
        let binding = HotKeyBinding(
            combo: .empty,
            actionType: .runScriptInShell,
            target: "echo hello",
            title: "테스트"
        )
        XCTAssertTrue(ActionExecutor.shared.execute(binding))
    }

    func testBuiltInPresetsAreFixedWithoutHotkeys() {
        // 고정 프리셋은 시스템 탭으로 이관됨 — 동작 탭 프리셋 목록은 비어 있음
        XCTAssertTrue(BuiltInShortcutPresets.all.isEmpty)
        // 시스템 탭에 Android 미러 고정 액션이 있음 (외부 스크립트 파일 단일 소스)
        XCTAssertTrue(SystemActionType.allCases.contains(.androidMirror))
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: SystemActionExecutor.androidMirrorScriptPath),
            "scrcpy_run.sh 없음: \(SystemActionExecutor.androidMirrorScriptPath)"
        )
    }

    func testEngineReportsUnimplementedActionFailure() {
        // R-01: 미구현 타입이 성공으로 둔갑하지 않음
        let shortcut = ShortcutItem(
            name: "미구현",
            steps: [ShortcutStep(type: .dialog, target: "", title: "대화상자")]
        )
        var ctx = UseModelExecutor.ExecutionContext()
        let result = ExecutionEngine.shared.execute(shortcut, context: &ctx)
        XCTAssertFalse(result.success)
    }

    func testWaitBlocksSequentially() {
        // R-02: 대기는 호출 스레드에서 동기 수행 (순서 보장)
        let start = Date()
        ActionExecutor.shared.execute(HotKeyBinding(
            combo: .empty, actionType: .wait, target: "0.2", title: ""
        ))
        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(start), 0.2)
    }

    func testAdbWifiShortcutEndToEnd() throws {
        // USB 연결 기기가 있을 때만: 저장된 샘플과 동일한 단계로 전체 경로 실행.
        // 무선 중복 연결 시 adb가 기기를 고르지 못하므로 USB 시리얼을 -s로 명시한다.
        guard let serial = usbAdbSerial() else {
            throw XCTSkip("USB 연결된 ADB 기기 없음 — 실기 Connected 환경에서만 실행")
        }
        // tcpip 전환하면 USB 전송이 끊기므로 IP는 먼저 조회한다
        let script = """
        IP=$(adb -s \(serial) shell ip route | awk '{print $9}' | head -1)
        if [ -z "$IP" ]; then echo "IP를 찾지 못했습니다. USB 연결을 확인하세요."; exit 1; fi
        adb -s \(serial) tcpip 5555
        sleep 4
        adb connect "$IP:5555"
        """
        let shortcut = ShortcutItem(
            name: "ADB Wi-Fi 연결",
            steps: [ShortcutStep(type: .script, target: script, title: "ADB Wi-Fi 연결")]
        )
        // 실행 버튼과 동일한 진입점
        XCTAssertTrue(ActionExecutor.shared.execute(shortcut))
    }

    /// USB로 연결된 adb 기기의 시리얼 (없으면 nil). 무선(:5555) 연결은 제외.
    private func usbAdbSerial() -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", ShellEnvironment.pathExport + "; adb devices | awk '{gsub(/\\r/,\"\")} $2==\"device\" && $1 !~ /:/ {print $1; exit}'"]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (out?.isEmpty == false) ? out : nil
    }

    /// USB로 연결된 adb 기기가 있는지 (테스트 게이트용)
    private func hasAdbDevice() -> Bool {
        usbAdbSerial() != nil
    }
}
