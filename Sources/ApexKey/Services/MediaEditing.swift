import AppKit
import CoreImage
import Foundation

/// 미디어 편집·캡처 — 이미지 회전/자르기, 비디오 자르기, 카메라, 볼륨, 음악 (T-220)
///
/// **원본 보존**: 이미지·비디오 편집은 원본을 덮어쓰지 않는다. 출력 경로를 비우면
/// `이름-rotated.png`처럼 파생 이름을 만들고, 원본과 같은 경로가 지정되면 거부한다.
///
/// **공개 경로**: 비디오 자르기는 `/usr/bin/avconvert`(macOS 기본), 이미지 편집은
/// CoreImage, 볼륨은 CoreAudio(`SystemVolume`), 음악 제어는 AppleScript를 쓴다.
/// 외부 실행·이미지 입출력은 주입 가능해 테스트가 실제 파일·앱을 건드리지 않는다.
enum MediaEditing {

    typealias Runner = (_ executable: String, _ arguments: [String]) -> ProcessRunner.Result
    typealias Confirmer = (String) -> Bool
    typealias ImageLoader = (URL) -> CIImage?
    typealias ImageWriter = (CIImage, URL) -> Bool
    typealias Capture = (URL) -> Result<Void, CameraCapture.Failure>
    typealias VolumeSetter = (Float) -> Bool
    typealias Outcome = Result<[String], FailureReason>

    static let avconvertPath = "/usr/bin/avconvert"

    static let defaultRunner: Runner = { executable, arguments in
        ProcessRunner.run(executable: executable, arguments: arguments, timeout: 300)
    }

    static let defaultConfirmer: Confirmer = { message in
        UserPromptActions.confirmation(message: message)
    }

    static let defaultLoader: ImageLoader = { CIImage(contentsOf: $0) }

