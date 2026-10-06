import XCTest
@testable import ApexKey

/// HUD 실행 결과 토스트 정책 테스트 (M-05)
/// 실패만 토스트, 성공은 무음. 이 정책이 바뀌면 여기부터 고칠 것.
final class MenuHUDFeedbackTests: XCTestCase {

    func testSuccessProducesNoToast() {
        XCTAssertNil(AppDelegate.MenuHUDRunFeedback.toastMessage(for: .success))
    }

    func testAllFailuresProduceToastMessage() {
        let failures: [MenuActionResult] = [.appNotRunning, .noPermission, .automationDenied, .menuNotFound]
        for result in failures {
            let message = AppDelegate.MenuHUDRunFeedback.toastMessage(for: result)
            XCTAssertNotNil(message, "\(result)는 토스트 메시지가 있어야 함")
            XCTAssertFalse(message!.isEmpty)
        }
    }

    func testFailureMessagesAreDistinct() {
        // 원인별 안내가 뭉개지면 토스트 의미가 없다
        let messages = Set([
            AppDelegate.MenuHUDRunFeedback.toastMessage(for: .appNotRunning),
            AppDelegate.MenuHUDRunFeedback.toastMessage(for: .noPermission),
            AppDelegate.MenuHUDRunFeedback.toastMessage(for: .automationDenied),
            AppDelegate.MenuHUDRunFeedback.toastMessage(for: .menuNotFound),
        ])
        XCTAssertEqual(messages.count, 4)
    }
}
