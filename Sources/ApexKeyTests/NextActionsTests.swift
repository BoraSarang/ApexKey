import XCTest
import AppKit
@testable import ApexKey

/// T-211 순수 로직·UI 액션 14종 검증
///
/// 규칙: 부작용 없는 경로만 자동화한다. 실제 알림·Quick Look 패널·caffeinate
/// 프로세스는 띄우지 않고, 주입 가능한 경계(`runner`·`imageData`·파일 경로)로
/// 실패·성공을 판정한다.
final class NextActionsTests: XCTestCase {

    // MARK: - 언어 감지

    func testDetectLanguageKorean() {
        let outcome = NextActions.detectLanguage("안녕하세요. 오늘 날씨가 정말 좋네요. 산책을 다녀왔습니다.")
        guard case .success(let text) = outcome else {
            return XCTFail("한국어 감지 실패: \(outcome)")
        }
        XCTAssertTrue(text.hasPrefix("ko"), "감지 결과: \(text)")
    }

    func testDetectLanguageEmptyFails() {
        XCTAssertEqual(NextActions.detectLanguage("   "), .failure(.emptyInput))
    }

    // MARK: - 측정 변환

    func testMeasurementMetersToKilometers() {
        let outcome = NextActions.measurement("12.5 m", from: nil, to: .kilometers)
        XCTAssertEqual(outcome, .success("0.0125 km"))
    }

    func testMeasurementCelsiusToFahrenheit() {
        let outcome = NextActions.measurement("100 c", from: nil, to: .fahrenheit)
        XCTAssertEqual(outcome, .success("212 °F"))
    }

    func testMeasurementWithExplicitFromUnit() {
        let outcome = NextActions.measurement("2", from: .kilograms, to: .pounds)
        guard case .success(let text) = outcome else {
            return XCTFail("변환 실패: \(outcome)")
        }
        XCTAssertTrue(text.hasSuffix(" lb"), "결과: \(text)")
    }

    func testMeasurementDimensionMismatchFails() {
        XCTAssertEqual(
            NextActions.measurement("1 kg", from: nil, to: .meters),
            .failure(.dimensionMismatch)
        )
    }

    func testMeasurementInvalidFails() {
        XCTAssertEqual(
            NextActions.measurement("abc", from: nil, to: .meters),
            .failure(.invalidMeasurement("abc"))
        )
    }

    // MARK: - 날짜

    func testAdjustDateAddsHours() {
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let outcome = NextActions.adjustDate("", amount: 2, unit: .hours, now: base)
        guard case .success(let text) = outcome,
              let parsed = NextActions.parseDate(text) else {
            return XCTFail("날짜 조정 실패: \(outcome)")
        }
        XCTAssertEqual(
            parsed.timeIntervalSince1970,
            base.timeIntervalSince1970 + 7200,
            accuracy: 1
        )
    }

    func testAdjustDateParsesISODate() {
        let outcome = NextActions.adjustDate(
            "2026-11-09T00:00:00Z",
            amount: 1,
            unit: .days,
            format: "yyyy-MM-dd"
        )
        guard case .success(let text) = outcome else {
            return XCTFail("날짜 조정 실패: \(outcome)")
        }
        XCTAssertEqual(text.count, 10, "형식 적용 실패: \(text)")
    }

    func testAdjustDateInvalidInputFails() {
        XCTAssertEqual(
            NextActions.adjustDate("not-a-date", amount: 1, unit: .days),
            .failure(.invalidDate("not-a-date"))
        )
    }

    // MARK: - 딕셔너리

    private let sampleJSON = #"{"name":"Apex","user":{"age":30},"flag":true}"#

    func testDictionaryReadsTopLevelKey() {
        XCTAssertEqual(
            NextActions.dictionary(sampleJSON, key: "name"),
            .success("Apex")
        )
    }

    func testDictionaryReadsNestedKey() {
        XCTAssertEqual(
            NextActions.dictionary(sampleJSON, key: "user.age"),
            .success("30")
        )
    }

    func testDictionaryReadsBoolean() {
        XCTAssertEqual(
            NextActions.dictionary(sampleJSON, key: "flag"),
            .success("true")
        )
    }

    func testDictionaryMissingKeyFails() {
        XCTAssertEqual(
            NextActions.dictionary(sampleJSON, key: "nope"),
            .failure(.missingKey("nope"))
        )
    }

