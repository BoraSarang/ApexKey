import XCTest
@testable import ApexKey

/// T-215 Apple 앱 2 — Mail·Music·Podcasts·Photos 검증.
///
/// 실제 앱 실행·발송·권한 없이 실행기와 URL 열기 클로저를 주입해 검증한다.
/// 메일은 기본이 초안 열기라는 점(발송 인자 "0")도 테스트로 고정한다.
final class AppleMediaAppsTests: XCTestCase {

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

    // MARK: - 순수 로직

    func testValidateAddressesSplitsAndRejects() {
        XCTAssertEqual(
            AppleMediaApps.validateAddresses("a@b.com, c@d.com; e@f.com\n"),
            .success(["a@b.com", "c@d.com", "e@f.com"])
        )
        XCTAssertEqual(
            AppleMediaApps.validateAddresses("not-an-address"),
            .failure(.invalidAddress("not-an-address"))
        )
        XCTAssertEqual(AppleMediaApps.validateAddresses("  "), .success([]))
    }

    func testParsePathsSplitsLines() {
        XCTAssertEqual(
            AppleMediaApps.parsePaths("/tmp/a.pdf\n\n /tmp/b.png \n"),
            ["/tmp/a.pdf", "/tmp/b.png"]
        )
    }

    // MARK: - Mail

    func testComposeMailDefaultsToDraft() {
        var arguments: [String]?
        let outcome = AppleMediaApps.composeMail(
            to: "a@b.com, c@d.com",
            cc: "",
            bcc: "",
            subject: "제목",
            body: "본문",
            attachments: ["/tmp/a.pdf"],
            send: false
        ) { source, args in
            XCTAssertTrue(source.contains("tell application \"Mail\""))
            arguments = args
            return self.result(output: "제목")
        }
        XCTAssertEqual(outcome, .success(["제목"]))
        XCTAssertEqual(arguments?[0], "a@b.com\nc@d.com")
        XCTAssertEqual(arguments?[3], "제목")
        XCTAssertEqual(arguments?[4], "본문")
        XCTAssertEqual(arguments?[5], "0", "기본은 초안 열기 — 발송하면 안 됨")
        XCTAssertEqual(arguments?[6], "/tmp/a.pdf")
    }

    func testComposeMailSendFlag() {
        var arguments: [String]?
        _ = AppleMediaApps.composeMail(
            to: "a@b.com",
            cc: "",
            bcc: "",
            subject: "",
            body: "",
            attachments: [],
            send: true
        ) { _, args in
            arguments = args
            return self.result(output: "")
        }
        XCTAssertEqual(arguments?[5], "1")
    }

    func testComposeMailInvalidAddressDoesNotRun() {
        let outcome = AppleMediaApps.composeMail(
            to: "broken",
            cc: "",
            bcc: "",
            subject: "",
            body: "",
            attachments: [],
            send: false
        ) { _, _ in
            XCTFail("주소가 잘못되면 스크립트를 실행하지 않아야 함")
            return self.result()
        }
        XCTAssertEqual(outcome, .failure(.invalidAddress("broken")))
    }

    func testSetMailBodyRequiresBody() {
        let outcome = AppleMediaApps.setMailBody("  ") { _, _ in
            XCTFail("본문이 비면 실행하지 않아야 함")
            return self.result()
        }
        XCTAssertEqual(outcome, .failure(.emptyBody))
    }

    func testSetMailRecipientsRequiresAtLeastOne() {
        let outcome = AppleMediaApps.setMailRecipients(to: "", cc: "", bcc: "") { _, _ in
            XCTFail("수신자가 모두 비면 실행하지 않아야 함")
            return self.result()
        }
        XCTAssertEqual(outcome, .failure(.emptyRecipients))
    }

    // MARK: - Music

    func testPlayMusicMapsPlaylistSentinel() {
        let outcome = AppleMediaApps.playMusic(query: "", playlistName: "없음") { _, _ in
            self.result(exitCode: 1, error: "execution error: APEX_PLAYLIST_NOT_FOUND (-9301)")
        }
        XCTAssertEqual(outcome, .failure(.playlistNotFound("없음")))
    }

    func testPlayMusicMapsTrackSentinel() {
        let outcome = AppleMediaApps.playMusic(query: "없는 곡", playlistName: "") { _, _ in
            self.result(exitCode: 1, error: "execution error: APEX_TRACK_NOT_FOUND (-9302)")
        }
        XCTAssertEqual(outcome, .failure(.trackNotFound("없는 곡")))
    }

    func testPlayMusicPassesQueryAndPlaylist() {
        var arguments: [String]?
        let outcome = AppleMediaApps.playMusic(query: "Yesterday", playlistName: "Favorites") { source, args in
            XCTAssertTrue(source.contains("tell application \"Music\""))
            arguments = args
            return self.result(output: "Yesterday")
        }
        XCTAssertEqual(outcome, .success(["Yesterday"]))
        XCTAssertEqual(arguments, ["Yesterday", "Favorites"])
    }

    // MARK: - Podcasts

    func testPlayPodcastRejectsSearchTerm() {
        let outcome = AppleMediaApps.playPodcast(url: "jazz") { _ in
            XCTFail("검색어는 URL이 아니므로 열지 않아야 함")
            return true
        }
        XCTAssertEqual(outcome, .failure(.podcastSearchUnsupported))
    }

    func testPlayPodcastOpensURL() {
        var opened: URL?
        let outcome = AppleMediaApps.playPodcast(url: "podcast://example/episode") { url in
            opened = url
            return true
        }
        XCTAssertEqual(outcome, .success(["podcast://example/episode"]))
        XCTAssertEqual(opened?.scheme, "podcast")
    }

