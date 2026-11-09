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

    /// 표시 이름 키가 액션마다 유일해야 한다 (T-210 — `drive`/`oneDrive` 중복 정리)
    ///
    /// 두 액션이 같은 키를 쓰면 카탈로그에 같은 이름이 두 번 나온다.
    /// 사용자는 어느 쪽을 골라야 하는지 알 수 없고, 한쪽 번역을 고치면
    /// 다른 쪽 이름까지 같이 바뀐다.
    func testDisplayNameKeysAreUnique() {
        var seen: [String: ActionType] = [:]
        for type in ActionType.allCases {
            guard let key = ActionType.metadata[type]?.displayNameKey else {
                XCTFail("\(type.rawValue) 메타데이터 누락")
                continue
            }
            if let other = seen[key] {
                XCTFail("\(type.rawValue) 와 \(other.rawValue) 가 같은 표시 키를 씀: \(key)")
            }
            seen[key] = type
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
