import XCTest
import AppKit
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
    ///
    /// E-MAC-TEXT-6001(11종)·E-MAC-TEXT-6002(12종)로 구현되어 목록에서 빠졌다.
    /// 그 사실을 여기서 못 박아 둔다 — 목록에 넣었다가 구현 없이 되돌리면
    /// "카탈로그에는 노출되는데 실행은 안 되는" 상태(T-159)가 되돌아온다.
    func testKnownUnimplementedRemainPlanned() {
        let known: [ActionType] = [
            .translate, .scanQRCode, .recognizeText, .htmlToMarkdown,
        ]
        for type in known {
            XCTAssertEqual(
                type.implementation, .planned,
                "\(type.rawValue) 는 미구현이므로 planned여야 함"
            )
        }
    }

    /// E-MAC-TEXT-6001/6002로 구현한 23종이 implemented로 유지되는지
    ///
    /// 역방향 가드: 구현을 되돌렸는데 정의를 그대로 두면 카탈로그가 "준비 중"으로
    /// 숨기지만 실제로는 동작하는, 설명과 반대의 상태가 된다.
    func testTextActionsStayImplemented() {
        let implemented: [ActionType] = [
            // 6001 — 텍스트 11종
            .text, .combineText, .splitText, .trimWhitespace, .replaceText,
            .regex, .matchText, .count, .formatNumber, .getClipboard, .setClipboard,
            // 6002 — 수치·날짜·목록 12종
            .changeCase, .sort, .surroundText, .wordCount, .calculate, .math,
            .number, .outputDifference, .base64Encode, .hash, .uuid, .dateFormatter,
        ]
        for type in implemented {
            XCTAssertEqual(
                type.implementation, .implemented,
                "\(type.rawValue) 는 구현되어 있으므로 implemented여야 함"
            )
            XCTAssertTrue(type.isSelectable, "\(type.rawValue) 는 카탈로그에서 선택 가능해야 함")
            XCTAssertTrue(type.hasStepSettingsUI, "\(type.rawValue) 는 설정 UI를 제공해야 함")
        }
    }

    /// 텍스트 액션 11종이 엔진에서 **실제로 실행된다**
    ///
    /// `TextActions`의 순수 함수만 테스트하면 **배선을 놓친다.** 카탈로그가 "구현됨"이라
    /// 말하지만 `executeStep`에 case가 없으면 `.planned`일 때와 똑같이 실패한다.
    /// T-159(카탈로그 정합)가 바로 그랬다. 여기서 엔진 경유로 확인한다.
    func testTextActionsExecuteThroughEngine() {
        struct Case {
            let type: ActionType
            let target: String
            let config: TextActionConfig?
            let expect: String
        }
        var config1 = TextActionConfig(); config1.separator = ","
        var configR = TextActionConfig(); configR.search = "\\d+"
        var configRep = TextActionConfig(); configRep.search = "X"; configRep.replacement = "-"
        var configSep = TextActionConfig(); configSep.separator = ","
        var configCnt = TextActionConfig(); configCnt.countUnit = .words
        var configNum = TextActionConfig(); configNum.numberStyle = .decimal; configNum.decimals = 0; configNum.grouping = false

        let cases: [Case] = [
            Case(type: .text, target: "안녕", config: nil, expect: "안녕"),
            Case(type: .trimWhitespace, target: "  안녕  ", config: nil, expect: "안녕"),
            Case(type: .combineText, target: "a,b,c", config: config1, expect: "a,b,c"),
            Case(type: .splitText, target: "a,b,c", config: configSep, expect: "a\nb\nc"),
            Case(type: .replaceText, target: "aXbXc", config: configRep, expect: "a-b-c"),
            Case(type: .regex, target: "a1b22", config: configR, expect: "1"),
            Case(type: .matchText, target: "a1", config: configR, expect: "true"),
            Case(type: .count, target: "hello world", config: configCnt, expect: "2"),
            Case(type: .formatNumber, target: "1234", config: configNum, expect: "1234"),
        ]

        for c in cases {
            var step = ShortcutStep(type: c.type, target: c.target, title: "")
            step.actionParameters = c.config.flatMap { try? JSONEncoder().encode($0) }
            var context = UseModelExecutor.ExecutionContext()
            let result = ExecutionEngine.shared.execute(steps: [step], context: &context)
            XCTAssertTrue(result.success, "\(c.type.rawValue) 실행 실패: \(result.error ?? "-")")
            XCTAssertEqual(
                context.lastOutput.asText ?? "<nil>", c.expect,
                "\(c.type.rawValue) 결과 불일치"
            )
        }
    }

    /// 수치·날짜·목록 12종도 **엔진 경유**로 실행되는지 (E-MAC-TEXT-6002)
    ///
    /// 순수 함수 테스트만으로는 `executeStep`에 case가 없다는 걸 못 잡는다 —
    /// 카탈로그가 "구현됨"이라 말하지만 실행하면 `planned`와 똑같이 실패한다.
    func testDataActionsExecuteThroughEngine() {
        struct Case {
            let type: ActionType
            let target: String
            let config: TextActionConfig?
            let expect: String
        }
        var caseStyle = TextActionConfig(); caseStyle.caseStyle = .uppercase
        var sortCfg = TextActionConfig(); sortCfg.sortMode = .numeric; sortCfg.sortOrder = .ascending
        var surround = TextActionConfig(); surround.prefix = "["; surround.suffix = "]"
        var mathAdd = TextActionConfig(); mathAdd.mathOperation = .add
        var mathMul = TextActionConfig(); mathMul.mathOperation = .multiply
        var numDec = TextActionConfig(); numDec.decimals = 1
        var diff = TextActionConfig(); diff.separator = "\n"
        var b64dec = TextActionConfig(); b64dec.decode = true
        var hashCfg = TextActionConfig(); hashCfg.hashAlgorithm = .sha256
        var dateCfg = TextActionConfig(); dateCfg.dateFormat = "yyyy"

        let cases: [Case] = [
            Case(type: .changeCase, target: "abc", config: caseStyle, expect: "ABC"),
            Case(type: .sort, target: "10\n9\n100", config: sortCfg, expect: "9\n10\n100"),
            Case(type: .surroundText, target: "안녕", config: surround, expect: "[안녕]"),
            Case(type: .wordCount, target: "a b c", config: nil, expect: "3"),
            Case(type: .calculate, target: "2+3*4", config: nil, expect: "14"),
            Case(type: .math, target: "3\n4", config: mathAdd, expect: "7"),
            Case(type: .math, target: "3\n4", config: mathMul, expect: "12"),
            Case(type: .number, target: "3.14159", config: numDec, expect: "3.1"),
            Case(type: .outputDifference, target: "10\n3", config: diff, expect: "7"),
            Case(type: .base64Encode, target: "7JWI64WV", config: b64dec, expect: "안녕"),
            // 해시·날짜는 출력이 길거나 시간 의존이라 같은 함수의 결과를 기준으로 삼는다
            Case(type: .hash, target: "a", config: hashCfg, expect: DataActions.hash("a", algorithm: .sha256).text),
            Case(type: .dateFormatter, target: "0", config: dateCfg, expect: DataActions.formatDate("0", format: "yyyy").text),
        ]

        for c in cases {
            var step = ShortcutStep(type: c.type, target: c.target, title: "")
            step.actionParameters = c.config.flatMap { try? JSONEncoder().encode($0) }
            var context = UseModelExecutor.ExecutionContext()
            let result = ExecutionEngine.shared.execute(steps: [step], context: &context)
            XCTAssertTrue(result.success, "\(c.type.rawValue) 실행 실패: \(result.error ?? "-")")
            XCTAssertEqual(
                context.lastOutput.asText ?? "<nil>", c.expect,
                "\(c.type.rawValue) 결과 불일치"
            )
        }

        // uuid는 입력이 없고 결과가 매번 달라지므로 "성공 + 형식"만 확인
        let uuidStep = ShortcutStep(type: .uuid, target: "", title: "")
        var uuidContext = UseModelExecutor.ExecutionContext()
        let uuidResult = ExecutionEngine.shared.execute(steps: [uuidStep], context: &uuidContext)
        XCTAssertTrue(uuidResult.success, "uuid 실행 실패")
        XCTAssertNotNil(UUID(uuidString: uuidContext.lastOutput.asText ?? ""), "UUID 형식이 아니다")
    }

    /// 클립보드 2종도 엔진 경유로 확인한다
    ///
    /// 엔진은 `NSPasteboard.general`을 쓰므로 **사용자 클립보드를 건드린다.**
    /// 원래 값을 저장해 두고 복원한다. 순서도 의도적이다 —
    /// 빈 클립보드에서 get을 먼저 하면 "빈 클립보드"와 "배선 누락"을 구분할 수 없다.
    func testClipboardActionsExecuteThroughEngine() {
        let general = NSPasteboard.general
        let original = general.string(forType: .string)
        defer {
            general.clearContents()
            if let original { general.setString(original, forType: .string) }
        }

        // 1) set → 실제 클립보드에 쓰는지
        let setStep = ShortcutStep(type: .setClipboard, target: "엔진이 씁니다", title: "")
        var setContext = UseModelExecutor.ExecutionContext()
        let setResult = ExecutionEngine.shared.execute(steps: [setStep], context: &setContext)
        XCTAssertTrue(setResult.success, "setClipboard 실행 실패: \(setResult.error ?? "-")")
        XCTAssertEqual(general.string(forType: .string), "엔진이 씁니다", "클립보드에 쓰이지 않음")

        // 2) get → 방금 쓴 값을 읽는지
        let getStep = ShortcutStep(type: .getClipboard, target: "", title: "")
        var getContext = UseModelExecutor.ExecutionContext()
        let getResult = ExecutionEngine.shared.execute(steps: [getStep], context: &getContext)
        XCTAssertTrue(getResult.success, "getClipboard 실행 실패: \(getResult.error ?? "-")")
        XCTAssertEqual(getContext.lastOutput.asText, "엔진이 씁니다", "클립보드 읽기 배선 실패")
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
