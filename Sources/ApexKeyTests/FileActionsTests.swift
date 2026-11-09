import XCTest
import AppKit
@testable import ApexKey

/// T-213 파일 액션 7종 검증.
///
/// 실제 사용자 파일은 건드리지 않는다 — 모든 경로는 임시 디렉터리 픽스처다.
/// 확인 창은 주입한 클로저로 대체해 UI 없이 승인·취소 경로를 모두 검증한다.
final class FileActionsTests: XCTestCase {

    private var root: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ApexKeyFileTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let root { try? FileManager.default.removeItem(at: root) }
        try super.tearDownWithError()
    }

    // MARK: - 픽스처

    @discardableResult
    private func write(_ name: String, in folder: URL, text: String = "x") throws -> URL {
        let url = folder.appendingPathComponent(name)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func makeDir(_ name: String, in folder: URL) throws -> URL {
        let url = folder.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: - 가져오기

    func testListFilesReturnsSortedFiles() throws {
        try write("b.txt", in: root)
        try write("a.txt", in: root)
        try makeDir("folder", in: root)

        let outcome = FileActions.listFiles(path: root.path)
        guard case .success(let urls) = outcome else {
            return XCTFail("목록 실패: \(outcome)")
        }
        XCTAssertEqual(urls.map(\.lastPathComponent), ["a.txt", "b.txt"])
    }

    func testListFilesRecursiveAndExtensionFilter() throws {
        let sub = try makeDir("sub", in: root)
        try write("top.txt", in: root)
        try write("deep.md", in: sub)
        try write("deep.txt", in: sub)

        let outcome = FileActions.listFiles(
            path: root.path,
            recursive: true,
            extensions: "txt"
        )
        guard case .success(let urls) = outcome else {
            return XCTFail("목록 실패: \(outcome)")
        }
        XCTAssertEqual(Set(urls.map(\.lastPathComponent)), ["top.txt", "deep.txt"])
    }

    func testListFilesMissingPathFails() {
        let missing = root.appendingPathComponent("nope").path
        XCTAssertEqual(
            FileActions.listFiles(path: missing),
            .failure(.notFound(missing))
        )
    }

    func testListFilesNoMatchesFails() throws {
        try write("a.md", in: root)
        XCTAssertEqual(
            FileActions.listFiles(path: root.path, extensions: "txt"),
            .failure(.noFiles(root.path))
        )
    }

    // MARK: - 이동

    func testMoveMovesFile() throws {
        let source = try write("a.txt", in: root)
        let destination = try makeDir("dest", in: root)

        let outcome = FileActions.move(
            [source.path],
            to: destination.path,
            confirm: { _ in true }
        )
        guard case .success(let moved) = outcome else {
            return XCTFail("이동 실패: \(outcome)")
        }
        XCTAssertEqual(moved.first?.lastPathComponent, "a.txt")
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: destination.appendingPathComponent("a.txt").path
        ))
    }

    func testMoveCancelKeepsSource() throws {
        let source = try write("a.txt", in: root)
        let destination = try makeDir("dest", in: root)

        let outcome = FileActions.move(
            [source.path],
            to: destination.path,
            confirm: { _ in false }
        )
        XCTAssertEqual(outcome, .failure(.cancelled))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }

    func testMoveConflictFailsWithoutOverwrite() throws {
        let source = try write("a.txt", in: root)
        let destination = try makeDir("dest", in: root)
        try write("a.txt", in: destination, text: "existing")

        let outcome = FileActions.move(
            [source.path],
            to: destination.path,
            confirm: { _ in true }
        )
        XCTAssertEqual(outcome, .failure(.conflict("a.txt")))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }

    func testMoveOverwriteReplacesDestination() throws {
        let source = try write("a.txt", in: root, text: "new")
        let destination = try makeDir("dest", in: root)
        try write("a.txt", in: destination, text: "old")

        let outcome = FileActions.move(
            [source.path],
            to: destination.path,
            overwrite: true,
            confirm: { _ in true }
        )
        guard case .success = outcome else {
            return XCTFail("이동 실패: \(outcome)")
        }
        let text = try String(
            contentsOf: destination.appendingPathComponent("a.txt"),
            encoding: .utf8
        )
        XCTAssertEqual(text, "new")
    }

    // MARK: - 이름 바꾸기

    func testRenameTemplateWithIndex() throws {
        let a = try write("a.txt", in: root)
        let b = try write("b.txt", in: root)

        let outcome = FileActions.rename(
            [a.path, b.path],
            template: "photo-{index}",
            find: nil,
            replace: nil,
            startNumber: 1,
            confirm: { _ in true }
        )
        guard case .success(let renamed) = outcome else {
            return XCTFail("이름 변경 실패: \(outcome)")
        }
        XCTAssertEqual(renamed.map(\.lastPathComponent), ["photo-1.txt", "photo-2.txt"])
    }

    func testRenameFindReplaceKeepsExtension() throws {
        let source = try write("report-final.txt", in: root)

        let outcome = FileActions.rename(
            [source.path],
            template: nil,
            find: "-final",
            replace: "",
            confirm: { _ in true }
        )
        guard case .success(let renamed) = outcome else {
            return XCTFail("이름 변경 실패: \(outcome)")
        }
        XCTAssertEqual(renamed.first?.lastPathComponent, "report.txt")
    }

    func testRenameDetectsBatchCollision() throws {
        let a = try write("a.txt", in: root)
        let b = try write("b.txt", in: root)

        let outcome = FileActions.rename(
            [a.path, b.path],
            template: "same",
            find: nil,
            replace: nil,
            confirm: { _ in true }
        )
        XCTAssertEqual(outcome, .failure(.conflict("same.txt")))
    }

    func testRenameNoChangeFails() throws {
        let source = try write("a.txt", in: root)
        let outcome = FileActions.rename(
            [source.path],
            template: nil,
            find: nil,
            replace: nil,
            confirm: { _ in true }
        )
        XCTAssertEqual(outcome, .failure(.noChange))
    }

    func testRenameInvalidNameFails() throws {
        let source = try write("a.txt", in: root)
        let outcome = FileActions.rename(
            [source.path],
            template: "bad/name",
            find: nil,
            replace: nil,
            confirm: { _ in true }
        )
        XCTAssertEqual(outcome, .failure(.invalidName("bad/name.txt")))
    }

    // MARK: - 압축 풀기

    func testExtractZip() throws {
        let sourceFolder = try makeDir("src", in: root)
        try write("inside.txt", in: sourceFolder, text: "hello")
        let archive = root.appendingPathComponent("archive.zip")
        let create = ProcessRunner.run(
            executable: "/usr/bin/ditto",
            arguments: ["-c", "-k", sourceFolder.path, archive.path]
        )
        guard create.succeeded else {
            throw XCTSkip("ditto로 zip을 만들지 못함: \(create.standardError)")
        }

        let destination = try makeDir("out", in: root)
        let outcome = FileActions.extractArchive(archive: archive.path, to: destination.path)
        guard case .success = outcome else {
            return XCTFail("압축 풀기 실패: \(outcome)")
        }
        let extracted = destination.appendingPathComponent("inside.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: extracted.path))
        XCTAssertEqual(try String(contentsOf: extracted, encoding: .utf8), "hello")
    }

    func testExtractUnsupportedFormatFails() throws {
        let archive = try write("archive.rar", in: root)
        XCTAssertEqual(
            FileActions.extractArchive(archive: archive.path, to: nil),
            .failure(.archiveUnsupported("rar"))
        )
    }

    // MARK: - 외부 저장소

    func testSelectVolumeByName() {
        let a = URL(fileURLWithPath: "/Volumes/USB")
        let b = URL(fileURLWithPath: "/Volumes/Backup")
        XCTAssertEqual(FileActions.selectVolume(named: "USB", from: [a, b]), a)
        XCTAssertEqual(FileActions.selectVolume(named: "Backup", from: [a, b]), b)
        XCTAssertNil(FileActions.selectVolume(named: "Missing", from: [a, b]))
    }

    func testSelectVolumeAutoOnlyWhenSingle() {
        let a = URL(fileURLWithPath: "/Volumes/USB")
        XCTAssertEqual(FileActions.selectVolume(named: nil, from: [a]), a)
        XCTAssertNil(FileActions.selectVolume(
            named: nil,
            from: [a, URL(fileURLWithPath: "/Volumes/Other")]
        ))
    }

    // MARK: - 파일 동작

    func testFileActionsCopy() throws {
        let source = try write("a.txt", in: root)
        let destination = try makeDir("dest", in: root)

        let outcome = FileActions.perform(
            operation: .copy,
            sourcePaths: [source.path],
            destination: destination.path,
            confirm: { _ in true }
        )
        guard case .success(let copied) = outcome else {
            return XCTFail("복사 실패: \(outcome)")
        }
        XCTAssertEqual(copied.first?.lastPathComponent, "a.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }

    func testFileActionsDuplicateUsesCopySuffix() throws {
        let source = try write("a.txt", in: root)
        let outcome = FileActions.perform(
            operation: .duplicate,
            sourcePaths: [source.path],
            destination: nil,
            confirm: { _ in true }
        )
        guard case .success(let duplicated) = outcome else {
            return XCTFail("복제 실패: \(outcome)")
        }
        XCTAssertEqual(duplicated.first?.lastPathComponent, "a copy.txt")
    }

    func testFileActionsRevealNeedsNoConfirmation() throws {
        let source = try write("a.txt", in: root)
        let outcome = FileActions.perform(
            operation: .reveal,
            sourcePaths: [source.path],
            destination: nil,
            confirm: { _ in
                XCTFail("Finder에서 보기는 확인 창을 띄우지 않아야 함")
                return false
            }
        )
        guard case .success = outcome else {
            return XCTFail("보기 실패: \(outcome)")
        }
    }

    // MARK: - 메일 첨부

    func testParseAttachmentPaths() {
        let output = "/tmp/a.pdf\n/tmp/b.png\n\n"
        XCTAssertEqual(
            FileActions.parseAttachmentPaths(output).map(\.lastPathComponent),
            ["a.pdf", "b.png"]
        )
    }

    // MARK: - 엔진 배선

    private func run(_ step: ShortcutStep) -> (result: ExecutionEngine.Result, context: UseModelExecutor.ExecutionContext) {
        var context = UseModelExecutor.ExecutionContext()
        let result = ExecutionEngine.shared.execute(steps: [step], context: &context)
        return (result, context)
    }

    func testEngineRunsGetFiles() throws {
        try write("a.txt", in: root)
        try write("b.md", in: root)
        let config = FileActionConfig(sourcePaths: root.path, extensions: "txt")
        let step = ShortcutStep(
            type: .getFiles,
            target: "",
            title: "가져오기",
            actionParameters: config.encode()
        )
        let output = run(step)
        XCTAssertTrue(output.result.success)
        XCTAssertEqual(output.context.lastOutput.asList?.count, 1)
    }

    func testEngineRunsMoveWithoutConfirmation() throws {
        let source = try write("a.txt", in: root)
        let destination = try makeDir("dest", in: root)
        let config = FileActionConfig(
            sourcePaths: source.path,
            destination: destination.path,
            confirmBeforeChange: false
        )
        let step = ShortcutStep(
            type: .moveFiles,
            target: "",
            title: "이동",
            actionParameters: config.encode()
        )
        let output = run(step)
        XCTAssertTrue(output.result.success)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: destination.appendingPathComponent("a.txt").path
        ))
    }

    /// 7종이 "미구현" 토스트로 떨어지지 않는지 — 배선 누락 회귀 감지
    func testFileActionsAreWiredIntoEngine() {
        let unimplemented = "toast.reason.unimplemented".localized
        let externalCopy = FileActionConfig(storageMode: .copy)
        let cases: [ShortcutStep] = [
            ShortcutStep(type: .getFiles, target: "/nonexistent/ApexKey", title: ""),
            ShortcutStep(type: .moveFiles, target: "", title: ""),
            ShortcutStep(type: .renameFiles, target: "", title: ""),
            ShortcutStep(type: .extractArchive, target: "/nonexistent/ApexKey.zip", title: ""),
            ShortcutStep(
                type: .externalStorage,
                target: "",
                title: "",
                actionParameters: externalCopy.encode()
            ),
            ShortcutStep(type: .fileActions, target: "", title: ""),
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
        // Mail 실행 여부에 의존하지 않도록 배선은 분류로 확인한다
        for type in [ActionType.getAttachment, .getFiles, .moveFiles, .renameFiles,
                     .extractArchive, .externalStorage, .fileActions] {
            XCTAssertEqual(type.implementation, .implemented, "\(type.rawValue) 구현 분류 누락")
        }
    }
}
