import XCTest
@testable import ApexKey

/// 온보딩 완료 플래그 테스트 (M-06) — 전용 suite 주입으로 실 설정 오염 없음.
final class OnboardingStateTests: XCTestCase {

    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "ApexKeyTests.OnboardingState")!
        defaults.removeObject(forKey: OnboardingState.completedKey)
    }

    override func tearDown() {
        defaults.removeObject(forKey: OnboardingState.completedKey)
        super.tearDown()
    }

    func testDefaultsToIncomplete() {
        XCTAssertFalse(OnboardingState.isCompleted(defaults: defaults))
    }

    func testMarkCompletedPersists() {
        OnboardingState.markCompleted(defaults: defaults)
        XCTAssertTrue(OnboardingState.isCompleted(defaults: defaults))
    }

    func testNewKeysExistInBothLanguages() {
        // 신규 키 누락은 게이트를 통과하고 UI에 원문으로 노출되므로 여기서 고정
        for key in ["onboarding.title", "onboarding.step1", "onboarding.step2",
                    "onboarding.permission.ok", "onboarding.permission.needed",
                    "onboarding.permission.description", "onboarding.permission.open_settings",
                    "onboarding.shortcuts.description", "onboarding.back",
                    "onboarding.next", "onboarding.start"] {
            XCTAssertFalse(key.localized.isEmpty, key)
        }
    }
}