    static let defaultWriter: ImageWriter = { image, url in
        guard let cgImage = CIContext().createCGImage(image, from: image.extent) else {
            return false
        }
        let representation = NSBitmapImageRep(cgImage: cgImage)
        let ext = url.pathExtension.lowercased()
        let type: NSBitmapImageRep.FileType
        switch ext {
        case "jpg", "jpeg": type = .jpeg
        case "tiff", "tif": type = .tiff
        default: type = .png
        }
        guard let data = representation.representation(using: type, properties: [:]) else {
            return false
        }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    static let defaultCapture: Capture = { url in
        CameraCapture.capture(to: url)
    }

    static let defaultVolumeSetter: VolumeSetter = { SystemVolume.set($0) }

    enum FailureReason: Equatable, Error {
        case emptyPath
        case fileNotFound(String)
        case unsupportedImage(String)
        case invalidAngle
        case invalidCrop
        case invalidRange
        case samePath
        case writeFailed(String)
        case exportFailed(String)
        case destinationEmpty
        case destinationMissing(String)
        case destinationExists(String)
        case noCurrentTrack
        case nothingPlaying
        case musicNotRunning
        case cancelled
        case volumeUnavailable
        case cameraDenied
        case cameraUnavailable
        case cameraFailed(String)
        case automationDenied
        case scriptFailed(String)

        var message: String {
            switch self {
            case .emptyPath: return "error.user.media_path_empty".localized
            case .fileNotFound(let path): return "error.user.media_file_not_found".localizedFormat(path)
            case .unsupportedImage(let path): return "error.user.media_unsupported_image".localizedFormat(path)
            case .invalidAngle: return "error.user.media_invalid_angle".localized
            case .invalidCrop: return "error.user.media_invalid_crop".localized
            case .invalidRange: return "error.user.media_invalid_range".localized
            case .samePath: return "error.user.media_same_path".localized
            case .writeFailed(let path): return "error.user.media_write_failed".localizedFormat(path)
            case .exportFailed(let detail): return "error.user.media_export_failed".localizedFormat(detail)
            case .destinationEmpty: return "error.user.media_destination_empty".localized
            case .destinationMissing(let path): return "error.user.media_destination_missing".localizedFormat(path)
            case .destinationExists(let name): return "error.user.media_destination_exists".localizedFormat(name)
            case .noCurrentTrack: return "error.user.media_no_current_track".localized
            case .nothingPlaying: return "error.user.media_nothing_playing".localized
            case .musicNotRunning: return "error.user.media_music_not_running".localized
            case .cancelled: return "error.user.media_cancelled".localized
            case .volumeUnavailable: return "error.user.media_volume_unavailable".localized
            case .cameraDenied: return "error.user.media_camera_denied".localized
            case .cameraUnavailable: return "error.user.media_camera_unavailable".localized
            case .cameraFailed(let detail): return "error.user.media_camera_failed".localizedFormat(detail)
            case .automationDenied: return "error.user.apple_denied".localized
            case .scriptFailed(let detail): return "error.user.apple_failed".localizedFormat(detail)
            }
        }
    }

    // MARK: - 이미지

    static func rotateImage(
        path: String,
        outputPath: String,
        angleDegrees: Double,
        fileManager: FileManager = .default,
        loader: ImageLoader = defaultLoader,
        writer: ImageWriter = defaultWriter
    ) -> Outcome {
        guard let input = existingFile(path, fileManager: fileManager) else {
            return .failure(path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? .emptyPath
                : .fileNotFound(expanded(path)))
        }

        let normalized = angleDegrees.truncatingRemainder(dividingBy: 360)
        guard abs(normalized) >= 0.01 else { return .failure(.invalidAngle) }

        let output = resolvedOutput(outputPath, input: input, suffix: "rotated", fileManager: fileManager)
        guard output.standardizedFileURL != input.standardizedFileURL else {
            return .failure(.samePath)
        }
        guard let image = loader(input) else { return .failure(.unsupportedImage(input.path)) }

        let rotated = rotate(image, degrees: normalized)
        guard writer(rotated, output) else { return .failure(.writeFailed(output.path)) }
        return .success([output.path])
    }

    static func cropImage(
        path: String,
        outputPath: String,
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        fileManager: FileManager = .default,
        loader: ImageLoader = defaultLoader,
        writer: ImageWriter = defaultWriter
    ) -> Outcome {
        guard let input = existingFile(path, fileManager: fileManager) else {
            return .failure(path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? .emptyPath
                : .fileNotFound(expanded(path)))
        }
        guard width > 0, height > 0 else { return .failure(.invalidCrop) }
        guard let image = loader(input) else { return .failure(.unsupportedImage(input.path)) }

        // 사용자 좌표는 이미지의 왼쪽 위 기준이다. CIImage는 왼쪽 아래 기준이라 y를 뒤집는다.
        let extent = image.extent
        let rect = CGRect(
            x: extent.minX + x,
            y: extent.maxY - y - height,
            width: width,
            height: height
        )
        guard rect.width > 0, rect.height > 0,
              rect.minX >= extent.minX - 0.5,
              rect.minY >= extent.minY - 0.5,
              rect.maxX <= extent.maxX + 0.5,
              rect.maxY <= extent.maxY + 0.5 else {
            return .failure(.invalidCrop)
        }

        let output = resolvedOutput(outputPath, input: input, suffix: "cropped", fileManager: fileManager)
        guard output.standardizedFileURL != input.standardizedFileURL else {
            return .failure(.samePath)
        }

        let cropped = crop(image, rect: rect)
        guard writer(cropped, output) else { return .failure(.writeFailed(output.path)) }
        return .success([output.path])
    }

    /// 이미지 회전 후 음수 원점을 0으로 옮긴다 (출력 extent가 0에서 시작하도록).
    static func rotate(_ image: CIImage, degrees: Double) -> CIImage {
        let radians = degrees * .pi / 180
        let transformed = image.transformed(by: CGAffineTransform(rotationAngle: radians))
        let extent = transformed.extent
        return transformed.transformed(
            by: CGAffineTransform(translationX: -extent.origin.x, y: -extent.origin.y)
        )
    }

    /// 자른 이미지의 원점을 0으로 옮긴다.
    static func crop(_ image: CIImage, rect: CGRect) -> CIImage {
        image.cropped(to: rect).transformed(
            by: CGAffineTransform(translationX: -rect.origin.x, y: -rect.origin.y)
        )
    }

    // MARK: - 비디오

    static func trimVideo(
        path: String,
        outputPath: String,
        startSeconds: Double,
        endSeconds: Double,
        fileManager: FileManager = .default,
        runner: Runner = defaultRunner
    ) -> Outcome {
        guard let input = existingFile(path, fileManager: fileManager) else {
            return .failure(path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? .emptyPath
                : .fileNotFound(expanded(path)))
        }
        guard startSeconds >= 0, endSeconds > startSeconds else {
            return .failure(.invalidRange)
        }

        let output = resolvedOutput(outputPath, input: input, suffix: "trimmed", fileManager: fileManager)
        guard output.standardizedFileURL != input.standardizedFileURL else {
            return .failure(.samePath)
        }

        let duration = endSeconds - startSeconds
        let result = runner(avconvertPath, [
            "--source", input.path,
            "--output", output.path,
            "--preset", "PresetHighestQuality",
            "--start", trimmedNumber(startSeconds),
            "--duration", trimmedNumber(duration),
            "--replace",
        ])
        guard result.succeeded else { return .failure(.exportFailed(detail(result))) }
        guard fileManager.fileExists(atPath: output.path) else {
            return .failure(.exportFailed("output was not created"))
        }
        return .success([output.path])
    }

    // MARK: - 카메라

    static func capturePhoto(
        outputPath: String,
        fileManager: FileManager = .default,
        capture: Capture = defaultCapture
    ) -> Outcome {
        let destination = photoDestination(outputPath, fileManager: fileManager)
        do {
            try fileManager.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            return .failure(.writeFailed(destination.deletingLastPathComponent().path))
        }

        switch capture(destination) {
        case .success:
            return .success([destination.path])
        case .failure(.denied):
            return .failure(.cameraDenied)
        case .failure(.unavailable):
            return .failure(.cameraUnavailable)
        case .failure(.failed(let detail)):
            return .failure(.cameraFailed(detail))
        }
    }

    /// 출력 경로가 폴더면 파일 이름을 붙이고, 비어 있으면 사진 폴더를 쓴다.
    static func photoDestination(_ path: String, fileManager: FileManager = .default) -> URL {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return picturesDirectory(fileManager: fileManager)
                .appendingPathComponent(photoName)
        }
        let url = URL(fileURLWithPath: expanded(trimmed))
        let ext = url.pathExtension.lowercased()
        if ["jpg", "jpeg", "png", "heic"].contains(ext) {
            return url.standardizedFileURL
        }
        return url.appendingPathComponent(photoName)
    }

