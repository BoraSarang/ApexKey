import Foundation
import AppKit

/// 파일 액션 (T-213) — 가져오기·이동·이름 변경·압축 풀기·외부 저장소·파일 동작·첨부 가져오기
///
/// **안전 원칙**
/// - 사용자 데이터를 바꾸는 동작은 **미리보기 + 확인**을 거친다(`confirmBeforeChange`, 기본 켜짐).
///   확인 창은 주입 가능해서 자동화 테스트가 UI 없이 취소·승인 경로를 모두 검증한다.
/// - 충돌은 조용히 덮어쓰지 않는다. `overwrite`가 꺼져 있으면 실패로 알린다.
/// - 실패는 빈 결과로 뭉개지 않는다 — 없는 경로·권한·충돌을 구분해 사유를 돌려준다.
enum FileActions {

    typealias Confirmer = (String) -> Bool
    typealias OperationResult = Result<[URL], FailureReason>

    enum FailureReason: Equatable, Error {
        case emptyPath
        case notFound(String)
        case notDirectory(String)
        case noFiles(String)
        case conflict(String)
        case invalidName(String)
        case noChange
        case cancelled
        case archiveUnsupported(String)
        case noExternalVolume
        case mailNotRunning
        case mailDenied
        case noAttachments
        case operationFailed(String)

        /// 사용자에게 보여줄 문구 — 경로·이름처럼 가변 값은 포맷으로 넣는다
        var message: String {
            switch self {
            case .emptyPath: return "error.user.file_path_empty".localized
            case .notFound(let path): return "error.user.file_not_found".localizedFormat(path)
            case .notDirectory(let path): return "error.user.file_not_directory".localizedFormat(path)
            case .noFiles(let path): return "error.user.file_no_files".localizedFormat(path)
            case .conflict(let name): return "error.user.file_conflict".localizedFormat(name)
            case .invalidName(let name): return "error.user.file_name_invalid".localizedFormat(name)
            case .noChange: return "error.user.file_no_change".localized
            case .cancelled: return "error.user.file_cancelled".localized
            case .archiveUnsupported(let ext): return "error.user.file_archive_unsupported".localizedFormat(ext)
            case .noExternalVolume: return "error.user.file_no_volume".localized
            case .mailNotRunning: return "error.user.file_mail_not_running".localized
            case .mailDenied: return "error.user.file_mail_denied".localized
            case .noAttachments: return "error.user.file_no_attachments".localized
            case .operationFailed(let detail): return "error.user.file_operation_failed".localizedFormat(detail)
            }
        }
    }

    /// 기본 확인 창 — 취소를 실패로 만들지 않기 위해 결과를 `Bool`로 돌려준다
    static let defaultConfirmer: Confirmer = { message in
        UserPromptActions.confirmation(message: message)
    }

    // MARK: - 가져오기

