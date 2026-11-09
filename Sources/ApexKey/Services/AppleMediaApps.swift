import Foundation
import AppKit

/// Apple 앱 연동 2 — Mail·Music·Podcasts·Photos (T-215)
///
/// **스파이크 실측(2026-11-09)**
/// - Mail·Music·Photos는 스크립팅 사전(`sdef`)이 있다. Photos는 `media item`·
///   `export`·`spotlight`·`album`을 제공하므로 최근 사진·내보내기·앨범을 구현할 수 있다.
/// - **Podcasts는 `sdef`가 없다**(-192). AppleScript로 검색·재생을 할 수 없어
///   URL scheme(`podcasts://`·`podcast://`·`pcast://`)만 지원한다. 검색어 재생은
///   불가능하다고 **정직하게 실패**시키고 URL을 넣도록 안내한다.
///
/// **안전 원칙**
/// - 메일은 기본이 **초안 열기**다. `sendImmediately`가 명시적으로 켜졌을 때만 `send`한다.
/// - 테스트는 실행기와 URL 열기 클로저를 주입해 실제 앱·권한·발송 없이 검증한다.
enum AppleMediaApps {

    typealias Runner = AppleApps.Runner
    typealias Opener = (URL) -> Bool

    enum FailureReason: Equatable, Error {
        case invalidAddress(String)
        case albumNotFound(String)
        case playlistNotFound(String)
        case trackNotFound(String)
        case noPhotos
        case emptyAlbumName
        case emptyBody
        case emptyRecipients
        case podcastSearchUnsupported
        case automationDenied
        case scriptFailed(String)

        var message: String {
            switch self {
            case .invalidAddress(let address): return "error.user.media_invalid_address".localizedFormat(address)
            case .albumNotFound(let name): return "error.user.media_album_not_found".localizedFormat(name)
            case .playlistNotFound(let name): return "error.user.media_playlist_not_found".localizedFormat(name)
            case .trackNotFound(let query): return "error.user.media_track_not_found".localizedFormat(query)
            case .noPhotos: return "error.user.media_no_photos".localized
            case .emptyAlbumName: return "error.user.media_empty_album".localized
            case .emptyBody: return "error.user.media_empty_body".localized
            case .emptyRecipients: return "error.user.media_empty_recipients".localized
            case .podcastSearchUnsupported: return "error.user.media_podcast_unsupported".localized
            case .automationDenied: return "error.user.apple_denied".localized
            case .scriptFailed(let detail): return "error.user.apple_failed".localizedFormat(detail)
            }
        }
    }

    typealias Outcome = Result<[String], FailureReason>

    static let defaultRunner: Runner = AppleApps.defaultRunner
    static let defaultOpener: Opener = { NSWorkspace.shared.open($0) }

    // MARK: - Mail

    /// 새 메일 초안을 만든다. `send == false`면 창만 열고 보내지 않는다.
    static func composeMail(
        to: String,
        cc: String,
        bcc: String,
        subject: String,
        body: String,
        attachments: [String],
        send: Bool,
        runner: Runner = defaultRunner
    ) -> Outcome {
        let toList: [String]
        let ccList: [String]
        let bccList: [String]
        switch validateAddresses(to) {
        case .failure(let reason): return .failure(reason)
        case .success(let list): toList = list
        }
        switch validateAddresses(cc) {
        case .failure(let reason): return .failure(reason)
        case .success(let list): ccList = list
        }
        switch validateAddresses(bcc) {
        case .failure(let reason): return .failure(reason)
        case .success(let list): bccList = list
        }

        return run(
            scripts.composeMail,
            arguments: [
                toList.joined(separator: "\n"),
                ccList.joined(separator: "\n"),
                bccList.joined(separator: "\n"),
                subject,
                body,
                send ? "1" : "0",
                attachments.joined(separator: "\n"),
            ],
            runner: runner
        )
    }

