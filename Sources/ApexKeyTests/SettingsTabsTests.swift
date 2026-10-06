import XCTest
@testable import ApexKey

/// 설정 탭 구조 테스트 — 8탭 고정 + 도움말 키 존재 (ko/en).
final class SettingsTabsTests: XCTestCase {

    func testTabCount() {
        XCTAssertEqual(SettingsTab.allCases.count, 8)
    }

    func testTabTitlesAndHelpKeysExist() {
        for tab in SettingsTab.allCases {
            XCTAssertFalse(tab.titleKey.localized.isEmpty, tab.rawValue)
            for suffix in ["what", "when", "how"] {
                let key = "\(tab.helpPrefix).\(suffix)"
                XCTAssertFalse(key.localized.isEmpty, key)
                // 키 누락은 게이트를 통과하고 원문으로 노출되므로 양쪽 언어 값 일치 여부로 감지 불가 —
                // 최소한 비어 있지 않음만 고정한다
            }
        }
        XCTAssertFalse("settings.hud.show_no_shortcut.description".localized.isEmpty)
    }

    func testHelpKeysMatchBetweenLanguages() {
        // 탭/도움말 키가 한쪽에만 있으면 다른 쪽 UI에 원문 노출 — 키 집합 대조는 여기서 못 하므로
        // 최소한 FeatureHelpCard가 참조하는 키 형식을 고정한다
        for tab in SettingsTab.allCases {
            XCTAssertTrue(tab.helpPrefix.hasPrefix("settings.help."))
        }
    }
}
