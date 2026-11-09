import CoreImage
import XCTest
@testable import ApexKey

/// T-220 미디어 편집·캡처 검증.
///
/// 실제 카메라·음악 앱·시스템 볼륨을 건드리지 않는다. 이미지 로더/라이터,
/// 비디오 실행기, 촬영기, 볼륨 설정기를 주입해 인자와 실패 사유를 검사한다.
final class MediaEditingTests: XCTestCase {

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

    private func makeTempFile(named name: String = "photo.png") throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("ApexKeyMedia-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(name)
        try Data().write(to: url)
        return url
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    private func colorImage(width: CGFloat = 100, height: CGFloat = 50) -> CIImage {
        CIImage(color: CIColor(red: 1, green: 0, blue: 0))
            .cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
    }

    // MARK: - 설정

    func testConfigDefaults() {
        let config = MediaEditingConfig()
        XCTAssertEqual(config.resolvedAngle, 90)
        XCTAssertEqual(config.resolvedVolume, 50)
        XCTAssertEqual(config.resolvedPlayback, .playPause)
        XCTAssertTrue(config.resolvedConfirm)
    }

    func testConfigTolerantDecoding() throws {
        let data = Data(#"{"angle":180,"volume":30,"unknown":true}"#.utf8)
        let config = MediaEditingConfig.decode(from: data)
        XCTAssertEqual(config.angle, 180)
        XCTAssertEqual(config.volume, 30)
        XCTAssertNil(config.path)
    }

    // MARK: - 이미지 회전

    func testRotateRejectsEmptyAndMissingPath() {
        XCTAssertEqual(
            MediaEditing.rotateImage(path: "  ", outputPath: "", angleDegrees: 90),
            .failure(.emptyPath)
        )
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString).png").path
        XCTAssertEqual(
            MediaEditing.rotateImage(path: missing, outputPath: "", angleDegrees: 90),
            .failure(.fileNotFound(missing))
        )
    }

    func testRotateRejectsZeroAngleAndSamePath() throws {
        let input = try makeTempFile()
        defer { cleanup(input) }
        XCTAssertEqual(
            MediaEditing.rotateImage(path: input.path, outputPath: "", angleDegrees: 0),
            .failure(.invalidAngle)
        )
        XCTAssertEqual(
            MediaEditing.rotateImage(
                path: input.path,
                outputPath: input.path,
                angleDegrees: 90,
                loader: { _ in self.colorImage() }
            ),
            .failure(.samePath)
        )
    }

    func testRotateWritesDerivedOutputAndSwapsExtent() throws {
        let input = try makeTempFile(named: "photo.png")
        defer { cleanup(input) }
        var written: (URL, CGRect)?

        let outcome = MediaEditing.rotateImage(
            path: input.path,
            outputPath: "",
            angleDegrees: 90,
            loader: { _ in self.colorImage(width: 100, height: 50) },
            writer: { image, url in
                written = (url, image.extent)
                return true
            }
        )

        let expected = input.deletingLastPathComponent().appendingPathComponent("photo-rotated.png")
        XCTAssertEqual(outcome, .success([expected.path]))
        XCTAssertEqual(written?.0, expected)
        XCTAssertEqual(written?.1.width ?? 0, 50, accuracy: 1)
        XCTAssertEqual(written?.1.height ?? 0, 100, accuracy: 1)
    }

    func testRotateReportsLoaderAndWriterFailures() throws {
        let input = try makeTempFile()
        defer { cleanup(input) }
        XCTAssertEqual(
            MediaEditing.rotateImage(
                path: input.path, outputPath: "", angleDegrees: 90, loader: { _ in nil }
            ),
            .failure(.unsupportedImage(input.path))
        )
        XCTAssertEqual(
            MediaEditing.rotateImage(
                path: input.path,
                outputPath: "",
                angleDegrees: 90,
                loader: { _ in self.colorImage() },
                writer: { _, _ in false }
            ),
            .failure(.writeFailed(input.deletingLastPathComponent()
                .appendingPathComponent("photo-rotated.png").path))
        )
    }

    // MARK: - 이미지 자르기

    func testCropRejectsInvalidRect() throws {
        let input = try makeTempFile()
        defer { cleanup(input) }
        XCTAssertEqual(
            MediaEditing.cropImage(
                path: input.path, outputPath: "", x: 0, y: 0, width: 0, height: 10,
                loader: { _ in self.colorImage() }
            ),
            .failure(.invalidCrop)
        )
        XCTAssertEqual(
            MediaEditing.cropImage(
                path: input.path, outputPath: "", x: 90, y: 0, width: 20, height: 10,
                loader: { _ in self.colorImage() }
            ),
            .failure(.invalidCrop)
        )
    }

    func testCropWritesRequestedExtent() throws {
        let input = try makeTempFile(named: "photo.png")
        defer { cleanup(input) }
        var extent: CGRect?

        let outcome = MediaEditing.cropImage(
            path: input.path,
            outputPath: "",
            x: 10, y: 5, width: 20, height: 15,
            loader: { _ in self.colorImage(width: 100, height: 50) },
            writer: { image, _ in
                extent = image.extent
                return true
            }
        )

        XCTAssertTrue(outcome.isSuccess)
        XCTAssertEqual(extent?.width ?? 0, 20, accuracy: 0.5)
        XCTAssertEqual(extent?.height ?? 0, 15, accuracy: 0.5)
        XCTAssertEqual(extent?.origin.x ?? -1, 0, accuracy: 0.5)
        XCTAssertEqual(extent?.origin.y ?? -1, 0, accuracy: 0.5)
    }

    // MARK: - 비디오

    func testTrimRejectsInvalidRange() throws {
        let input = try makeTempFile(named: "clip.mov")
        defer { cleanup(input) }
        XCTAssertEqual(
            MediaEditing.trimVideo(
                path: input.path, outputPath: "", startSeconds: 3, endSeconds: 3
            ),
            .failure(.invalidRange)
        )
    }

    func testTrimRunsAVConvertWithRange() throws {
        let input = try makeTempFile(named: "clip.mov")
        defer { cleanup(input) }
        var executable: String?
        var arguments: [String]?

        let outcome = MediaEditing.trimVideo(
            path: input.path,
            outputPath: "",
            startSeconds: 1.5,
            endSeconds: 4
        ) { path, args in
            executable = path
            arguments = args
            if let index = args.firstIndex(of: "--output"), index + 1 < args.count {
                try? Data().write(to: URL(fileURLWithPath: args[index + 1]))
            }
            return self.result()
        }

        let expected = input.deletingLastPathComponent().appendingPathComponent("clip-trimmed.mov")
        XCTAssertEqual(outcome, .success([expected.path]))
        XCTAssertEqual(executable, MediaEditing.avconvertPath)
        XCTAssertEqual(arguments?.first, "--source")
        XCTAssertTrue(arguments?.contains("--start") == true)
        XCTAssertTrue(arguments?.contains("1.500") == true)
        XCTAssertTrue(arguments?.contains("--duration") == true)
        XCTAssertTrue(arguments?.contains("2.500") == true)
    }

    func testTrimReportsRunnerAndMissingOutput() throws {
        let input = try makeTempFile(named: "clip.mov")
        defer { cleanup(input) }

        let failed = MediaEditing.trimVideo(
            path: input.path, outputPath: "", startSeconds: 0, endSeconds: 2
        ) { _, _ in
            self.result(exitCode: 1, error: "preset failed")
        }
        guard case .failure(.exportFailed(let detail)) = failed else {
            return XCTFail("실행 실패가 exportFailed로 와야 함")
        }
        XCTAssertTrue(detail.contains("preset failed"))

        XCTAssertEqual(
            MediaEditing.trimVideo(
                path: input.path, outputPath: "", startSeconds: 0, endSeconds: 2
            ) { _, _ in self.result() },
            .failure(.exportFailed("output was not created"))
        )
    }

    // MARK: - 카메라

    func testCameraDestination() {
        let empty = MediaEditing.photoDestination("")
        XCTAssertEqual(empty.pathExtension, "jpg")
        XCTAssertTrue(empty.lastPathComponent.hasPrefix("ApexKey-"))

        let folder = MediaEditing.photoDestination("/tmp/ApexKeyCamera")
        XCTAssertEqual(folder.deletingLastPathComponent().path, "/tmp/ApexKeyCamera")
        XCTAssertTrue(folder.lastPathComponent.hasPrefix("ApexKey-"))

        XCTAssertEqual(MediaEditing.photoDestination("/tmp/shot.png").path, "/tmp/shot.png")
    }

    func testCameraOutcomeMapping() {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("ApexKeyCamera-\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: folder) }

        XCTAssertTrue(
            MediaEditing.capturePhoto(outputPath: folder) { url in
                try? Data().write(to: url)
                return .success(())
            }.isSuccess
        )
        XCTAssertEqual(
            MediaEditing.capturePhoto(outputPath: folder) { _ in .failure(.denied) },
            .failure(.cameraDenied)
        )
        XCTAssertEqual(
            MediaEditing.capturePhoto(outputPath: folder) { _ in .failure(.unavailable) },
            .failure(.cameraUnavailable)
        )
        XCTAssertEqual(
            MediaEditing.capturePhoto(outputPath: folder) { _ in .failure(.failed("boom")) },
            .failure(.cameraFailed("boom"))
        )
    }

    // MARK: - 볼륨

    func testVolumeClampsAndReportsFailure() {
        var applied: Float?
        XCTAssertEqual(
            MediaEditing.setVolume(percent: 150) { value in
                applied = value
                return true
            },
            .success(["100%"])
        )
        XCTAssertEqual(applied, 1.0)

        XCTAssertEqual(
            MediaEditing.setVolume(percent: 40) { _ in false },
            .failure(.volumeUnavailable)
        )
    }

    // MARK: - 음악

    func testMusicScripts() {
        XCTAssertTrue(MediaEditing.scripts.music(.play).contains("play"))
        XCTAssertFalse(
            MediaEditing.scripts.music(.play).contains("APEX_MUSIC_NOT_RUNNING"),
            "재생은 앱을 실행할 수 있으므로 실행 중 검사를 넣지 않는다"
        )
        XCTAssertTrue(
            MediaEditing.scripts.music(.pause).contains("APEX_MUSIC_NOT_RUNNING")
        )
        XCTAssertTrue(MediaEditing.scripts.music(.next).contains("next track"))
        XCTAssertTrue(MediaEditing.scripts.currentTrack.contains("player state is stopped"))
        XCTAssertTrue(MediaEditing.scripts.currentTrack.contains("POSIX path"))
    }

    func testMusicClassifiesFailures() {
        XCTAssertEqual(
            MediaEditing.music(command: .pause) { _, _ in
                self.result(exitCode: 1, error: "APEX_MUSIC_NOT_RUNNING")
            },
            .failure(.musicNotRunning)
        )
        XCTAssertEqual(
            MediaEditing.music(command: .play) { _, _ in
                self.result(exitCode: 1, error: "Not authorized to send Apple events (-1743)")
            },
            .failure(.automationDenied)
        )
        XCTAssertEqual(
            MediaEditing.currentTrackPath { _, _ in
                self.result(exitCode: 1, error: "APEX_NOTHING_PLAYING")
            },
            .failure(.nothingPlaying)
        )
    }

    func testMusicSuccessOutputsCommandName() {
        let outcome = MediaEditing.music(command: .playPause) { _, _ in self.result() }
        XCTAssertEqual(outcome, .success([MediaEditingConfig.PlaybackCommand.playPause.displayName]))
    }

    // MARK: - 현재 곡 이동

    func testMoveCurrentTrackRequiresDestination() throws {
        let source = try makeTempFile(named: "song.m4a")
        defer { cleanup(source) }
        XCTAssertEqual(
            MediaEditing.moveCurrentTrack(destination: "  ") { _, _ in
                self.result(output: source.path + "\n")
            },
            .failure(.destinationEmpty)
        )
    }

    func testMoveCurrentTrackCancelKeepsOriginal() throws {
        let source = try makeTempFile(named: "song.m4a")
        defer { cleanup(source) }
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("ApexKeyMove-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }

        let outcome = MediaEditing.moveCurrentTrack(
            destination: folder.path,
            confirm: { _ in false }
        ) { _, _ in
            self.result(output: source.path + "\n")
        }
        XCTAssertEqual(outcome, .failure(.cancelled))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }

    func testMoveCurrentTrackMovesFile() throws {
        let source = try makeTempFile(named: "song.m4a")
        defer { cleanup(source) }
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("ApexKeyMove-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }

        let outcome = MediaEditing.moveCurrentTrack(
            destination: folder.path,
            confirm: { _ in true }
        ) { _, _ in
            self.result(output: source.path + "\n")
        }

        let target = folder.appendingPathComponent("song.m4a")
        XCTAssertEqual(outcome, .success([target.path]))
        XCTAssertTrue(FileManager.default.fileExists(atPath: target.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
    }

    func testMoveCurrentTrackRefusesExistingTarget() throws {
        let source = try makeTempFile(named: "song.m4a")
        defer { cleanup(source) }
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("ApexKeyMove-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try Data().write(to: folder.appendingPathComponent("song.m4a"))

        XCTAssertEqual(
            MediaEditing.moveCurrentTrack(
                destination: folder.path,
                confirm: { _ in true }
            ) { _, _ in
                self.result(output: source.path + "\n")
            },
            .failure(.destinationExists("song.m4a"))
        )
    }

    // MARK: - 엔진 배선

    private func run(_ step: ShortcutStep) -> ExecutionEngine.Result {
        var context = UseModelExecutor.ExecutionContext()
        return ExecutionEngine.shared.execute(steps: [step], context: &context)
    }

    private func step(_ type: ActionType, _ config: MediaEditingConfig) -> ShortcutStep {
        ShortcutStep(type: type, target: "", title: "", actionParameters: config.encode())
    }

    /// 실제 카메라·음악·볼륨을 건드리지 않는 실패 경로만 엔진에 통과시킨다.
    func testMediaActionsAreWiredIntoEngine() {
        let unimplemented = "toast.reason.unimplemented".localized
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString).png").path

        let cases: [(ActionType, MediaEditingConfig)] = [
            (.rotateImage, MediaEditingConfig(path: "")),
            (.cropImage, MediaEditingConfig(path: missing)),
            (.trimVideo, MediaEditingConfig(path: "", endSeconds: 1)),
        ]

        for (type, config) in cases {
            let result = run(step(type, config))
            XCTAssertFalse(result.success, "\(type.rawValue) 는 잘못된 입력으로 실패해야 함")
            XCTAssertNotEqual(result.error, unimplemented, "\(type.rawValue) 가 엔진에 배선되지 않았다")
        }
    }
}

private extension Result {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