    /// 폴더에서 파일 목록을 가져온다.
    ///
    /// - `path`가 파일이면 그 파일 하나를 돌려준다.
    /// - 폴더면 `recursive`에 따라 바로 아래 또는 하위 전체를 훑는다.
    /// - 패키지(.app 등) 내부는 내려가지 않는다 — 앱 번들 속 파일 수천 개가 목록을 덮는다.
    static func listFiles(
        path: String,
        recursive: Bool = false,
        includeHidden: Bool = false,
        extensions: String? = nil,
        fileManager: FileManager = .default
    ) -> OperationResult {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.emptyPath) }

        let url = URL(fileURLWithPath: expanded(trimmed))
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return .failure(.notFound(url.path))
        }
        if !isDirectory.boolValue {
            return matches(url, extensions: extensions) ? .success([url]) : .failure(.noFiles(url.path))
        }

        let filter = extensionSet(extensions)
        var results: [URL] = []

        if recursive {
            let keys: [URLResourceKey] = [.isRegularFileKey, .isHiddenKey]
            guard let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: keys,
                options: includeHidden ? [.skipsPackageDescendants] : [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                return .failure(.notFound(url.path))
            }
            for case let child as URL in enumerator {
                guard (try? child.resourceValues(forKeys: Set(keys)).isRegularFile) == true else { continue }
                if matches(child, filter: filter) { results.append(child) }
            }
        } else {
            guard let children = try? fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey, .isHiddenKey],
                options: includeHidden ? [.skipsPackageDescendants] : [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                return .failure(.notFound(url.path))
            }
            for child in children {
                guard (try? child.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
                if matches(child, filter: filter) { results.append(child) }
            }
        }

        let sorted = results.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
        guard !sorted.isEmpty else { return .failure(.noFiles(url.path)) }
        return .success(sorted)
    }

    // MARK: - 이동

    static func move(
        _ sourcePaths: [String],
        to destination: String,
        overwrite: Bool = false,
        createDestination: Bool = true,
        confirm: Confirmer = FileActions.defaultConfirmer,
        fileManager: FileManager = .default
    ) -> OperationResult {
        let sources: [URL]
        switch resolvedURLs(sourcePaths, fileManager: fileManager) {
        case .failure(let reason): return .failure(reason)
        case .success(let urls): sources = urls
        }

        let folder = URL(fileURLWithPath: expanded(destination.trimmingCharacters(in: .whitespacesAndNewlines)))
        guard !destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.emptyPath)
        }
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: folder.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue else { return .failure(.notDirectory(folder.path)) }
        } else if createDestination {
            do {
                try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            } catch {
                return .failure(.operationFailed(error.localizedDescription))
            }
        } else {
            return .failure(.notFound(folder.path))
        }

        if let conflict = firstConflict(sources, in: folder, fileManager: fileManager, overwrite: overwrite) {
            return .failure(.conflict(conflict))
        }
        guard confirmChange(
            title: "file.confirm.move".localizedFormat(sources.count, folder.path),
            sources: sources,
            confirm: confirm
        ) else {
            return .failure(.cancelled)
        }

        var moved: [URL] = []
        for source in sources {
            let target = folder.appendingPathComponent(source.lastPathComponent)
            do {
                if overwrite, fileManager.fileExists(atPath: target.path) {
                    try fileManager.removeItem(at: target)
                }
                try fileManager.moveItem(at: source, to: target)
                moved.append(target)
            } catch {
                return .failure(.operationFailed("\(source.lastPathComponent): \(error.localizedDescription)"))
            }
        }
        return .success(moved)
    }

    // MARK: - 이름 바꾸기

    /// 이름을 바꾼다. 확장자는 보존하고, 템플릿이 비면 찾기/바꾸기를 쓴다.
    ///
    /// 템플릿 토큰: `{name}`(확장자 제외 이름) `{index}` `{date}` `{ext}`(확장자, 점 없음).
    /// `{ext}`를 쓰지 않으면 원래 확장자를 자동으로 붙인다.
    static func rename(
        _ sourcePaths: [String],
        template: String?,
        find: String?,
        replace: String?,
        startNumber: Int = 1,
        overwrite: Bool = false,
        confirm: Confirmer = FileActions.defaultConfirmer,
        now: Date = Date(),
        fileManager: FileManager = .default
    ) -> OperationResult {
        let sources: [URL]
        switch resolvedURLs(sourcePaths, fileManager: fileManager) {
        case .failure(let reason): return .failure(reason)
        case .success(let urls): sources = urls
        }

        let dateText = NextActions.formatDate(now, format: "yyyyMMdd")
        var plan: [(source: URL, target: URL)] = []
        var seen = Set<String>()

        for (offset, source) in sources.enumerated() {
            let ext = source.pathExtension
            let base = source.deletingPathExtension().lastPathComponent
            let index = startNumber + offset

            let rawTemplate = (template ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let usesTemplate = !rawTemplate.isEmpty
            let usesExtensionToken = rawTemplate.contains("{ext}")

            var newBase: String
            if usesTemplate {
                newBase = rawTemplate
                    .replacingOccurrences(of: "{name}", with: base)
                    .replacingOccurrences(of: "{index}", with: String(index))
                    .replacingOccurrences(of: "{date}", with: dateText)
                    .replacingOccurrences(of: "{ext}", with: ext)
            } else {
                let findText = find ?? ""
                newBase = findText.isEmpty
                    ? base
                    : base.replacingOccurrences(of: findText, with: replace ?? "")
            }

            let newName = usesTemplate && usesExtensionToken
                ? newBase
                : (ext.isEmpty ? newBase : "\(newBase).\(ext)")

            guard !newName.isEmpty, !newName.contains("/"), !newName.contains(":") else {
                return .failure(.invalidName(newName))
            }

            let target = source.deletingLastPathComponent().appendingPathComponent(newName)
            if target.lastPathComponent != source.lastPathComponent {
                let key = target.path.lowercased()
                if seen.contains(key) || fileManager.fileExists(atPath: target.path) {
                    if !overwrite { return .failure(.conflict(newName)) }
                }
                seen.insert(key)
                plan.append((source, target))
            }
        }

        guard !plan.isEmpty else { return .failure(.noChange) }

        var preview = plan.map { "\($0.source.lastPathComponent) → \($0.target.lastPathComponent)" }
        if preview.count > 8 {
            preview = Array(preview.prefix(8)) + ["… +\(plan.count - 8)"]
        }
        let message = "file.confirm.rename".localizedFormat(plan.count)
            + "\n" + preview.joined(separator: "\n")
        guard confirm(message) else { return .failure(.cancelled) }

        var renamed: [URL] = []
        for item in plan {
            do {
                if overwrite, fileManager.fileExists(atPath: item.target.path) {
                    try fileManager.removeItem(at: item.target)
                }
                try fileManager.moveItem(at: item.source, to: item.target)
                renamed.append(item.target)
            } catch {
                return .failure(.operationFailed("\(item.source.lastPathComponent): \(error.localizedDescription)"))
            }
        }
        return .success(renamed)
    }

    // MARK: - 압축 풀기

    /// 압축을 푼다. zip은 `ditto`, tar 계열은 `/usr/bin/tar`를 쓴다.
    ///
    /// 셸을 거치지 않고 인자 배열로 실행하므로 경로에 공백·따옴표가 있어도 안전하다.
    static func extractArchive(
        archive: String,
        to destination: String?,
        fileManager: FileManager = .default
    ) -> OperationResult {
        let trimmed = archive.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.emptyPath) }

        let archiveURL = URL(fileURLWithPath: expanded(trimmed))
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: archiveURL.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            return .failure(.notFound(archiveURL.path))
        }

        let destinationRaw = (destination ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let folder = destinationRaw.isEmpty
            ? archiveURL.deletingLastPathComponent()
            : URL(fileURLWithPath: expanded(destinationRaw))

        var folderIsDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: folder.path, isDirectory: &folderIsDirectory) {
            guard folderIsDirectory.boolValue else { return .failure(.notDirectory(folder.path)) }
        } else {
            do {
                try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            } catch {
                return .failure(.operationFailed(error.localizedDescription))
            }
        }

        let name = archiveURL.lastPathComponent.lowercased()
        let run: ProcessRunner.Result
        if name.hasSuffix(".zip") {
            run = ProcessRunner.run(
                executable: "/usr/bin/ditto",
                arguments: ["-x", "-k", archiveURL.path, folder.path],
                timeout: 300
            )
        } else if name.hasSuffix(".tar") || name.hasSuffix(".tar.gz") || name.hasSuffix(".tgz")
            || name.hasSuffix(".tar.bz2") || name.hasSuffix(".tbz2")
            || name.hasSuffix(".tar.xz") || name.hasSuffix(".txz") {
            run = ProcessRunner.run(
                executable: "/usr/bin/tar",
                arguments: ["-xf", archiveURL.path, "-C", folder.path],
                timeout: 300
            )
        } else {
            return .failure(.archiveUnsupported(archiveURL.pathExtension))
        }

        guard run.succeeded else {
            let detail = run.timedOut
                ? "timeout"
                : (run.standardError.isEmpty ? "exit \(run.exitCode)" : run.standardError)
            return .failure(.operationFailed(String(detail.prefix(200))))
        }
        return .success([folder])
    }

    // MARK: - 외부 저장소

    /// 마운트된 외부 볼륨 — 내장 디스크가 아니고 로컬인 것
    static func externalVolumes(
        fileManager: FileManager = .default
    ) -> [URL] {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeIsInternalKey, .volumeIsLocalKey]
        let urls = fileManager.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) ?? []
        return urls.filter { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return false }
            return values.volumeIsInternal == false && values.volumeIsLocal == true
        }.sorted {
            ($0.lastPathComponent).localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
    }

    /// 이름으로 볼륨을 고른다 — 순수 함수라 시스템 없이 테스트한다
    static func selectVolume(named name: String?, from volumes: [URL]) -> URL? {
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return volumes.count == 1 ? volumes[0] : nil
        }
        return volumes.first {
            let volumeName = (try? $0.resourceValues(forKeys: [.volumeNameKey]))?.volumeName
            return $0.lastPathComponent == trimmed || volumeName == trimmed
        }
    }

    /// 파일을 외부 볼륨으로 복사한다. `subpath`가 비면 볼륨 루트에 원래 이름으로 둔다.
    static func saveToExternalStorage(
        _ sourcePaths: [String],
        volumeName: String?,
        subpath: String?,
        overwrite: Bool = false,
        confirm: Confirmer = FileActions.defaultConfirmer,
        fileManager: FileManager = .default
    ) -> OperationResult {
        let volumes = externalVolumes(fileManager: fileManager)
        guard let volume = selectVolume(named: volumeName, from: volumes) else {
            return .failure(.noExternalVolume)
        }
        let sources: [URL]
        switch resolvedURLs(sourcePaths, fileManager: fileManager) {
        case .failure(let reason): return .failure(reason)
        case .success(let urls): sources = urls
        }

        let sub = (subpath ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let folder = sub.isEmpty
            ? volume
            : volume.appendingPathComponent(sub, isDirectory: true)
        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            return .failure(.operationFailed(error.localizedDescription))
        }
        if let conflict = firstConflict(sources, in: folder, fileManager: fileManager, overwrite: overwrite) {
            return .failure(.conflict(conflict))
        }
        let message = "file.confirm.copy".localizedFormat(sources.count, folder.path)
        guard confirmChange(title: message, sources: sources, confirm: confirm) else {
            return .failure(.cancelled)
        }

        var copied: [URL] = []
        for source in sources {
            let target = folder.appendingPathComponent(source.lastPathComponent)
            do {
                if overwrite, fileManager.fileExists(atPath: target.path) {
                    try fileManager.removeItem(at: target)
                }
                try fileManager.copyItem(at: source, to: target)
                copied.append(target)
            } catch {
                return .failure(.operationFailed("\(source.lastPathComponent): \(error.localizedDescription)"))
            }
        }
        return .success(copied)
    }

    // MARK: - 파일 동작

    static func perform(
        operation: FileActionConfig.Operation,
        sourcePaths: [String],
        destination: String?,
        overwrite: Bool = false,
        confirm: Confirmer = FileActions.defaultConfirmer,
        fileManager: FileManager = .default
    ) -> OperationResult {
        let sources: [URL]
        switch resolvedURLs(sourcePaths, fileManager: fileManager) {
        case .failure(let reason): return .failure(reason)
        case .success(let urls): sources = urls
        }

        switch operation {
        case .move:
            let target = (destination ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !target.isEmpty else { return .failure(.emptyPath) }
            return move(sourcePaths, to: target, overwrite: overwrite, confirm: confirm, fileManager: fileManager)

        case .copy:
            let target = (destination ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !target.isEmpty else { return .failure(.emptyPath) }
            let folder = URL(fileURLWithPath: expanded(target))
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: folder.path, isDirectory: &isDirectory) {
                guard isDirectory.boolValue else { return .failure(.notDirectory(folder.path)) }
            } else {
                do {
                    try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
                } catch {
                    return .failure(.operationFailed(error.localizedDescription))
                }
            }
            if let conflict = firstConflict(sources, in: folder, fileManager: fileManager, overwrite: overwrite) {
                return .failure(.conflict(conflict))
            }
            let message = "file.confirm.copy".localizedFormat(sources.count, folder.path)
            guard confirmChange(title: message, sources: sources, confirm: confirm) else {
                return .failure(.cancelled)
            }
            var copied: [URL] = []
            for source in sources {
                let target = folder.appendingPathComponent(source.lastPathComponent)
                do {
                    if overwrite, fileManager.fileExists(atPath: target.path) {
                        try fileManager.removeItem(at: target)
                    }
                    try fileManager.copyItem(at: source, to: target)
                    copied.append(target)
                } catch {
                    return .failure(.operationFailed("\(source.lastPathComponent): \(error.localizedDescription)"))
                }
            }
            return .success(copied)

        case .duplicate:
            let message = "file.confirm.duplicate".localizedFormat(sources.count)
            guard confirmChange(title: message, sources: sources, confirm: confirm) else {
                return .failure(.cancelled)
            }
            var duplicated: [URL] = []
            for source in sources {
                let target = availableCopyURL(for: source, fileManager: fileManager)
                do {
                    try fileManager.copyItem(at: source, to: target)
                    duplicated.append(target)
                } catch {
                    return .failure(.operationFailed("\(source.lastPathComponent): \(error.localizedDescription)"))
                }
            }
            return .success(duplicated)

        case .trash:
            let message = "file.confirm.trash".localizedFormat(sources.count) + "\n"
                + sources.map(\.lastPathComponent).joined(separator: "\n")
            guard confirm(message) else { return .failure(.cancelled) }

            let semaphore = DispatchSemaphore(value: 0)
            var recycled: [URL] = []
            var recycleError: Error?
            NSWorkspace.shared.recycle(sources) { mapping, error in
                recycled = Array(mapping.values)
                recycleError = error
                semaphore.signal()
            }
            guard semaphore.wait(timeout: .now() + 15) == .success else {
                return .failure(.operationFailed("trash timeout"))
            }
            if let recycleError {
                return .failure(.operationFailed(recycleError.localizedDescription))
            }
            return .success(recycled)

        case .reveal:
            // 테스트에서는 Finder를 실제로 띄우지 않는다 (다른 입력 액션과 같은 규칙)
            if !KeySender.suppressesPublish {
                NSWorkspace.shared.activateFileViewerSelecting(sources)
            }
            return .success(sources)
        }
    }

    // MARK: - 메일 첨부

    /// Mail에서 **선택한 메시지**의 첨부 파일을 폴더에 저장한다.
    ///
    /// Mail이 실행 중이 아니면 실행하지 않는다 — 첨부 하나 가져오려고 메일 앱을
    /// 띄우는 것은 사용자가 기대하지 않는 부작용이다.
    static func mailAttachments(
        to folder: String?,
        fileManager: FileManager = .default
    ) -> OperationResult {
        let running = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.apple.mail"
        }
        guard running else { return .failure(.mailNotRunning) }

        let raw = (folder ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let directory = raw.isEmpty
            ? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
            : URL(fileURLWithPath: expanded(raw))
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            return .failure(.operationFailed(error.localizedDescription))
        }

        let script = """
        on run argv
            set outFolder to item 1 of argv
            tell application "Mail"
                set msgs to selection
                if (count of msgs) is 0 then error "no selected messages" number 9001
                set out to ""
                repeat with m in msgs
                    repeat with a in mail attachments of m
                        set p to outFolder & "/" & (name of a)
                        save a in (POSIX file p)
                        set out to out & p & linefeed
                    end repeat
                end repeat
                return out
            end tell
        end run
        """

        let run = ProcessRunner.run(
            executable: "/usr/bin/osascript",
            arguments: ["-e", script, directory.path],
            timeout: 60
        )
        guard run.succeeded else {
            let detail = run.standardError
            if detail.contains("-1743") || detail.contains("Not authorized")
                || detail.contains("not allowed") || detail.contains("automation") {
                return .failure(.mailDenied)
            }
            if detail.contains("9001") {
                return .failure(.noAttachments)
            }
            return .failure(.operationFailed(String(detail.prefix(200))))
        }

        let urls = parseAttachmentPaths(run.standardOutput)
        guard !urls.isEmpty else { return .failure(.noAttachments) }
        return .success(urls)
    }

    /// osascript stdout(줄바꿈 구분 경로)을 URL로 바꾼다 — 순수 함수
    static func parseAttachmentPaths(_ output: String) -> [URL] {
        output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { URL(fileURLWithPath: expanded($0)) }
    }

    // MARK: - 내부

    static func expanded(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }

    /// 입력 텍스트를 실제 존재하는 URL 목록으로 바꾼다 (중복 제거)
    static func resolvedURLs(
        _ sourcePaths: [String],
        fileManager: FileManager = .default
    ) -> OperationResult {
        let trimmed = sourcePaths
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !trimmed.isEmpty else { return .failure(.emptyPath) }

        var seen = Set<String>()
        var urls: [URL] = []
        for path in trimmed {
            let url = URL(fileURLWithPath: expanded(path))
            guard fileManager.fileExists(atPath: url.path) else {
                return .failure(.notFound(url.path))
            }
            if seen.insert(url.path).inserted { urls.append(url) }
        }
        return .success(urls)
    }

    private static func firstConflict(
        _ sources: [URL],
        in folder: URL,
        fileManager: FileManager,
        overwrite: Bool
    ) -> String? {
        guard !overwrite else { return nil }
        for source in sources {
            let target = folder.appendingPathComponent(source.lastPathComponent)
            if fileManager.fileExists(atPath: target.path) {
                return target.lastPathComponent
            }
        }
        return nil
    }

    private static func confirmChange(
        title: String,
        sources: [URL],
        confirm: Confirmer
    ) -> Bool {
        let names = sources.prefix(8).map(\.lastPathComponent)
        var message = title + "\n" + names.joined(separator: "\n")
        if sources.count > names.count {
            message += "\n… +\(sources.count - names.count)"
        }
        return confirm(message)
    }

    private static func availableCopyURL(
        for source: URL,
        fileManager: FileManager
    ) -> URL {
        let folder = source.deletingLastPathComponent()
        let ext = source.pathExtension
        let base = source.deletingPathExtension().lastPathComponent
        var index = 1
        while true {
            let suffix = index == 1 ? " copy" : " copy \(index)"
            let name = ext.isEmpty ? "\(base)\(suffix)" : "\(base)\(suffix).\(ext)"
            let candidate = folder.appendingPathComponent(name)
            if !fileManager.fileExists(atPath: candidate.path) { return candidate }
            index += 1
        }
    }

    private static func extensionSet(_ text: String?) -> Set<String> {
        let raw = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return [] }
        let parts = raw
            .split(whereSeparator: { $0 == "," || $0 == ";" || $0 == " " })
            .map { String($0).trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased() }
            .filter { !$0.isEmpty }
        return Set(parts)
    }

    private static func matches(_ url: URL, extensions: String?) -> Bool {
        matches(url, filter: extensionSet(extensions))
    }

    private static func matches(_ url: URL, filter: Set<String>) -> Bool {
        filter.isEmpty || filter.contains(url.pathExtension.lowercased())
    }
}
