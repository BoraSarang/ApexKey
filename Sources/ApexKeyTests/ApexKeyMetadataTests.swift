import XCTest
@testable import ApexKey

/// 액션 메타데이터 테이블 정합성 테스트 (R-08/R-09 회귀)
final class ApexKeyMetadataTests: XCTestCase {

    func testMetadataCoversAllCases() {
        XCTAssertEqual(ActionType.metadata.count, ActionType.allCases.count)
        for type in ActionType.allCases {
            let meta = ActionType.metadata[type]
            XCTAssertNotNil(meta, "\(type.rawValue) 메타데이터 누락")
            XCTAssertFalse(meta?.displayName.isEmpty ?? true)
            XCTAssertFalse(meta?.systemImage.isEmpty ?? true)
        }
    }

    func testCategoryMappingIsBidirectional() {
        // 카테고리 목록 합집합 = 전체 케이스 정확히 1회씩 (중복·누락 금지)
        let listed = ActionCategory.allCases.flatMap { $0.actionTypes }
        XCTAssertEqual(Set(listed).count, listed.count, "actionTypes 중복 등록 존재")
        XCTAssertEqual(Set(listed), Set(ActionType.allCases), "actionTypes 합집합이 전체와 불일치")
        // 역방향 일치: 각 타입의 category 목록에 자신이 포함
        for type in ActionType.allCases {
            XCTAssertTrue(type.category.actionTypes.contains(type),
                          "\(type.rawValue).category=\(type.category.rawValue) 목록에 자신 없음")
        }
    }

    func testVariableTypesBelongToVariables() {
        for type in [ActionType.setVariable, .variableDetail, .clipboardAction, .number, .outputToVariable] {
            XCTAssertEqual(type.category, .variables)
        }
        XCTAssertEqual(ActionType.runScriptInShell.category, .flowControl)
    }

    func testAutomationListsAllFour() {
        let auto = ActionCategory.automation.actionTypes
        for type in [ActionType.automation, .findAutomation, .automationRun, .trigger] {
            XCTAssertTrue(auto.contains(type), "\(type.rawValue)가 automation 목록에 없음")
        }
    }
}
