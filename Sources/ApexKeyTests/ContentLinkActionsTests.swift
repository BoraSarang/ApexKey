import Foundation
import XCTest
@testable import ApexKey

/// T-221 콘텐츠·위치·웹 검증.
///
/// 실제 메시지 발송·메일 발송·지도 앱·인터넷·Keynote를 건드리지 않는다.
/// 실행기·URL 열기·네트워크·아이콘 쓰기·앱 설치 확인을 주입해 인자와 실패 사유를 검사한다.
final class ContentLinkActionsTests: XCTestCase {

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

    // MARK: - 설정

    func testConfigDefaults() {
        let config = ContentLinkConfig()
        XCTAssertTrue(config.resolvedPreview)
        XCTAssertFalse(config.resolvedSend)
        XCTAssertEqual(config.resolvedWebContentMode, .text)
        XCTAssertEqual(config.resolvedWebAction, .fetch)
        XCTAssertEqual(config.resolvedPresentationAction, .start)
        XCTAssertEqual(config.resolvedTravelMode, .driving)
        XCTAssertEqual(config.resolvedSymbol, "sparkles")
        XCTAssertEqual(config.resolvedColorHex, "#0A84FF")
    }

    func testConfigTolerantDecoding() {
        let data = Data(#"{"travelMode":"transit","preview":false,"unknown":1}"#.utf8)
        let config = ContentLinkConfig.decode(from: data)
        XCTAssertEqual(config.resolvedTravelMode, .transit)
        XCTAssertFalse(config.resolvedPreview)
        XCTAssertNil(config.destination)
    }

    // MARK: - 메시지

    func testMessageRequiresRecipientAndBody() {
        XCTAssertEqual(
            ContentLinkActions.message(recipients: " ", body: "hi", confirm: { _ in true }) { _, _ in
                XCTFail("입력이 비면 실행하지 않는다")
                return self.result()
            },
            .failure(.emptyRecipients)
        )
        XCTAssertEqual(
            ContentLinkActions.message(recipients: "a@b.com", body: " ") { _, _ in
                XCTFail("내용이 비면 실행하지 않는다")
                return self.result()
            },
            .failure(.emptyBody)
        )
    }

    func testMessageCancelDoesNotRun() {
        var ran = false
        let outcome = ContentLinkActions.message(
            recipients: "a@b.com",
            body: "hello",
            preview: true,
            confirm: { message in
                XCTAssertTrue(message.contains("a@b.com"))
                return false
            }
        ) { _, _ in
            ran = true
            return self.result()
        }
        XCTAssertEqual(outcome, .failure(.cancelled))
        XCTAssertFalse(ran)
    }

    func testMessageRunsWithArguments() {
        var arguments: [String]?
        let outcome = ContentLinkActions.message(
            recipients: " a@b.com ",
            body: " hello ",
            preview: false
        ) { script, args in
            XCTAssertTrue(script.contains("on run argv"))
            arguments = args
            return self.result()
        }
        XCTAssertEqual(outcome, .success(["a@b.com"]))
        XCTAssertEqual(arguments, ["a@b.com", "hello"], "인젝션 방지를 위해 스크립트가 아닌 인자로 넘긴다")

        // 스크립트에 사용자 입력을 직접 넣지 않는다
        XCTAssertFalse(ContentLinkActions.scripts.message.contains("item 3 of argv"))
    }

    func testMessageMapsAutomationDenied() {
        XCTAssertEqual(
            ContentLinkActions.message(recipients: "a@b.com", body: "hi", preview: false) { _, _ in
                self.result(exitCode: 1, error: "Not authorized to send Apple events (-1743)")
            },
            .failure(.automationDenied)
        )
    }

    // MARK: - 이메일

    func testEmailRequiresRecipientAndBody() {
        XCTAssertEqual(
            ContentLinkActions.email(config: ContentLinkConfig(recipients: "", body: "x")) { _, _ in
                self.result()
            },
            .failure(.emptyRecipients)
        )
        XCTAssertEqual(
            ContentLinkActions.email(config: ContentLinkConfig(recipients: "a@b.com", body: "")) { _, _ in
                self.result()
            },
            .failure(.emptyBody)
        )
    }

    func testEmailDefaultsToDraft() {
        var arguments: [String]?
        let outcome = ContentLinkActions.email(
            config: ContentLinkConfig(
                recipients: "a@b.com",
                subject: "Hi",
                body: "Body"
            )
        ) { _, args in
            arguments = args
            return self.result()
        }
        XCTAssertEqual(outcome, .success([]), "초안 경로는 출력이 없다")
        XCTAssertEqual(arguments?.last, "", "첨부 없음")
        XCTAssertTrue(arguments?.contains("0") == true, "기본은 send=0(초안)")
    }

    func testEmailSendFlagIsForwarded() {
        var arguments: [String]?
        _ = ContentLinkActions.email(
            config: ContentLinkConfig(
                recipients: "a@b.com",
                body: "Body",
                sendImmediately: true
            )
        ) { _, args in
            arguments = args
            return self.result()
        }
        XCTAssertEqual(arguments?[5], "1", "바로 보내기를 켜면 send=1")
    }

    // MARK: - 지도·대중교통

    func testMapsURLIncludesMode() {
        let driving = ContentLinkActions.mapsURL(origin: "서울역", destination: "강남역", mode: .driving)
        let query = driving.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems }
        XCTAssertEqual(query?.first { $0.name == "dirflg" }?.value, "d")
        XCTAssertEqual(query?.first { $0.name == "saddr" }?.value, "서울역")
        XCTAssertEqual(query?.first { $0.name == "daddr" }?.value, "강남역")

        let walking = ContentLinkActions.mapsURL(origin: "", destination: "강남역", mode: .walking)
        let walkingQuery = walking.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems }
        XCTAssertEqual(walkingQuery?.first { $0.name == "dirflg" }?.value, "w")
        XCTAssertNil(walkingQuery?.first { $0.name == "saddr" }, "출발지가 비면 넣지 않는다")

