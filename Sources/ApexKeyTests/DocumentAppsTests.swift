import XCTest
@testable import ApexKey

/// T-216 문서 앱 연동 — Pages·Numbers·TextEdit 검증.
///
/// 실제 앱 실행·자동화 권한·설치 상태에 의존하지 않는다. 설치 확인, 실행기,
/// URL 열기 클로저를 주입해 인자 구성과 실패 사유를 결정적으로 검사한다.
final class DocumentAppsTests: XCTestCase {

    private func result(
        exitCode: Int32 = 0,
        output: String = "",
        error: String = "",
        timedOut: Bool = false
    ) -> ProcessRunner.Result {
        ProcessRunner.Result(
            exitCode: exitCode,
            standardOutput: output,
            standardError: error,
            timedOut: timedOut
        )
    }

    private func makeFile(named name: String = "note.txt") throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("ApexKeyDoc-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(name)
        try "hello".write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    // MARK: - 순수 로직

    func testConfigDefaults() {
        let config = DocumentConfig()
        XCTAssertEqual(config.resolvedApp, .textEdit)
        XCTAssertEqual(config.resolvedEditMode, .append)
        XCTAssertEqual(config.resolvedFontSize, 0)
    }

    func testConfigTolerantDecoding() throws {
        // 알 수 없는 필드와 일부 누락이 저장된 설정 전체를 무효화하면 안 된다
        let data = Data(#"{"app":"pages","fontName":"Menlo","unknown":42}"#.utf8)
        let config = DocumentConfig.decode(from: data)
        XCTAssertEqual(config.app, .pages)
        XCTAssertEqual(config.fontName, "Menlo")
        XCTAssertNil(config.path)
    }

    func testScriptsReadArgumentsFromArgv() {
        let sources = [
            DocumentApps.scripts.textEditNew,
            DocumentApps.scripts.textEditOpen,
            DocumentApps.scripts.textEditEdit,
            DocumentApps.scripts.textEditStyle,
        ]
        for source in sources {
            XCTAssertTrue(source.contains("on run argv"), source)
        }
    }

    // MARK: - 새 문서

    func testCreateDocumentPassesContentForTextEdit() {
        var captured: (String, [String])?
        let outcome = DocumentApps.createDocument(
            app: .textEdit,
            content: "첫 줄\n둘째 줄",
            installed: { _ in true }
        ) { source, arguments in
            captured = (source, arguments)
            return self.result(output: "제목 없음")
        }
        XCTAssertEqual(outcome, .success(["제목 없음"]))
        XCTAssertEqual(captured?.1, ["첫 줄\n둘째 줄"])
        XCTAssertTrue(captured?.0.contains("tell application \"TextEdit\"") == true)
    }

    func testCreateDocumentRejectsMissingApp() {
        let outcome = DocumentApps.createDocument(
            app: .pages,
            content: "",
            installed: { _ in false }
        ) { _, _ in
            XCTFail("미설치 앱은 스크립트를 실행하지 않아야 함")
            return self.result()
        }
        XCTAssertEqual(outcome, .failure(.appNotInstalled(DocumentConfig.App.pages.displayName)))
    }

    func testCreateDocumentRejectsDefaultApp() {
        let outcome = DocumentApps.createDocument(
            app: .defaultApp,
            content: "x",
            installed: { _ in true }
        ) { _, _ in
            XCTFail("기본 앱으로는 새 문서를 만들지 않는다")
            return self.result()
        }
        XCTAssertEqual(outcome, .failure(.unsupportedApp(DocumentConfig.App.defaultApp.displayName)))
    }

    func testCreateDocumentRunsPagesWhenInstalled() {
        var captured: String?
        let outcome = DocumentApps.createDocument(
            app: .pages,
            content: "",
            installed: { _ in true }
        ) { source, _ in
            captured = source
            return self.result(output: "Pages")
        }
        XCTAssertEqual(outcome, .success(["Pages"]))
        XCTAssertTrue(captured?.contains("tell application \"Pages\"") == true)
    }

    // MARK: - 문서 열기

    func testViewDocumentMissingFileFailsBeforeOpening() throws {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("ApexKeyDoc-missing-\(UUID().uuidString).txt")
        let outcome = DocumentApps.viewDocument(
            path: missing.path,
            app: .defaultApp,
            installed: { _ in true },
            opener: { _ in
                XCTFail("없는 파일은 열지 않아야 함")
                return true
            }
        ) { _, _ in
            XCTFail("없는 파일은 스크립트를 실행하지 않아야 함")
            return self.result()
        }
        XCTAssertEqual(outcome, .failure(.fileNotFound(missing.path)))
    }

    func testViewDocumentDefaultAppUsesOpener() throws {
        let url = try makeFile()
        defer { cleanup(url) }
        var opened: URL?
        let outcome = DocumentApps.viewDocument(
            path: url.path,
            app: .defaultApp,
            opener: { target in
                opened = target
                return true
            }
        )
        XCTAssertEqual(outcome, .success([url.path]))
        XCTAssertEqual(opened, url)
    }

    func testViewDocumentTextEditPassesPath() throws {
        let url = try makeFile()
        defer { cleanup(url) }
        var arguments: [String]?
        let outcome = DocumentApps.viewDocument(
            path: url.path,
            app: .textEdit,
            installed: { _ in true }
        ) { source, args in
            XCTAssertTrue(source.contains("tell application \"TextEdit\""))
            arguments = args
            return self.result(output: "note.txt")
        }
        XCTAssertEqual(outcome, .success(["note.txt"]))
        XCTAssertEqual(arguments, [url.path])
    }

    func testViewDocumentReportsAutomationDenied() throws {
        let url = try makeFile()
        defer { cleanup(url) }
        let outcome = DocumentApps.viewDocument(
            path: url.path,
            app: .pages,
            installed: { _ in true }
        ) { _, _ in
            self.result(exitCode: 1, error: "Not authorized to send Apple events (-1743)")
        }
        XCTAssertEqual(outcome, .failure(.automationDenied))
    }

    // MARK: - 문서 편집 (TextEdit 전용)

    func testEditDocumentRequiresContent() {
        let outcome = DocumentApps.editDocument(
            path: "",
            text: "  ",
            mode: .append,
            app: .textEdit,
            installed: { _ in true }
        ) { _, _ in
            XCTFail("내용이 비면 실행하지 않아야 함")
            return self.result()
        }
        XCTAssertEqual(outcome, .failure(.emptyContent))
    }

    func testEditDocumentRejectsNonTextEditApp() {
        let outcome = DocumentApps.editDocument(
            path: "",
            text: "x",
            mode: .append,
            app: .pages,
            installed: { _ in true }
        ) { _, _ in
            XCTFail("Pages 본문 편집은 지원하지 않는다")
            return self.result()
        }
        XCTAssertEqual(outcome, .failure(.unsupportedApp(DocumentConfig.App.pages.displayName)))
    }

    func testEditDocumentPassesModeAndPath() throws {
        let url = try makeFile()
        defer { cleanup(url) }
        var arguments: [String]?
        let outcome = DocumentApps.editDocument(
            path: url.path,
            text: "덧붙임",
            mode: .replace,
            app: .textEdit,
            installed: { _ in true }
        ) { _, args in
            arguments = args
            return self.result(output: "note.txt")
        }
        XCTAssertEqual(outcome, .success(["note.txt"]))
        XCTAssertEqual(arguments, [url.path, "덧붙임", "replace"])
    }

    func testEditDocumentWithoutPathUsesOpenDocumentOrReportsMissing() {
        let outcome = DocumentApps.editDocument(
            path: "",
            text: "x",
            mode: .append,
            app: .textEdit,
            installed: { _ in true }
        ) { _, args in
            XCTAssertEqual(args.first, "", "경로가 없으면 열린 문서를 써야 함")
            return self.result(exitCode: 1, error: "execution error: APEX_NO_DOCUMENT (-9401)")
        }
        XCTAssertEqual(outcome, .failure(.noOpenDocument))
    }

    func testEditDocumentMissingPathFails() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("ApexKeyDoc-missing-\(UUID().uuidString).txt")
        let outcome = DocumentApps.editDocument(
            path: missing.path,
            text: "x",
            mode: .append,
            app: .textEdit,
            installed: { _ in true }
        ) { _, _ in
            XCTFail("없는 경로는 스크립트를 실행하지 않아야 함")
            return self.result()
        }
        XCTAssertEqual(outcome, .failure(.fileNotFound(missing.path)))
    }

    // MARK: - 문단 스타일

    func testSetParagraphStyleRequiresFontOrSize() {
        let outcome = DocumentApps.setParagraphStyle(
            path: "",
            fontName: " ",
            fontSize: 0,
            app: .textEdit,
            installed: { _ in true }
        ) { _, _ in
            XCTFail("글꼴도 크기도 없으면 실행하지 않아야 함")
            return self.result()
        }
        XCTAssertEqual(outcome, .failure(.emptyStyle))
    }

    func testSetParagraphStyleRejectsNonTextEditApp() {
        let outcome = DocumentApps.setParagraphStyle(
            path: "",
            fontName: "Menlo",
            fontSize: 12,
            app: .numbers,
            installed: { _ in true }
        ) { _, _ in
            XCTFail("Numbers 글꼴 지정은 지원하지 않는다")
            return self.result()
        }
        XCTAssertEqual(outcome, .failure(.unsupportedApp(DocumentConfig.App.numbers.displayName)))
    }

    func testSetParagraphStylePassesFontAndSize() {
        var arguments: [String]?
        let outcome = DocumentApps.setParagraphStyle(
            path: "",
            fontName: "Menlo",
            fontSize: 15,
            app: .textEdit,
            installed: { _ in true }
        ) { source, args in
            XCTAssertTrue(source.contains("set font of targetText"))
            arguments = args
            return self.result(output: "제목 없음")
        }
        XCTAssertEqual(outcome, .success(["제목 없음"]))
        XCTAssertEqual(arguments, ["Menlo", "15", ""])
    }

    // MARK: - 엔진 배선

    private func run(_ step: ShortcutStep) -> ExecutionEngine.Result {
        var context = UseModelExecutor.ExecutionContext()
        return ExecutionEngine.shared.execute(steps: [step], context: &context)
    }

    private func step(_ type: ActionType, _ config: DocumentConfig) -> ShortcutStep {
        ShortcutStep(type: type, target: "", title: "", actionParameters: config.encode())
    }

    /// 실제 앱을 띄우지 않고 실패하는 경로만 엔진에 통과시킨다.
    func testDocumentActionsAreWiredIntoEngine() {
        let unimplemented = "toast.reason.unimplemented".localized
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("ApexKeyDoc-missing-\(UUID().uuidString).txt").path

        let cases: [(ActionType, DocumentConfig)] = [
            // 기본 앱으로는 새 문서를 만들 수 없다
            (.newDocument, DocumentConfig(app: .defaultApp)),
            // 없는 파일은 열지 않는다
            (.viewDocument, DocumentConfig(app: .defaultApp, path: missing)),
            // 내용이 비면 편집하지 않는다
            (.editDocument, DocumentConfig(app: .textEdit, content: "  ")),
            // 글꼴·크기가 모두 비면 스타일을 바꾸지 않는다
            (.setParagraphStyle, DocumentConfig(app: .textEdit)),
        ]

        for (type, config) in cases {
            let result = run(step(type, config))
            XCTAssertFalse(result.success, "\(type.rawValue) 는 잘못된 입력으로 실패해야 함")
            XCTAssertNotEqual(
                result.error,
                unimplemented,
                "\(type.rawValue) 가 엔진에 배선되지 않았다"
            )
        }
    }
}
