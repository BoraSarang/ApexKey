import XCTest
@testable import ApexKey

/// 동작 실동작 검증 스위트 — 체크리스트(`docs/plans/ACTION_VERIFY_v2_macos.md`)의 [자동] 행과 1:1 매핑.
/// 규칙: 부작용 없는 것만 자동화 (실패 경로·파싱·읽기 전용 실실행).
/// 실제 앱 띄우기/키 전송/미러는 수동 행으로 체크리스트에 남긴다.
final class ApexKeyActionVerifyTests: XCTestCase {

    // MARK: - LAUNCH (앱 실행)

    /// V-LAUNCH-01: 오타 번들ID → E-MAC-APP-4001 실패 반환, 크래시 없음
    func testVerifyLaunchBogusBundleIDFails() {
        let config = LaunchConfig(bundleID: "com.example.Nope", mode: .toggle)
        XCTAssertFalse(AppSwitcher.execute(config: config))
    }

    /// V-LAUNCH-02: 앱 미지정(번들ID+경로 비움) → 실패 반환 + 안내
    func testVerifyLaunchEmptyConfigFails() {
        XCTAssertFalse(AppSwitcher.execute(config: LaunchConfig()))
    }

    /// V-LAUNCH-03: 엔진 경로 — 오타 번들ID 단계 → success=false, 후속 단계 계속 가능
    func testVerifyLaunchEngineReportsFailure() {
        let shortcut = ShortcutItem(
            name: "검증",
            steps: [ShortcutStep(type: .launchApp, target: "com.example.Nope", title: "없는 앱")]
        )
        var ctx = UseModelExecutor.ExecutionContext()
        let result = ExecutionEngine.shared.execute(shortcut, context: &ctx)
        XCTAssertFalse(result.success)
    }

    /// V-LAUNCH-04: 인자 파싱 — 따옴표 그룹 유지 (실행 전 단계)
    func testVerifyLaunchArgsParsing() {
        XCTAssertEqual(
            LaunchConfig.parseArgs("--show-touches --max-size=1024 --name \"my device\""),
            ["--show-touches", "--max-size=1024", "--name", "my device"]
        )
    }

    /// V-LAUNCH-05: 모드 3종이 설정에 보존·영속 왕복됨
    func testVerifyLaunchModesRoundTrip() {
        for mode in LaunchMode.allCases {
            let config = LaunchConfig(bundleID: "com.apple.Safari", mode: mode)
            let decoded = ActionExecutor.decodeLaunchConfig(from: ActionExecutor.encodeLaunchConfig(config))
            XCTAssertEqual(decoded?.mode, mode, "모드 \(mode) 보존 실패")
        }
    }

    // MARK: - SCRIPT (셸)

    /// V-SCRIPT-01: 셸 정상 — echo 출력·종료코드 0
    func testVerifyShellSuccess() {
        let r = ActionExecutor.shared.runShellScriptResult("echo verify-ok")
        XCTAssertTrue(r.success)
        XCTAssertEqual(r.output, "verify-ok")
        XCTAssertEqual(r.exitCode, 0)
    }

    /// V-SCRIPT-02: 셸 문법 오류 — 실패 반환 + 에러 메시지, 크래시 없음
    func testVerifyShellSyntaxErrorFails() {
        let r = ActionExecutor.shared.runShellScriptResult("echo \"unterminated")
        XCTAssertFalse(r.success)
    }

    /// V-SCRIPT-03: 셸 빈 입력 — 실행 없음 + 실패 반환
    func testVerifyShellEmptyFails() {
        XCTAssertFalse(ActionExecutor.shared.runShellScript("   "))
    }

    /// V-SCRIPT-04: 엔진 경로 — 실패해도 단계 중단 아님(success=false, 크래시 없음)
    func testVerifyShellEngineFailure() {
        let shortcut = ShortcutItem(
            name: "검증",
            steps: [ShortcutStep(type: .script, target: "exit 3", title: "실패 스크립트")]
        )
        var ctx = UseModelExecutor.ExecutionContext()
        XCTAssertFalse(ExecutionEngine.shared.execute(shortcut, context: &ctx).success)
    }

    // MARK: - APPLESCRIPT / JXA (읽기 전용 실실행)