        let transit = ContentLinkActions.mapsURL(origin: "", destination: "강남역", mode: .transit)
        let transitQuery = transit.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems }
        XCTAssertEqual(transitQuery?.first { $0.name == "dirflg" }?.value, "r")
    }

    func testOpenMapRequiresDestinationAndOpensURL() {
        XCTAssertEqual(
            ContentLinkActions.openMap(origin: "", destination: "  ", mode: .driving) { _ in
                XCTFail("도착지가 비면 열지 않는다")
                return true
            },
            .failure(.emptyDestination)
        )

        var opened: URL?
        let outcome = ContentLinkActions.openMap(
            origin: "",
            destination: "강남역",
            mode: .transit
        ) { url in
            opened = url
            return true
        }
        XCTAssertTrue(outcome.isSuccess)
        XCTAssertEqual(opened?.host, "maps.apple.com")
    }

    // MARK: - 웹 콘텐츠

    func testWebContentRejectsNonHTTP() {
        XCTAssertEqual(
            ContentLinkActions.webContent(urlString: " ", mode: .text) { _ in
                XCTFail("빈 주소는 가져오지 않는다")
                return .success(Data())
            },
            .failure(.emptyURL)
        )
        XCTAssertEqual(
            ContentLinkActions.webContent(urlString: "file:///etc/passwd", mode: .text) { _ in
                XCTFail("http·https가 아니면 가져오지 않는다")
                return .success(Data())
            },
            .failure(.invalidURL("file:///etc/passwd"))
        )
        XCTAssertEqual(
            ContentLinkActions.webContent(urlString: "https://", mode: .text) { _ in
                .success(Data())
            },
            .failure(.invalidURL("https://"))
        )
    }

    func testWebContentReadsTitleAndText() {
        let html = """
        <html><head><title>ApexKey &amp; You</title>
        <style>body { color: red; }</style></head>
        <body><h1>Heading</h1><p>Hello   world</p><script>alert(1)</script></body></html>
        """

        let title = ContentLinkActions.webContent(urlString: "https://example.com", mode: .title) { _ in
            .success(Data(html.utf8))
        }
        XCTAssertEqual(title, .success(["ApexKey & You"]))

        let text = ContentLinkActions.webContent(urlString: "https://example.com", mode: .text) { _ in
            .success(Data(html.utf8))
        }
        guard case .success(let values) = text else { return XCTFail("본문을 읽어야 함") }
        let joined = values.joined()
        XCTAssertTrue(joined.contains("Hello world"))
        XCTAssertFalse(joined.contains("alert(1)"), "스크립트는 제거한다")
        XCTAssertFalse(joined.contains("color: red"), "스타일은 제거한다")
        XCTAssertFalse(joined.contains("<p>"), "태그는 제거한다")
    }

    func testWebContentReportsFetchFailureAndEmptyContent() {
        XCTAssertEqual(
            ContentLinkActions.webContent(urlString: "https://example.com", mode: .text) { _ in
                .failure(NSError(domain: "test", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "offline",
                ]))
            },
            .failure(.fetchFailed("offline"))
        )
        XCTAssertEqual(
            ContentLinkActions.webContent(urlString: "https://example.com", mode: .text) { _ in
                .success(Data("<html></html>".utf8))
            },
            .failure(.emptyContent)
        )
    }

    // MARK: - 웹 연동

    func testWebIntegrationEncoding() {
        let encoded = ContentLinkActions.webIntegration(action: .encode, input: "a b&c=d")
        XCTAssertEqual(encoded, .success(["a%20b%26c%3Dd"]))

        guard case .success(let values) = ContentLinkActions.webIntegration(
            action: .decode,
            input: "a%20b%26c%3Dd"
        ) else { return XCTFail("디코딩 실패") }
        XCTAssertEqual(values, ["a b&c=d"])

        XCTAssertEqual(
            ContentLinkActions.webIntegration(action: .encode, input: ""),
            .failure(.emptyBody)
        )
    }

    func testWebIntegrationFetchDelegates() {
        let outcome = ContentLinkActions.webIntegration(
            action: .fetch,
            input: "https://example.com"
        ) { _ in
            .success(Data("<title>Fetched</title>".utf8))
        }
        XCTAssertEqual(outcome, .success(["Fetched"]))
    }

    // MARK: - 프레젠테이션

    func testPresentationRequiresKeynote() {
        var ran = false
        let outcome = ContentLinkActions.presentation(action: .start, installed: { _ in false }) { _, _ in
            ran = true
            return self.result()
        }
        XCTAssertEqual(outcome, .failure(.appNotInstalled("Keynote")))
        XCTAssertFalse(ran, "미설치면 스크립트를 실행하지 않는다")
    }

    func testPresentationRunsScriptAndClassifiesNotRunning() {
        var script: String?
        let started = ContentLinkActions.presentation(
            action: .start,
            installed: { _ in true }
        ) { source, _ in
            script = source
            return self.result()
        }
        XCTAssertEqual(started, .success(["Keynote"]))
        XCTAssertTrue(script?.contains("start slideshow") == true)
        XCTAssertTrue(script?.contains("APEX_KEYNOTE_NOT_RUNNING") == true)

        XCTAssertEqual(
            ContentLinkActions.presentation(action: .stop, installed: { _ in true }) { _, _ in
                self.result(exitCode: 1, error: "APEX_KEYNOTE_NOT_RUNNING")
            },
            .failure(.appNotRunning("Keynote"))
        )
    }

    // MARK: - 아이콘

    func testIconDestination() {
        XCTAssertEqual(
            ContentLinkActions.iconDestination("/tmp/ApexKeyIcon.png").path,
            "/tmp/ApexKeyIcon.png"
        )
        XCTAssertEqual(
            ContentLinkActions.iconDestination("/tmp/ApexKeyIcons").lastPathComponent,
            "ApexKey-icon.png"
        )
        XCTAssertEqual(
            ContentLinkActions.iconDestination("   ").lastPathComponent,
            "ApexKey-icon.png"
        )
    }

    func testIconUsesDefaultsAndReportsFailure() {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("ApexKeyIcon-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }

        var received: (String, String, URL)?
        let created = ContentLinkActions.createIcon(
            symbolName: " ",
            colorHex: "",
            outputPath: folder.path
        ) { symbol, color, url in
            received = (symbol, color, url)
            return true
        }
        XCTAssertTrue(created.isSuccess)
        XCTAssertEqual(received?.0, "sparkles")
        XCTAssertEqual(received?.1, "#0A84FF")

        XCTAssertEqual(
            ContentLinkActions.createIcon(
                symbolName: "star",
                colorHex: "#FF0000",
                outputPath: folder.path
            ) { _, _, _ in false },
            .failure(.iconFailed(folder.appendingPathComponent("ApexKey-icon.png").path))
        )
    }

    // MARK: - 엔진 배선

    private func run(_ step: ShortcutStep) -> ExecutionEngine.Result {
        var context = UseModelExecutor.ExecutionContext()
        return ExecutionEngine.shared.execute(steps: [step], context: &context)
    }

    private func step(_ type: ActionType, _ config: ContentLinkConfig) -> ShortcutStep {
        ShortcutStep(type: type, target: "", title: "", actionParameters: config.encode())
    }

    /// 실제 발송·지도 앱을 건드리지 않는 실패 경로만 엔진에 통과시킨다.
    func testContentActionsAreWiredIntoEngine() {
        let unimplemented = "toast.reason.unimplemented".localized

        let failing: [(ActionType, ContentLinkConfig)] = [
            (.message, ContentLinkConfig(recipients: "")),
            (.email, ContentLinkConfig(recipients: "", body: "")),
            (.map, ContentLinkConfig(destination: "")),
            (.transportation, ContentLinkConfig(destination: "")),
            (.webContent, ContentLinkConfig(url: "ftp://example.com")),
            (.webIntegration, ContentLinkConfig(body: "", webAction: .decode)),
        ]

        for (type, config) in failing {
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