    func testDictionaryEmptyKeyReturnsWholeObject() {
        guard case .success(let text) = NextActions.dictionary(sampleJSON, key: nil) else {
            return XCTFail("전체 딕셔너리 출력 실패")
        }
        XCTAssertTrue(text.contains("\"name\""))
        XCTAssertTrue(text.contains("\"user\""))
    }

    func testDictionaryReadsPlist() {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>city</key>
            <string>Seoul</string>
        </dict>
        </plist>
        """
        XCTAssertEqual(NextActions.dictionary(plist, key: "city"), .success("Seoul"))
    }

    func testDictionaryInvalidInputFails() {
        XCTAssertEqual(
            NextActions.dictionary("not json", key: nil),
            .failure(.invalidDictionary)
        )
    }

    // MARK: - 목록

    func testListActionsMatchesCatalog() {
        guard case .success(let text) = NextActions.listActions() else {
            return XCTFail("목록 출력 실패")
        }
        let lines = text.split(separator: "\n")
        XCTAssertEqual(lines.count, ActionType.catalogVisible.count)
        XCTAssertFalse(lines.isEmpty)
    }

    // MARK: - 출력 저장

    func testSaveOutputWritesAppendsAndOverwrites() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let path = dir.appendingPathComponent("out.txt").path

        XCTAssertEqual(
            NextActions.saveOutput("hello", to: path, append: false),
            .success(path)
        )
        XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), "hello")

        XCTAssertEqual(
            NextActions.saveOutput(" world", to: path, append: true),
            .success(path)
        )
        XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), "hello world")

        XCTAssertEqual(
            NextActions.saveOutput("reset", to: path, append: false),
            .success(path)
        )
        XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), "reset")
    }

    func testSaveOutputEmptyPathFails() {
        XCTAssertEqual(
            NextActions.saveOutput("x", to: "  ", append: false),
            .failure(.emptyPath)
        )
    }

    // MARK: - 사용자 프롬프트

    func testDialogReturnsTypedText() {
        let answer = UserPromptActions.dialog(message: "이름", defaultText: "기본값") { alert in
            let field = alert.accessoryView as? NSTextField
            XCTAssertEqual(field?.stringValue, "기본값")
            field?.stringValue = "ApexKey"
            return .alertFirstButtonReturn
        }
        XCTAssertEqual(answer, "ApexKey")
    }

    func testDialogCancelReturnsEmpty() {
        let answer = UserPromptActions.dialog(message: "이름", defaultText: nil) { _ in
            .alertSecondButtonReturn
        }
        XCTAssertEqual(answer, "")
    }

    func testConfirmationOKIsTrue() {
        XCTAssertTrue(UserPromptActions.confirmation(message: "계속?") { _ in
            .alertFirstButtonReturn
        })
    }

    func testConfirmationCancelIsFalse() {
        XCTAssertFalse(UserPromptActions.confirmation(message: "계속?") { _ in
            .alertSecondButtonReturn
        })
    }

    // MARK: - Vision 입력

    func testVisionMissingPathDoesNotFallBackToClipboard() {
        XCTAssertNil(VisionActions.imageData(from: "/nonexistent/ApexKey-test.png"))
    }

    func testVisionWithoutImageFails() {
        XCTAssertEqual(
            VisionActions.recognizeText(imageData: nil),
            .failure(.noImage)
        )
        XCTAssertEqual(
            VisionActions.scanQRCode(imageData: nil),
            .failure(.noImage)
        )
        XCTAssertEqual(
            VisionActions.recognizeAnimal(imageData: nil),
            .failure(.noImage)
        )
    }

    // MARK: - Quick Look

    func testQuickLookEmptyPathFails() {
        guard case .failure(.emptyPath) = QuickLookActions.shared.preview(path: " ") else {
            return XCTFail("빈 경로는 emptyPath로 실패해야 함")
        }
    }

    func testQuickLookMissingFileFails() {
        guard case .failure(.fileMissing) = QuickLookActions.shared.preview(
            path: "/nonexistent/ApexKey-test.pdf"
        ) else {
            return XCTFail("없는 파일은 fileMissing으로 실패해야 함")
        }
    }

    // MARK: - 잠자기 방지

    func testPreventSleepStatusAndSimulatedToggle() {
        let controller = PreventSleepController.shared
        controller.setActive(false)
        XCTAssertFalse(controller.isActive)
        XCTAssertEqual(
            controller.statusText,
            "ui.next_action.prevent_sleep_off".localized
        )

        XCTAssertTrue(controller.setActive(true))
        XCTAssertTrue(controller.isActive)
        XCTAssertEqual(
            controller.statusText,
            "ui.next_action.prevent_sleep_on".localized
        )

        controller.setActive(false)
        XCTAssertFalse(controller.isActive)
    }

    // MARK: - 엔진 배선

    private func run(_ step: ShortcutStep) -> (result: ExecutionEngine.Result, context: UseModelExecutor.ExecutionContext) {
        var context = UseModelExecutor.ExecutionContext()
        let result = ExecutionEngine.shared.execute(steps: [step], context: &context)
        return (result, context)
    }

    func testEngineRunsListActions() {
        let output = run(ShortcutStep(type: .listActions, target: "", title: "목록"))
        XCTAssertTrue(output.result.success)
        XCTAssertEqual(
            output.context.lastOutput.asText?.split(separator: "\n").count,
            ActionType.catalogVisible.count
        )
    }

    func testEngineRunsDetectLanguage() {
        let output = run(ShortcutStep(
            type: .detectLanguage,
            target: "안녕하세요. 오늘 날씨가 정말 좋네요.",
            title: "언어"
        ))
        XCTAssertTrue(output.result.success)
        XCTAssertTrue(output.context.lastOutput.asText?.hasPrefix("ko") ?? false)
    }

    func testEngineRunsMeasurement() {
        let config = TextActionConfig(measurementUnit: .kilometers)
        let step = ShortcutStep(
            type: .measurement,
            target: "12.5 m",
            title: "측정",
            actionParameters: try? JSONEncoder().encode(config)
        )
        let output = run(step)
        XCTAssertTrue(output.result.success)
        XCTAssertEqual(output.context.lastOutput.asText, "0.0125 km")
    }

    func testEngineRunsGetDictionary() {
        let config = TextActionConfig(text: sampleJSON, dictionaryKey: "user.age")
        let step = ShortcutStep(
            type: .getDictionary,
            target: "",
            title: "딕셔너리",
            actionParameters: try? JSONEncoder().encode(config)
        )
        let output = run(step)
        XCTAssertTrue(output.result.success)
        XCTAssertEqual(output.context.lastOutput.asText, "30")
    }

    func testEngineRunsSaveOutput() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let path = dir.appendingPathComponent("engine.txt").path
        let config = TextActionConfig(text: "engine", savePath: path)
        let step = ShortcutStep(
            type: .saveOutput,
            target: "",
            title: "저장",
            actionParameters: try? JSONEncoder().encode(config)
        )
        let output = run(step)
        XCTAssertTrue(output.result.success)
        XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), "engine")
    }

    func testEngineRunsPreventSleepStatus() {
        let config = TextActionConfig(preventSleepMode: .status)
        let step = ShortcutStep(
            type: .preventSleep,
            target: "",
            title: "상태",
            actionParameters: try? JSONEncoder().encode(config)
        )
        let output = run(step)
        XCTAssertTrue(output.result.success)
        XCTAssertEqual(
            output.context.lastOutput.asText,
            PreventSleepController.shared.statusText
        )
    }

    /// 14종이 "미구현" 토스트로 떨어지지 않는지 — 배선 누락 회귀 감지
    func testNextActionsAreWiredIntoEngine() {
        let unimplemented = "toast.reason.unimplemented".localized
        let cases: [ShortcutStep] = [
            ShortcutStep(type: .recognizeText, target: "/nonexistent/ApexKey.png", title: ""),
            ShortcutStep(type: .scanQRCode, target: "/nonexistent/ApexKey.png", title: ""),
            ShortcutStep(type: .recognizeAnimal, target: "/nonexistent/ApexKey.png", title: ""),
            ShortcutStep(type: .quickLook, target: "/nonexistent/ApexKey.pdf", title: ""),
            ShortcutStep(type: .saveOutput, target: "", title: ""),
            ShortcutStep(type: .adjustDate, target: "not-a-date", title: ""),
        ]
        for step in cases {
            let output = run(step)
            XCTAssertFalse(output.result.success, "\(step.type.rawValue) 는 잘못된 입력으로 실패해야 함")
            XCTAssertNotEqual(
                output.result.error,
                unimplemented,
                "\(step.type.rawValue) 가 엔진에 배선되지 않았다"
            )
        }
    }
}