    /// V-AS-01: AppleScript 정상 — Finder 이름 조회 성공
    func testVerifyAppleScriptSuccess() {
        let r = ScriptExecutor.runAppleScript("tell application \"Finder\" to get name")
        XCTAssertTrue(r.success, "stderr: \(r.errorOutput)")
        XCTAssertFalse(r.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    /// V-AS-02: AppleScript 문법 오류 — 실패 반환 + 에러 메시지
    func testVerifyAppleScriptSyntaxErrorFails() {
        let r = ScriptExecutor.runAppleScript("this is not valid applescript %%%")
        XCTAssertFalse(r.success)
    }

    /// V-AS-03: AppleScript 빈 입력 — 건너뜀 + 실패 반환
    func testVerifyAppleScriptEmptyFails() {
        XCTAssertFalse(ScriptExecutor.runAppleScript("   ").success)
    }

    /// V-JXA-01: JXA 정상 — Finder 이름 조회 성공
    func testVerifyJXASuccess() {
        let r = ScriptExecutor.runJXA("Application('Finder').name()")
        XCTAssertTrue(r.success, "stderr: \(r.errorOutput)")
        XCTAssertFalse(r.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    /// V-JXA-02: JXA 오류 — 실패 반환 + stderr
    func testVerifyJXAErrorFails() {
        let r = ScriptExecutor.runJXA("throw new Error('boom')")
        XCTAssertFalse(r.success)
    }

    // MARK: - SYSTEM (시스템 탭)

    /// V-SYS-01: Android 미러 — 기기 없음 → 조용히 실패(false), 크래시 없음.
    /// 기기가 연결되어 있으면 scrcpy가 뜨므로 스킵 (수동 행에서 확인).
    func testVerifyAndroidMirrorNoDeviceFailsGracefully() throws {
        guard !hasAdbDevice() else {
            throw XCTSkip("ADB 기기 연결됨 — 실기 미러는 수동 행에서 확인")
        }
        XCTAssertFalse(SystemActionExecutor.execute(.androidMirror))
    }

    /// V-SYS-01b: 미러 스크립트 파일이 단일 소스로 존재함
    func testVerifyAndroidMirrorScriptFileExists() {
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: SystemActionExecutor.androidMirrorScriptPath),
            "scrcpy_run.sh 없음: \(SystemActionExecutor.androidMirrorScriptPath)"
        )
    }

    /// V-SYS-02: 시스템 액션 9종이 타입·이름·아이콘을 모두 갖춤 (목록 누락 방지)
    func testVerifySystemActionCatalogComplete() {
        XCTAssertEqual(SystemActionType.allCases.count, 9)
        for type in SystemActionType.allCases {
            XCTAssertFalse(type.displayName.isEmpty, "\(type.rawValue) 이름 누락")
            XCTAssertFalse(type.systemImage.isEmpty, "\(type.rawValue) 아이콘 누락")
        }
        XCTAssertFalse(SystemActionExecutor.androidMirrorScriptPath.isEmpty)
    }

    // MARK: - KEYCOMBO (부작용 없는 범위만)

    /// V-KEY-01: 잘못된 형식 → 엔진 실패 반환, 전송 없음
    func testVerifyKeyComboInvalidFails() {
        let shortcut = ShortcutItem(
            name: "검증",
            steps: [ShortcutStep(type: .keyCombo, target: "not-a-combo", title: "잘못된 조합")]
        )
        var ctx = UseModelExecutor.ExecutionContext()
        XCTAssertFalse(ExecutionEngine.shared.execute(shortcut, context: &ctx).success)
    }

    /// V-KEY-02: 빈 조합 전송 → 부작용 없이 실패
    func testVerifyKeyComboEmptyFails() {
        XCTAssertFalse(ActionExecutor.sendKeyPress(.empty))
    }

    // MARK: - TOAST (실행 결과 사유 배관)

    /// V-TOAST-01: 잘못된 키 조합 → 실패 + 사유 포함
    func testVerifyDetailKeyComboInvalid() {
        let binding = HotKeyBinding(combo: .empty, actionType: .keyCombo, target: "oops", title: "키")
        let r = ActionExecutor.shared.executeWithDetail(binding)
        XCTAssertFalse(r.success)
        XCTAssertFalse((r.message ?? "").isEmpty)
    }

    /// V-TOAST-02: 빈 스크립트 → 실패 + 사유 포함
    func testVerifyDetailEmptyScript() {
        let binding = HotKeyBinding(combo: .empty, actionType: .script, target: "   ", title: "빈 스크립트")
        let r = ActionExecutor.shared.executeWithDetail(binding)
        XCTAssertFalse(r.success)
        XCTAssertFalse((r.message ?? "").isEmpty)
    }

    /// V-TOAST-03: 알 수 없는 시스템 액션 → 실패 + 사유 포함
    func testVerifyDetailUnknownSystem() {
        let binding = HotKeyBinding(combo: .empty, actionType: .system, target: "nope", title: "시스템")
        let r = ActionExecutor.shared.executeWithDetail(binding)
        XCTAssertFalse(r.success)
        XCTAssertFalse((r.message ?? "").isEmpty)
    }

    /// V-TOAST-04: 오타 번들ID 실행 → 실패 + 사유 포함
    func testVerifyDetailBogusLaunch() {
        let binding = HotKeyBinding(combo: .empty, actionType: .launchApp, target: "com.example.Nope", title: "없는 앱")
        let r = ActionExecutor.shared.executeWithDetail(binding)
        XCTAssertFalse(r.success)
        XCTAssertFalse((r.message ?? "").isEmpty)
    }

    /// V-TOAST-05: 성공 시 메시지는 nil
    func testVerifyDetailSuccessHasNoMessage() {
        let binding = HotKeyBinding(combo: .empty, actionType: .script, target: "echo ok", title: "에코")
        let r = ActionExecutor.shared.executeWithDetail(binding)
        XCTAssertTrue(r.success)
        XCTAssertNil(r.message)
    }

    /// V-TOAST-06: 동작 실패 → 엔진 에러 메시지 전달
    func testVerifyDetailShortcutFailure() {
        let shortcut = ShortcutItem(
            name: "검증",
            steps: [ShortcutStep(type: .script, target: "exit 3", title: "실패")]
        )
        let r = ActionExecutor.shared.executeWithDetail(shortcut)
        XCTAssertFalse(r.success)
        XCTAssertFalse((r.message ?? "").isEmpty)
    }

    private func hasAdbDevice() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", ShellEnvironment.pathExport + "; adb devices | tail -n +2 | grep -q device"]
        try? task.run()
        task.waitUntilExit()
        return task.terminationStatus == 0
    }
}
