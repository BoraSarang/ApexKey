import XCTest
@testable import ApexKey

/// 무아이콘 모드 라우팅 — AppDelegate 없이 순수 분기만 고정한다.
final class ReopenRoutingTests: XCTestCase {

    // MARK: - 재실행 (이미 실행 중)

    func testReopenWithoutVisibleWindowShowsSettings() {
        XCTAssertEqual(ReopenRouter.reopen(hasVisibleWindow: false), .settings)
    }

    func testReopenWithVisibleWindowBringsItForward() {
        XCTAssertEqual(ReopenRouter.reopen(hasVisibleWindow: true), .bringForward)
    }

    // MARK: - 실행 (앱이 꺼져 있음)

    func testManualLaunchWithNoIconsShowsSettings() {
        XCTAssertEqual(
            ReopenRouter.launch(showInMenuBar: false, showInDock: false, launchedAsLoginItem: false),
            .settings
        )
    }

    func testLoginItemLaunchStaysHidden() {
        // 로그인 자동 시작은 사용자가 부른 실행이 아니므로 설정 창을 띄우지 않는다.
        XCTAssertNil(
            ReopenRouter.launch(showInMenuBar: false, showInDock: false, launchedAsLoginItem: true)
        )
    }

    func testLaunchWithMenuBarIconStaysHidden() {
        XCTAssertNil(
            ReopenRouter.launch(showInMenuBar: true, showInDock: false, launchedAsLoginItem: false)
        )
    }

    func testLaunchWithDockIconStaysHidden() {
        XCTAssertNil(
            ReopenRouter.launch(showInMenuBar: false, showInDock: true, launchedAsLoginItem: false)
        )
    }

    func testLaunchWithBothIconsStaysHidden() {
        XCTAssertNil(
            ReopenRouter.launch(showInMenuBar: true, showInDock: true, launchedAsLoginItem: false)
        )
    }

    func testLoginItemDetectionIsFalseWithoutLaunchEvent() {
        // 단위 테스트 프로세스에는 kAEOpenApplication 이벤트가 없다.
        XCTAssertFalse(LaunchContext.isLoginItemLaunch())
    }
}
