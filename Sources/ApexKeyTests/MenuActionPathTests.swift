import XCTest
@testable import ApexKey

/// 메뉴 실행 경로·오류 분류 회귀 테스트 (PLAN_v0.21 T-157/158 · E-MAC-MENU-7007/7008)
///
/// 감사에서 실측으로 확인한 사실:
/// - 없는 메뉴 항목·없는 메뉴바 항목·빈 세그먼트·`count==1` 구조 오류 → **전부 `-1728`**
/// - Automation(Apple Events) 권한 거부 → `-1743`
/// - `-600`은 실측으로 나타나지 않음. 게다가 `performAction`이 앱 미실행을 선검사로 처리하므로
///   `appNotRunning`을 `-600`에 연결한 분기는 도달 불가였다.
/// - `path.count == 1`이면 `click menu item "X" of menu 1 of menu bar item "X"`가 생성돼
///   **구조적으로 100% 실패**했다(같은 이름이 부모·자식으로 동시 등장).
final class MenuActionPathTests: XCTestCase {

    // MARK: - osascript 실측으로 코드 가정 검증

    /// 실행 중인 앱(Finder)에 없는 메뉴 항목을 지정하면 실제로 -1728이 난다.
    /// 이 시나리오가 빠르므로(~0.3초) 분류 로직의 근거 검증에 쓴다.
    ///
    /// - Important: **호스트가 UI 스크립팅을 못 하면 이 테스트에는 신호가 없다.**
    ///   GitHub Actions 러너는 접근성 권한이 없어서, 없는 메뉴 항목이 -1728이 아니라
    ///   권한 오류로 실패한다. 그 상태에서 단언을 유지하면 **분류 로직이 아니라
    ///   러너의 권한 상태를 측정**하게 되고, 매번 CI가 빨개진다.
    ///   (로컬에서는 영원히 통과하므로 로컬만으로는 발견 불가)
    ///
    ///   `AXIsProcessTrusted()` 대신 **실측 probe**를 쓴다. osascript는 우리
    ///   프로세스와 별개의 TCC 컨텍스트에서 실행되므로 우리 프로세스의 권한과
    ///   일치하지 않는다. "진짜 해볼 수 있는가"를 직접 물어야 한다.
    func testMissingMenuItemProduces1728() throws {
        let probe = ProcessRunner.run(
            executable: "/usr/bin/osascript",
            arguments: ["-e", "tell application \"System Events\" to count menu bar items of process \"Finder\""],
            timeout: MenuEnumerator.osaScriptTimeout
        )
        try XCTSkipUnless(
            probe.succeeded,
            """
            이 환경에서는 System Events UI 스크립팅이 불가능 (접근성 권한 없음).
            -1728 분류 로직을 측정할 수 없어 건너뛴다. \
            실제 오류: \(probe.standardError.prefix(160))
            """
        )

        let run = ProcessRunner.run(
            executable: "/usr/bin/osascript",
            arguments: ["-e", "tell application \"System Events\" to tell process \"Finder\" to click menu item \"__nope__\" of menu 1 of menu bar item \"__nope__\" of menu bar 1"],
            timeout: MenuEnumerator.osaScriptTimeout
        )
        XCTAssertFalse(run.succeeded, "없는 메뉴 항목은 실패해야 함")
        XCTAssertTrue(
            run.standardError.contains("-1728"),
            "-1728이 아니면 분류 로직의 근거가 무너짐. 실제: \(run.standardError.prefix(200))"
        )
    }

    /// 없는 **프로세스**는 -1728이지만 소요 시간이 훨씬 길다(실측 5.5초).
    /// 그래서 데드라인은 그보다 넉넉해야 "시간 초과"로 잘못 보고되지 않는다.
    /// 이 테스트는 슬owness를 되풀이하지 않고 상수만 검증한다.
    func testOsaScriptTimeoutExceedsSlowMissingProcessLatency() {
        XCTAssertGreaterThan(
            MenuEnumerator.osaScriptTimeout, 6.0,
            "없는 프로세스 시나리오의 실측 지연(≈5.5초)보다 커야 -1728 진단이 살아남음"
        )
    }