    func testPodcastsOpensAppScheme() {
        var opened: URL?
        let outcome = AppleMediaApps.openPodcasts { url in
            opened = url
            return true
        }
        XCTAssertEqual(outcome, .success([]))
        XCTAssertEqual(opened?.absoluteString, "podcasts://")
    }

    func testPodcastsOpenFailure() {
        let outcome = AppleMediaApps.openPodcasts { _ in false }
        XCTAssertEqual(outcome, .failure(.scriptFailed("Podcasts could not be opened")))
    }

    // MARK: - Photos

    func testRecentPhotosPassesCount() {
        var arguments: [String]?
        let outcome = AppleMediaApps.recentPhotos(count: 3) { source, args in
            XCTAssertTrue(source.contains("tell application \"Photos\""))
            arguments = args
            return self.result(output: "IMG_3.HEIC\nIMG_2.HEIC\nIMG_1.HEIC\n")
        }
        XCTAssertEqual(outcome, .success(["IMG_3.HEIC", "IMG_2.HEIC", "IMG_1.HEIC"]))
        XCTAssertEqual(arguments, ["3"])
    }

    func testRecentPhotosEmptyLibrary() {
        let outcome = AppleMediaApps.recentPhotos(count: 1) { _, _ in
            self.result(exitCode: 1, error: "execution error: APEX_NO_PHOTOS (-9201)")
        }
        XCTAssertEqual(outcome, .failure(.noPhotos))
    }

    func testExportLastPhotosReturnsFolderPaths() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("ApexKeyPhotos-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        var arguments: [String]?
        let outcome = AppleMediaApps.exportLastPhotos(count: 2, to: folder.path) { _, args in
            arguments = args
            return self.result(output: "a.jpg\nb.jpg\n")
        }

        XCTAssertEqual(outcome, .success([
            folder.appendingPathComponent("a.jpg").path,
            folder.appendingPathComponent("b.jpg").path,
        ]))
        XCTAssertEqual(arguments?[0], "2")
        XCTAssertEqual(arguments?[1], folder.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.path))
    }

    func testAlbumCreateRequiresName() {
        let outcome = AppleMediaApps.createAlbum(name: "  ") { _, _ in
            XCTFail("이름이 없으면 실행하지 않아야 함")
            return self.result()
        }
        XCTAssertEqual(outcome, .failure(.emptyAlbumName))
    }

    func testAlbumCreateAndList() {
        var captured: [String]?
        let create = AppleMediaApps.createAlbum(name: "여행") { source, args in
            XCTAssertTrue(source.contains("tell application \"Photos\""))
            captured = args
            return self.result(output: "여행")
        }
        XCTAssertEqual(create, .success(["여행"]))
        XCTAssertEqual(captured, ["여행"])

        let list = AppleMediaApps.albums { _, _ in
            self.result(output: "여행\n가족\n")
        }
        XCTAssertEqual(list, .success(["여행", "가족"]))
    }

    func testSpotlightLatestMapsAlbumSentinel() {
        let outcome = AppleMediaApps.spotlightLatestPhoto(albumName: "없음") { _, _ in
            self.result(exitCode: 1, error: "execution error: APEX_ALBUM_NOT_FOUND (-9202)")
        }
        XCTAssertEqual(outcome, .failure(.albumNotFound("없음")))
    }

    func testAutomationDenied() {
        let outcome = AppleMediaApps.recentPhotos(count: 1) { _, _ in
            self.result(exitCode: 1, error: "Not authorized to send Apple events (-1743)")
        }
        XCTAssertEqual(outcome, .failure(.automationDenied))
    }

    // MARK: - 엔진 배선

    private func run(_ step: ShortcutStep) -> ExecutionEngine.Result {
        var context = UseModelExecutor.ExecutionContext()
        return ExecutionEngine.shared.execute(steps: [step], context: &context)
    }

    private func step(_ type: ActionType, _ config: AppleMediaConfig) -> ShortcutStep {
        ShortcutStep(type: type, target: "", title: "", actionParameters: config.encode())
    }

    /// 앱을 실제로 띄우지 않고 실패하는 경로만 엔진에 통과시킨다.
    /// 나머지는 `ActionCatalogIntegrityTests`의 구현 분류로 배선을 확인한다.
    func testMediaActionsAreWiredIntoEngine() {
        let unimplemented = "toast.reason.unimplemented".localized
        let cases: [(ActionType, AppleMediaConfig, String)] = [
            (.mail, AppleMediaConfig(to: "broken"), "error.user.media_invalid_address".localized),
            (.emailData, AppleMediaConfig(to: "broken"), "error.user.media_invalid_address".localized),
            (.setMailBody, AppleMediaConfig(), "error.user.media_empty_body".localized),
            (.setMailRecipients, AppleMediaConfig(), "error.user.media_empty_recipients".localized),
            (.album, AppleMediaConfig(albumOperation: .create, albumName: ""), "error.user.media_empty_album".localized),
            (.playPodcast, AppleMediaConfig(podcastURL: "jazz"), "error.user.media_podcast_unsupported".localized),
        ]

        for (type, config, expected) in cases {
            let result = run(step(type, config))
            XCTAssertFalse(result.success, "\(type.rawValue) 는 잘못된 입력으로 실패해야 함")
            XCTAssertNotEqual(result.error, unimplemented, "\(type.rawValue) 가 엔진에 배선되지 않았다")
            if type == .mail || type == .emailData {
                XCTAssertTrue(result.error?.hasPrefix("이메일 주소가 올바르지 않습니다") == true
                    || result.error?.hasPrefix("Invalid email address") == true,
                    "\(type.rawValue) 사유: \(result.error ?? "nil")")
            } else {
                XCTAssertEqual(result.error, expected, type.rawValue)
            }
        }
    }
}