    // MARK: - 볼륨

    static func setVolume(
        percent: Int,
        setter: VolumeSetter = defaultVolumeSetter
    ) -> Outcome {
        let clamped = min(max(percent, 0), 100)
        guard setter(Float(clamped) / 100) else {
            return .failure(.volumeUnavailable)
        }
        return .success(["\(clamped)%"])
    }

    // MARK: - 음악

    static func music(
        command: MediaEditingConfig.PlaybackCommand,
        runner: Runner = AppleApps.defaultRunner
    ) -> Outcome {
        let result = runner(scripts.music(command), [])
        if result.succeeded { return .success([command.displayName]) }
        return .failure(classify(result))
    }

    /// 현재 재생 중인 곡의 파일 경로를 읽는다.
    static func currentTrackPath(
        runner: Runner = AppleApps.defaultRunner
    ) -> Result<String, FailureReason> {
        let result = runner(scripts.currentTrack, [])
        guard result.succeeded else { return .failure(classify(result)) }
        let lines = AppleApps.parseLines(result.standardOutput)
        guard let path = lines.first, !path.isEmpty else {
            return .failure(.noCurrentTrack)
        }
        return .success(path)
    }

    /// 현재 재생 중인 곡 파일을 대상 폴더로 옮긴다.
    static func moveCurrentTrack(
        destination: String,
        confirmBeforeChange: Bool = true,
        confirm: Confirmer = defaultConfirmer,
        fileManager: FileManager = .default,
        runner: Runner = AppleApps.defaultRunner
    ) -> Outcome {
        let sourcePath: String
        switch currentTrackPath(runner: runner) {
        case .failure(let reason): return .failure(reason)
        case .success(let path): sourcePath = path
        }

        let source = URL(fileURLWithPath: sourcePath).standardizedFileURL
        guard fileManager.fileExists(atPath: source.path) else {
            return .failure(.noCurrentTrack)
        }

        let trimmed = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.destinationEmpty) }

        let folder = URL(fileURLWithPath: expanded(trimmed)).standardizedFileURL
        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            return .failure(.destinationMissing(folder.path))
        }
        guard fileManager.fileExists(atPath: folder.path) else {
            return .failure(.destinationMissing(folder.path))
        }

        if confirmBeforeChange {
            let message = "media.confirm.move".localizedFormat(source.lastPathComponent, folder.path)
            guard confirm(message) else { return .failure(.cancelled) }
        }

        let target = folder.appendingPathComponent(source.lastPathComponent)
        guard target.standardizedFileURL != source.standardizedFileURL else {
            return .success([source.path])
        }
        if fileManager.fileExists(atPath: target.path) {
            return .failure(.destinationExists(target.lastPathComponent))
        }

        do {
            try fileManager.moveItem(at: source, to: target)
            return .success([target.path])
        } catch {
            return .failure(.writeFailed(error.localizedDescription))
        }
    }

    // MARK: - 스크립트

    enum scripts {
        static func music(_ command: MediaEditingConfig.PlaybackCommand) -> String {
            let body: String
            switch command {
            case .play: body = "play"
            case .pause: body = "pause"
            case .playPause: body = "playpause"
            case .next: body = "next track"
            case .previous: body = "previous track"
            case .stop: body = "stop"
            }

            let requiresRunning = command != .play
            let guardLine = requiresRunning
                ? "if application \"Music\" is not running then error \"APEX_MUSIC_NOT_RUNNING\"\n"
                : ""
            return """
            \(guardLine)tell application "Music"
                \(body)
            end tell
            """
        }

        static let currentTrack = """
        if application "Music" is not running then error "APEX_MUSIC_NOT_RUNNING"
        tell application "Music"
            if player state is stopped then error "APEX_NOTHING_PLAYING"
            try
                set trackLocation to location of current track
            on error
                error "APEX_NO_FILE"
            end try
            return POSIX path of trackLocation
        end tell
        """
    }

    // MARK: - 공통

    static func expanded(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath)
            .standardizedFileURL
            .path
    }

    private static func existingFile(_ path: String, fileManager: FileManager) -> URL? {
        let expandedPath = expanded(path)
        guard !expandedPath.isEmpty else { return nil }
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: expandedPath, isDirectory: &isDirectory),
              !isDirectory.boolValue else { return nil }
        return URL(fileURLWithPath: expandedPath)
    }

    private static func resolvedOutput(
        _ outputPath: String,
        input: URL,
        suffix: String,
        fileManager: FileManager
    ) -> URL {
        let trimmed = outputPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let url = URL(fileURLWithPath: expanded(trimmed))
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                return url.appendingPathComponent(derivedName(input: input, suffix: suffix))
            }
            return url.standardizedFileURL
        }
        return input.deletingLastPathComponent()
            .appendingPathComponent(derivedName(input: input, suffix: suffix))
    }

    private static func derivedName(input: URL, suffix: String) -> String {
        let base = input.deletingPathExtension().lastPathComponent
        let ext = input.pathExtension.isEmpty ? "png" : input.pathExtension
        return "\(base)-\(suffix).\(ext)"
    }

    private static func picturesDirectory(fileManager: FileManager) -> URL {
        fileManager.urls(for: .picturesDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
    }

    private static var photoName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "ApexKey-\(formatter.string(from: Date())).jpg"
    }

    private static func trimmedNumber(_ value: Double) -> String {
        String(format: "%.3f", value)
    }

    private static func detail(_ result: ProcessRunner.Result) -> String {
        if result.timedOut { return "timeout" }
        if let launchError = result.launchError { return launchError }
        let error = result.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
        if !error.isEmpty { return String(error.prefix(200)) }
        let output = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !output.isEmpty { return String(output.prefix(200)) }
        return "exit \(result.exitCode)"
    }

    private static func classify(_ result: ProcessRunner.Result) -> FailureReason {
        let text = result.standardError + " " + result.standardOutput
        if text.contains("APEX_MUSIC_NOT_RUNNING") { return .musicNotRunning }
        if text.contains("APEX_NOTHING_PLAYING") { return .nothingPlaying }
        if text.contains("APEX_NO_FILE") { return .noCurrentTrack }
        if AppleApps.isAutomationDenied(text) { return .automationDenied }
        if result.timedOut { return .scriptFailed("timeout") }
        return .scriptFailed(detail(result))
    }
}
