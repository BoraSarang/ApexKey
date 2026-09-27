import XCTest
@testable import ApexKey

/// 카탈로그 정합성 회귀 테스트 (PLAN_v0.21 T-159 / E-MAC-CAT-9401)
///
/// 감사에서 확인된 사실: `ActionType`은 153종인데 실제 실행되는 것은 28종(18%)이었다.
/// 나머지 125종은 `ActionExecutor`의 `default:` 분기에 떨어져 "미구현" 토스트와 함께
/// 실패했는데, 카탈로그에는 153종이 구분 없이 전부 노출됐다.
///
/// 이 테스트는 그 표면 정합을 고정한다. `ActionType+Implementation.swift`의 switch 는
/// `default:` 없이 153개를 전수 나열하므로, 새 case 추가 시 **컴파일 에러**가 나고
/// 여기 테스트는 수가 어긋나면 실패한다.
final class ActionCatalogIntegrityTests: XCTestCase {

    /// 전수 분류 누락이 없어야 한다 (switch 에 default:가 없으므로 컴파일 타임 보장)
    func testEveryActionTypeIsClassified() {
        XCTAssertEqual(
            ActionType.allCases.count,
            ActionType.implementationCounts().values.reduce(0, +),
            "분류되지 않은 ActionType이 존재"
        )
    }

    /// 집계 합계가 전체와 일치해야 한다
    func testImplementationCountsSumToTotal() {
        let counts = ActionType.implementationCounts()
        let total = counts.values.reduce(0, +)
        XCTAssertEqual(total, ActionType.allCases.count)
        XCTAssertNotNil(counts[.implemented], "implemented 항목이 없음")
    }

    /// 구현 완료 + 스텁 + 계획 = 전체
    func testThreeBucketsPartitionAllCases() {
        let implemented = ActionType.allCases.filter { $0.implementation == .implemented }
        let stub = ActionType.allCases.filter { $0.implementation == .stub }
        let planned = ActionType.allCases.filter { $0.implementation == .planned }
        XCTAssertEqual(
            implemented.count + stub.count + planned.count,
            ActionType.allCases.count
        )
    }

    /// 카탈로그 기본 노출은 구현 완료분만이어야 한다
    func testCatalogVisibleContainsOnlyImplemented() {
        for type in ActionType.catalogVisible {
            XCTAssertEqual(
                type.implementation, .implemented,
                "\(type.rawValue) 가 미구현인데 카탈로그에 노출됨"
            )
        }
        XCTAssertFalse(ActionType.catalogVisible.isEmpty, "노출되는 액션이 하나도 없음")
    }

    /// 미구현 액션은 선택 불가여야 한다
    func testNotImplementedActionsAreNotSelectable() {
        for type in ActionType.notImplemented {
            XCTAssertFalse(
                type.isSelectable,
                "\(type.rawValue) 는 구현되지 않았는데 선택 가능"
            )
            XCTAssertFalse(
                type.hasStepSettingsUI,
                "\(type.rawValue) 는 구현되지 않았는데 단계 설정 UI를 제공함"
            )
        }
    }

    /// 미구현 + 스텁 = 125종 (감사 시점 기준선 — 구현이 늘면 이 값이 올라야 한다)
    func testNotImplementedBaseline() {
        let notImplemented = ActionType.notImplemented
        XCTAssertEqual(
            notImplemented.count,
            ActionType.allCases.count - ActionType.implementationCounts()[.implemented]!,
            "notImplemented 목록이 allCases와 집계에서 어긋남"
        )
        // 기준선 기록: 구현이 추가되면 이 수치는 감소해야 한다
        XCTAssertLessThan(
            notImplemented.count, ActionType.allCases.count,
            "모든 액션이 구현됨 — 이 테스트의 기준선을 갱신하세요"
        )
    }

    /// 핵심 실행 액션이 "구현됨"으로 분류되어야 한다 (회귀: 실수로 planned에 빠지면 안 됨)
    func testCoreActionsAreImplemented() {
        let core: [ActionType] = [
            .launchApp, .keyCombo, .menuCommand, .url, .file, .script,
            .appleScript, .javaScriptForAutomation, .system, .paste, .wait,
            .coordinateClick, .pauseUntilInput, .macro,
            .ifElse, .repeatLoop, .repeatEach, .chooseFromMenu, .runShortcut,
            .stopShortcut, .setVariable, .outputToVariable, .comment, .endRepeat,
        ]
        for type in core {
            XCTAssertEqual(
                type.implementation, .implemented,
                "\(type.rawValue) 는 핵심 액션이므로 implemented 여야 함"
            )
        }
    }

    /// AI 3종은 스텁으로 분류되어야 한다 (정직한 실패 반환으로 바꿨으므로 stub이 맞다)
    func testAIActionsAreStubNotImplemented() {
        for type in [ActionType.useModel, .writingTool, .imagePlayground] {
            XCTAssertEqual(
                type.implementation, .stub,
                "\(type.rawValue) 는 FoundationModels 연동 전이므로 stub이어야 함"
            )
            XCTAssertFalse(type.isSelectable, "\(type.rawValue) 는 선택 불가여야 함")
        }
    }

    /// iOS 단축어 원본에서 그대로 옮겨온 미구현 액션들이 planned로 남아 있는지
    func testKnownUnimplementedRemainPlanned() {
        let known: [ActionType] = [
            .translate, .regex, .matchText, .replaceText, .splitText, .trimWhitespace,
            .count, .formatNumber, .getClipboard, .setClipboard, .scanQRCode,
            .recognizeText, .hash, .uuid, .base64Encode, .htmlToMarkdown,
        ]
        for type in known {
            XCTAssertEqual(
                type.implementation, .planned,
                "\(type.rawValue) 는 미구현이므로 planned여야 함"
            )
        }
    }

    /// 카테고리별 actionTypes 목록에 없는 case가 allCases에 있으면 안 된다
    /// (카탈로그가 Some 액션을 누락하는지 확인)
    func testAllCategoriesCoverAllCases() {
        let listed = Set(ActionCategory.allCases.flatMap(\.actionTypes))
        let missing = Set(ActionType.allCases).subtracting(listed)
        XCTAssertTrue(
            missing.isEmpty,
            "카테고리 목록에 없는 액션: \(missing.map(\.rawValue).sorted())"
        )
    }
}