    /// 열려 있는 초안의 본문을 바꾼다. 초안이 없으면 새로 만든다
    static func setMailBody(_ body: String, runner: Runner = defaultRunner) -> Outcome {
        guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.emptyBody)
        }
        return run(scripts.setMailBody, arguments: [body], runner: runner)
    }

    /// 열려 있는 초안의 수신자를 바꾼다. 초안이 없으면 새로 만든다
    static func setMailRecipients(
        to: String,
        cc: String,
        bcc: String,
        runner: Runner = defaultRunner
    ) -> Outcome {
        let toList: [String]
        let ccList: [String]
        let bccList: [String]
        switch validateAddresses(to) {
        case .failure(let reason): return .failure(reason)
        case .success(let list): toList = list
        }
        switch validateAddresses(cc) {
        case .failure(let reason): return .failure(reason)
        case .success(let list): ccList = list
        }
        switch validateAddresses(bcc) {
        case .failure(let reason): return .failure(reason)
        case .success(let list): bccList = list
        }
        guard !(toList.isEmpty && ccList.isEmpty && bccList.isEmpty) else {
            return .failure(.emptyRecipients)
        }
        return run(
            scripts.setMailRecipients,
            arguments: [
                toList.joined(separator: "\n"),
                ccList.joined(separator: "\n"),
                bccList.joined(separator: "\n"),
            ],
            runner: runner
        )
    }

    // MARK: - Music

    static func playMusic(
        query: String,
        playlistName: String,
        runner: Runner = defaultRunner
    ) -> Outcome {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPlaylist = playlistName.trimmingCharacters(in: .whitespacesAndNewlines)
        return run(
            scripts.playMusic,
            arguments: [cleanQuery, cleanPlaylist],
            sentinels: [
                ("APEX_PLAYLIST_NOT_FOUND", .playlistNotFound(cleanPlaylist)),
                ("APEX_TRACK_NOT_FOUND", .trackNotFound(cleanQuery)),
            ],
            runner: runner
        )
    }

    // MARK: - Podcasts

    /// Podcasts는 AppleScript 사전이 없다. 앱을 여는 것만 보장한다.
    static func openPodcasts(opener: Opener = defaultOpener) -> Outcome {
        guard let url = URL(string: "podcasts://") else {
            return .failure(.scriptFailed("invalid podcasts URL"))
        }
        guard opener(url) else {
            return .failure(.scriptFailed("Podcasts could not be opened"))
        }
        return .success([])
    }

    /// URL이면 Podcasts(또는 기본 앱)로 연다. 검색어는 지원하지 않는다.
    static func playPodcast(
        url text: String,
        opener: Opener = defaultOpener
    ) -> Outcome {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return openPodcasts(opener: opener)
        }
        guard let url = URL(string: trimmed), url.scheme != nil else {
            return .failure(.podcastSearchUnsupported)
        }
        guard opener(url) else {
            return .failure(.scriptFailed("Podcast URL could not be opened"))
        }
        return .success([trimmed])
    }

    // MARK: - Photos

    /// 최근 사진의 파일 이름을 최신순으로 돌려준다
    static func recentPhotos(count: Int, runner: Runner = defaultRunner) -> Outcome {
        run(
            scripts.recentPhotos,
            arguments: [String(max(count, 1))],
            sentinels: [("APEX_NO_PHOTOS", .noPhotos)],
            runner: runner
        )
    }

    /// 최근 사진을 폴더로 내보내고 파일 URL을 돌려준다
    static func exportLastPhotos(
        count: Int,
        to destination: String,
        runner: Runner = defaultRunner,
        fileManager: FileManager = .default
    ) -> Outcome {
        let raw = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        let folder = raw.isEmpty
            ? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
            : URL(fileURLWithPath: (raw as NSString).expandingTildeInPath, isDirectory: true)
        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            return .failure(.scriptFailed(error.localizedDescription))
        }

        let backed: Outcome = run(
            scripts.exportLastPhotos,
            arguments: [String(max(count, 1)), folder.path],
            sentinels: [("APEX_NO_PHOTOS", .noPhotos)],
            runner: runner
        )
        switch backed {
        case .failure(let reason):
            return .failure(reason)
        case .success(let names):
            let urls = names.map { folder.appendingPathComponent($0) }
            return .success(urls.map(\.path))
        }
    }

    /// 가장 최근 사진(또는 지정 앨범)을 Photos에서 연다
    static func spotlightLatestPhoto(
        albumName: String,
        runner: Runner = defaultRunner
    ) -> Outcome {
        let cleanAlbum = albumName.trimmingCharacters(in: .whitespacesAndNewlines)
        return run(
            scripts.spotlightLatest,
            arguments: [cleanAlbum],
            sentinels: [
                ("APEX_ALBUM_NOT_FOUND", .albumNotFound(cleanAlbum)),
                ("APEX_NO_PHOTOS", .noPhotos),
            ],
            runner: runner
        )
    }

    /// 무작위 사진을 Photos에서 연다
    static func randomPhoto(runner: Runner = defaultRunner) -> Outcome {
        run(
            scripts.randomPhoto,
            arguments: [],
            sentinels: [("APEX_NO_PHOTOS", .noPhotos)],
            runner: runner
        )
    }

    /// 앨범 목록을 돌려준다
    static func albums(runner: Runner = defaultRunner) -> Outcome {
        run(scripts.listAlbums, arguments: [], runner: runner)
    }

    /// 앨범을 만든다
    static func createAlbum(name: String, runner: Runner = defaultRunner) -> Outcome {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return .failure(.emptyAlbumName) }
        return run(
            scripts.createAlbum,
            arguments: [cleanName],
            sentinels: [("APEX_ALBUM_EXISTS", .scriptFailed(cleanName))],
            runner: runner
        )
    }

    // MARK: - 순수 로직

    /// 주소 문자열을 쉼표·세미콜론·줄바꿈으로 나누고 `@`가 있는지 확인한다.
    /// 주소가 비어 있는 것은 허용한다(받는 사람 없이 초안만 여는 경우).
    static func validateAddresses(_ text: String) -> Result<[String], FailureReason> {
        let parts = text
            .split(whereSeparator: { $0 == "," || $0 == ";" || $0 == "\n" || $0 == "\r" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        for part in parts where !part.contains("@") {
            return .failure(.invalidAddress(part))
        }
        return .success(parts)
    }

    /// 첨부 경로 문자열을 정리한다 (줄바꿈 구분)
    static func parsePaths(_ text: String) -> [String] {
        text
            .split(whereSeparator: { $0 == "\n" || $0 == "\r" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - 내부

    private static func run(
        _ source: String,
        arguments: [String],
        sentinels: [(marker: String, reason: FailureReason)] = [],
        runner: Runner
    ) -> Outcome {
        let result = runner(source, arguments)
        if result.succeeded {
            return .success(AppleApps.parseLines(result.standardOutput))
        }
        for sentinel in sentinels where result.standardError.contains(sentinel.marker) {
            return .failure(sentinel.reason)
        }
        if result.timedOut {
            return .failure(.scriptFailed("timeout"))
        }
        if AppleApps.isAutomationDenied(result.standardError) {
            return .failure(.automationDenied)
        }
        let detail = result.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
        return .failure(.scriptFailed(detail.isEmpty ? "exit \(result.exitCode)" : String(detail.prefix(200))))
    }

    enum scripts {

        static let composeMail = """
        on run argv
            set toText to item 1 of argv
            set ccText to item 2 of argv
            set bccText to item 3 of argv
            set mailSubject to item 4 of argv
            set mailBody to item 5 of argv
            set shouldSend to item 6 of argv
            set attachmentText to item 7 of argv
            tell application "Mail"
                set newMessage to make new outgoing message with properties {subject:mailSubject, content:mailBody, visible:true}
                tell newMessage
                    repeat with addr in my splitLines(toText)
                        make new to recipient at end of to recipients with properties {address:addr}
                    end repeat
                    repeat with addr in my splitLines(ccText)
                        make new cc recipient at end of cc recipients with properties {address:addr}
                    end repeat
                    repeat with addr in my splitLines(bccText)
                        make new bcc recipient at end of bcc recipients with properties {address:addr}
                    end repeat
                    if attachmentText is not "" then
                        repeat with filePath in my splitLines(attachmentText)
                            tell content
                                make new attachment with properties {file name:(POSIX file filePath)} at after the last paragraph
                            end tell
                        end repeat
                    end if
                    if shouldSend is "1" then send
                end tell
                return mailSubject
            end tell
        end run

        on splitLines(theText)
            if theText is "" then return {}
            set oldDelims to AppleScript's text item delimiters
            set AppleScript's text item delimiters to linefeed
            set theItems to text items of theText
            set AppleScript's text item delimiters to oldDelims
            return theItems
        end splitLines
        """

        static let setMailBody = """
        on run argv
            set mailBody to item 1 of argv
            tell application "Mail"
                if (count of outgoing messages) is 0 then
                    set targetMessage to make new outgoing message with properties {visible:true}
                else
                    set targetMessage to last item of outgoing messages
                end if
                set content of targetMessage to mailBody
                return subject of targetMessage
            end tell
        end run
        """

        static let setMailRecipients = """
        on run argv
            set toText to item 1 of argv
            set ccText to item 2 of argv
            set bccText to item 3 of argv
            tell application "Mail"
                if (count of outgoing messages) is 0 then
                    set targetMessage to make new outgoing message with properties {visible:true}
                else
                    set targetMessage to last item of outgoing messages
                end if
                tell targetMessage
                    delete every to recipient
                    delete every cc recipient
                    delete every bcc recipient
                    repeat with addr in my splitLines(toText)
                        make new to recipient at end of to recipients with properties {address:addr}
                    end repeat
                    repeat with addr in my splitLines(ccText)
                        make new cc recipient at end of cc recipients with properties {address:addr}
                    end repeat
                    repeat with addr in my splitLines(bccText)
                        make new bcc recipient at end of bcc recipients with properties {address:addr}
                    end repeat
                end tell
                return subject of targetMessage
            end tell
        end run

        on splitLines(theText)
            if theText is "" then return {}
            set oldDelims to AppleScript's text item delimiters
            set AppleScript's text item delimiters to linefeed
            set theItems to text items of theText
            set AppleScript's text item delimiters to oldDelims
            return theItems
        end splitLines
        """

        static let playMusic = """
        on run argv
            set searchTerm to item 1 of argv
            set playlistName to item 2 of argv
            tell application "Music"
                if playlistName is not "" then
                    try
                        set targetPlaylist to user playlist playlistName
                    on error
                        error "APEX_PLAYLIST_NOT_FOUND" number 9301
                    end try
                    play targetPlaylist
                    return name of targetPlaylist
                end if
                if searchTerm is "" then
                    play
                    try
                        return name of current track
                    on error
                        return ""
                    end try
                end if
                try
                    set targetTrack to first track of library playlist 1 whose name contains searchTerm
                on error
                    try
                        set targetTrack to first track of library playlist 1 whose artist contains searchTerm
                    on error
                        error "APEX_TRACK_NOT_FOUND" number 9302
                    end try
                end try
                play targetTrack
                return name of targetTrack
            end tell
        end run
        """

        static let recentPhotos = """
        on run argv
            set theCount to (item 1 of argv) as integer
            tell application "Photos"
                set itemList to media items
                set total to count of itemList
                if total is 0 then error "APEX_NO_PHOTOS" number 9201
                if theCount > total then set theCount to total
                set outText to ""
                repeat with i from 1 to theCount
                    set theItem to item (total - i + 1) of itemList
                    set outText to outText & (filename of theItem) & linefeed
                end repeat
                return outText
            end tell
        end run
        """

        static let exportLastPhotos = """
        on run argv
            set theCount to (item 1 of argv) as integer
            set destPath to item 2 of argv
            tell application "Photos"
                set itemList to media items
                set total to count of itemList
                if total is 0 then error "APEX_NO_PHOTOS" number 9201
                if theCount > total then set theCount to total
                set chosen to {}
                repeat with i from 1 to theCount
                    set end of chosen to item (total - i + 1) of itemList
                end repeat
                export chosen to (POSIX file destPath) using originals true
                set outText to ""
                repeat with theItem in chosen
                    set outText to outText & (filename of theItem) & linefeed
                end repeat
                return outText
            end tell
        end run
        """

        static let spotlightLatest = """
        on run argv
            set albumName to item 1 of argv
            tell application "Photos"
                if albumName is "" then
                    set itemList to media items
                    if (count of itemList) is 0 then error "APEX_NO_PHOTOS" number 9201
                    set theItem to item -1 of itemList
                    spotlight theItem
                    return filename of theItem
                else
                    try
                        set theAlbum to album albumName
                    on error
                        error "APEX_ALBUM_NOT_FOUND" number 9202
                    end try
                    spotlight theAlbum
                    return name of theAlbum
                end if
            end tell
        end run
        """

        static let randomPhoto = """
        on run argv
            tell application "Photos"
                set itemList to media items
                set total to count of itemList
                if total is 0 then error "APEX_NO_PHOTOS" number 9201
                set theItem to item (random number from 1 to total) of itemList
                spotlight theItem
                return filename of theItem
            end tell
        end run
        """

        static let listAlbums = """
        on run argv
            set outText to ""
            tell application "Photos"
                repeat with theAlbum in albums
                    set outText to outText & (name of theAlbum) & linefeed
                end repeat
            end tell
            return outText
        end run
        """

        static let createAlbum = """
        on run argv
            set albumName to item 1 of argv
            tell application "Photos"
                try
                    set existingAlbum to album albumName
                    error "APEX_ALBUM_EXISTS" number 9203
                on error errMsg number errNum
                    if errNum is 9203 then error "APEX_ALBUM_EXISTS" number 9203
                end try
                set newAlbum to make new album with properties {name:albumName}
                return name of newAlbum
            end tell
        end run
        """
    }
}
