import AppKit

/// Finder에서 "지금 열어야 할 폴더"를 읽는다 (T-195).
///
/// **왜 AX(접근성)가 아니라 AppleScript인가 — 2026-10-17 실측**:
/// 이 macOS의 Finder 창은 현재 폴더를 AX로 노출하지 않는다.
/// - 창의 `AXDocument` → `kAXErrorNoValue(-25212)` (값 자체가 없음)
/// - 목록 행/셀 → `AXURL`·`AXDocument`·`AXFilename` **속성 자체가 없음**
/// - 얻을 수 있는 것은 폴더 **표시 이름**(`AXTitle` = "Files")과 파일 이름뿐 → 절대 경로 불가
///
/// 따라서 Finder가 공식 제공하는 AppleScript(`target of front window` = 현재 폴더,
/// `selection` = 선택 항목)를 쓴다. 대가는 **자동화(TCC Apple Events) 권한 1회 승인**이다.
/// 거부되면 `-1743`(`errAEEventNotPermitted`)이 오고 우리는 그 사유를 사용자 문구로 표면화한다
/// (무음 실패 금지). 권한이 없다고 AX로 몰래 넘어가지 않는다 — 그 경로는 실측으로 불가능하다.
enum FinderPathProvider {
    static let finderBundleID = "com.apple.finder"

    /// 실패 사유 — 호출부가 사용자 문구를 고른다
    enum Failure: Equatable {
        /// 자동화 권한 거부 (`-1743`) — 시스템 설정에서 허용해야 한다
        case automationDenied
        /// Finder 미실행 / 전면 창 없음 / 현재 폴더를 못 읽음
        case notFound
    }

    struct Outcome {
        var folder: URL?
        var failure: Failure?
    }

    /// AppleScript가 거부를 알리는 표식 (스크립트 내부 `try`가 잡는다)
    static let deniedSentinel = "--APEXKEY-AUTOMATION-DENIED--"

    /// 항목 구분자 — 경로에 `\n`이 들어갈 수 있으므로 NUL(`ASCII character 0`)을 쓴다
    static let separator: Character = "\u{0}"

    /// 열 폴더 — **선택 우선, 없으면 현재 창 폴더**.
    static func resolveFolder() -> Outcome {
        let read = readFinder()
        if let failure = read.failure { return Outcome(folder: nil, failure: failure) }

        let folder = resolveFolder(selection: read.selection, currentFolder: read.currentFolder)
        guard let folder else {
            Logger.error("E-MAC-TERM-8102", "Finder에서 폴더를 찾을 수 없습니다 (선택 \(read.selection.count)건)")
            return Outcome(folder: nil, failure: .notFound)
        }
        Logger.info("FEATURE", "터미널에서 열기 대상: \(folder.path) (선택 \(read.selection.count)건)")
        return Outcome(folder: folder, failure: nil)
    }

    // MARK: - 순수 로직 (테스트 대상)

    /// 선택 우선 → 현재 폴더 규칙.
    ///
    /// - 선택에 **폴더가 있으면 그 폴더**(첫 번째). 파일만 골랐으면 그 파일의 **상위 폴더**.
    /// - 선택이 없으면 현재 창이 보고 있는 폴더.
    static func resolveFolder(
        selection: [URL],
        currentFolder: URL?,
        isDirectory: (URL) -> Bool = FinderPathProvider.defaultIsDirectory
    ) -> URL? {
        if let directory = selection.first(where: isDirectory) { return directory }
        if let first = selection.first { return first.deletingLastPathComponent() }
        return currentFolder
    }

    static func defaultIsDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }

    /// AppleScript 출력 파싱 — `현재폴더 NUL 선택1 NUL 선택2 …` (순수 함수).
    ///
    /// 빈 조각은 버린다. 경로가 아닌 조각(빈 문자열)은 자연히 걸러지고, 최종 존재 확인은
    /// `resolveFolder`가 `isDirectory`로 한다.
    struct AppleScriptRead: Equatable {
        var currentFolder: URL?
        var selection: [URL]
    }

    static func parseAppleScriptOutput(_ output: String) -> AppleScriptRead {
        let parts = output.split(separator: separator, omittingEmptySubsequences: false).map(String.init)
        let current = parts.first.flatMap(fileURL(fromScriptPath:))
        let selection = parts.dropFirst().compactMap(fileURL(fromScriptPath:))
        return AppleScriptRead(currentFolder: current, selection: selection)
    }

    /// AppleScript `POSIX path of`는 폴더에 끝 슬래시를 붙인다 (`/Users/lee/Documents/Files/`).
    /// 표준화해 두어야 표시·비교가 안정적이다.
    private static func fileURL(fromScriptPath path: String) -> URL? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(fileURLWithPath: trimmed).standardizedFileURL
    }

    // MARK: - Finder 읽기

    private struct FinderRead {
        var currentFolder: URL?
        var selection: [URL] = []
        var failure: Failure?
    }

    /// AppleScript 본문 — 문자열 보간이 없다(스크립트가 전부 정적이라 인용 위험도 없다).
    static let script = """
    set sep to (ASCII character 0)
    tell application "Finder"
        set out to ""
        try
            set out to POSIX path of ((target of front window) as alias)
        on error errMsg number errNum
            if errNum is -1743 then return "\(deniedSentinel)"
        end try
        set out to out & sep
        try
            repeat with anItem in (selection as alias list)
                try
                    set out to out & (POSIX path of anItem) & sep
                end try
            end repeat
        end try
        return out
    end tell
    """

    private static func readFinder() -> FinderRead {
        // Finder가 없으면 `tell application "Finder"`가 **Finder를 실행**한다 — 먼저 막는다
        guard !NSRunningApplication
            .runningApplications(withBundleIdentifier: finderBundleID).isEmpty else {
            Logger.error("E-MAC-TERM-8102", "Finder가 실행 중이 아닙니다")
            return FinderRead(failure: .notFound)
        }

        let result = ScriptExecutor.runAppleScript(script)
        if result.output == deniedSentinel {
            Logger.error("E-MAC-TERM-8101", "Finder 자동화 권한이 없습니다 (-1743) — 시스템 설정에서 허용 필요")
            return FinderRead(failure: .automationDenied)
        }
        guard result.success else {
            Logger.error("E-MAC-TERM-8102", "Finder AppleScript 실패: \(result.errorOutput.prefix(200))")
            return FinderRead(failure: .notFound)
        }

        let parsed = parseAppleScriptOutput(result.output)
        guard parsed.currentFolder != nil || !parsed.selection.isEmpty else {
            Logger.error("E-MAC-TERM-8102", "Finder 전면 창에서 현재 폴더를 읽지 못했습니다")
            return FinderRead(failure: .notFound)
        }
        return FinderRead(currentFolder: parsed.currentFolder, selection: parsed.selection)
    }
}