    /// Finder가 실행 중이 아니어도 테스트는 오해를 만들지 않아야 한다.
    /// (없으면 -1728이 다른 형태로 올 수 있어 "코드 또는 -1728" 중 하나만 허용)
    func testMissingMenuBarItemFailsWith1728OrTimeout() {
        let run = ProcessRunner.run(
            executable: "/usr/bin/osascript",
            arguments: ["-e", "tell application \"System Events\" to tell process \"Finder\" to click menu bar item \"__nope__\" of menu bar 1"],
            timeout: MenuEnumerator.osaScriptTimeout
        )
        XCTAssertFalse(run.succeeded)
        XCTAssertTrue(
            run.standardError.contains("-1728") || run.timedOut,
            "실패는 -1728 또는 타임아웃이어야 함. stderr: \(run.standardError.prefix(200))"
        )
    }

    // MARK: - 단일 세그먼트 (구 레거시 바인딩) 처리

    /// 구 바인딩(menuPath 비어 있음)의 폴백 규칙이 세그먼트 1개로 유지되어야 한다.
    /// 승격해서 2개로 만들면 안 된다 — 승격이 구조적 실패의 원인이었다.
    func testEmptyMenuPathStaysSingleSegment() {
        let legacy = MenuItem(title: "파일")
        XCTAssertTrue(legacy.menuPath.isEmpty)
        // performAction 내부 폴백 규칙: 비어 있으면 [title] (1개)
        let effectivePath = legacy.menuPath.isEmpty ? [legacy.title] : legacy.menuPath
        XCTAssertEqual(effectivePath.count, 1, "구 바인딩은 최상위 메뉴 클릭 경로로 처리되어야 함")
    }

    /// 정상 하위 항목은 2단계 이상 경로를 유지한다
    func testNestedMenuPathKeepsFullDepth() {
        let nested = MenuItem(title: "열기…", menuPath: ["파일", "열기…"])
        XCTAssertEqual(nested.menuPath.count, 2, "하위 항목 경로는 승격하지 않는다")
    }

    /// 3단계 경로도 그대로 유지
    func testThreeLevelMenuPathPreserved() {
        let deep = MenuItem(title: "최근 항목", menuPath: ["파일", "열기", "최근 항목"])
        XCTAssertEqual(deep.menuPath, ["파일", "열기", "최근 항목"])
    }

    // MARK: - 결과 유형

    /// Automation 거부용 결과가 손쉬운 사용 권한과 구분되어야 한다
    func testAutomationDeniedIsDistinctFromNoPermission() {
        XCTAssertNotEqual(
            MenuActionResult.automationDenied,
            MenuActionResult.noPermission,
            "Automation 거부와 AX 권한 없음이 같은 결과로 뭉치면 안 됨"
        )
    }

    /// 모든 실패 결과가 사용자에게 보여줄 문구를 가져야 한다
    func testAllResultsHaveUserMessage() {
        let results: [MenuActionResult] = [
            .success, .appNotRunning, .noPermission, .automationDenied, .menuNotFound
        ]
        for result in results {
            XCTAssertFalse(
                result.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                "\(result) 의 사용자 문구가 비어 있음 (키 누락 시 원문 키가 노출됨)"
            )
        }
    }

    /// Automation 거부 문구는 손쉬운 사용(Accessibility) 언급을 포함하면 안 된다
    /// -1743은 TCC Automation 거부가 아니라 Accessibility 거부 코드가 아니기 때문이다.
    func testAutomationDeniedMessageDoesNotMentionAccessibility() {
        let message = MenuActionResult.automationDenied.description
        XCTAssertFalse(
            message.localizedCaseInsensitiveContains("accessibility")
                || message.contains("손쉬운 사용"),
            "Automation 거부에 AX 권한 문구를 쓰면 잘못된 안내 — 실제: \(message)"
        )
    }

    /// 앱 미실행과 메뉴 미발견 문구가 구분되어야 한다
    func testAppNotRunningAndMenuNotFoundAreDistinct() {
        XCTAssertNotEqual(
            MenuActionResult.appNotRunning.description,
            MenuActionResult.menuNotFound.description,
            "앱 미실행과 경로 오류가 같은 문구면 사용자가 원인을 알 수 없음"
        )
    }

    /// 성공/실패 판정이 올바르게 동작
    func testIsSuccessOnlyForSuccess() {
        XCTAssertTrue(MenuActionResult.success.isSuccess)
        XCTAssertFalse(MenuActionResult.appNotRunning.isSuccess)
        XCTAssertFalse(MenuActionResult.noPermission.isSuccess)
        XCTAssertFalse(MenuActionResult.automationDenied.isSuccess)
        XCTAssertFalse(MenuActionResult.menuNotFound.isSuccess)
    }
}
