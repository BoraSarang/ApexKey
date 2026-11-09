import AppKit
import Foundation

/// 콘텐츠·위치·웹 — 메시지·이메일·지도·웹 콘텐츠·프레젠테이션·아이콘 (T-221)
///
/// **공개 경로만 사용한다.**
/// - 메시지: Messages AppleScript (`on run argv`, 인젝션 방지)
/// - 이메일: 기존 Mail 초안 경로 재사용 (기본은 보내지 않고 초안만 연다)
/// - 지도·대중교통: `maps.apple.com` URL scheme
/// - 웹 콘텐츠·웹 연동: URLSession + 로컬 HTML 파싱
/// - 프레젠테이션: Keynote AppleScript (미설치면 명확한 사유)
/// - 아이콘: AppKit으로 PNG 생성
///
/// 외부 실행·네트워크·이미지 쓰기는 주입 가능해 테스트가 실제 앱·인터넷을 건드리지 않는다.
enum ContentLinkActions {

    typealias Runner = AppleApps.Runner
    typealias Opener = (URL) -> Bool
    typealias Confirmer = (String) -> Bool
    typealias Fetcher = (URL) -> Result<Data, Error>
    typealias IconWriter = (_ symbol: String, _ colorHex: String, _ url: URL) -> Bool

    enum FailureReason: Equatable, Error {
        case emptyRecipients
        case emptyBody
        case emptyURL
        case invalidURL(String)
        case emptyDestination
        case fetchFailed(String)
        case invalidEncoding
        case emptyContent
        case appNotInstalled(String)
        case appNotRunning(String)
        case cancelled
        case iconFailed(String)
        case rejected(String)
        case automationDenied
        case scriptFailed(String)

        var message: String {
            switch self {
            case .emptyRecipients: return "error.user.content_empty_recipients".localized
            case .emptyBody: return "error.user.content_empty_body".localized
            case .emptyURL: return "error.user.content_empty_url".localized
            case .invalidURL(let value): return "error.user.content_invalid_url".localizedFormat(value)
            case .emptyDestination: return "error.user.content_empty_destination".localized
            case .fetchFailed(let detail): return "error.user.content_fetch_failed".localizedFormat(detail)
            case .invalidEncoding: return "error.user.content_invalid_encoding".localized
            case .emptyContent: return "error.user.content_empty_content".localized
            case .appNotInstalled(let name): return "error.user.content_app_not_installed".localizedFormat(name)
            case .appNotRunning(let name): return "error.user.content_app_not_running".localizedFormat(name)
            case .cancelled: return "error.user.content_cancelled".localized
            case .iconFailed(let detail): return "error.user.content_icon_failed".localizedFormat(detail)
            case .rejected(let message): return message
            case .automationDenied: return "error.user.apple_denied".localized
            case .scriptFailed(let detail): return "error.user.apple_failed".localizedFormat(detail)
            }
        }
    }

    typealias Outcome = Result<[String], FailureReason>

    static let defaultRunner: Runner = AppleApps.defaultRunner
    static let defaultOpener: Opener = { NSWorkspace.shared.open($0) }
    static let defaultConfirmer: Confirmer = { message in
        UserPromptActions.confirmation(message: message)
    }
    static let keynoteBundleID = "com.apple.iWork.Keynote"

    // MARK: - 메시지

    static func message(
        recipients: String,
        body: String,
        preview: Bool = true,
        confirm: Confirmer = defaultConfirmer,
        runner: Runner = defaultRunner
    ) -> Outcome {
        let recipient = recipients.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !recipient.isEmpty else { return .failure(.emptyRecipients) }
        guard !text.isEmpty else { return .failure(.emptyBody) }

        if preview {
            let prompt = "content.confirm.message".localizedFormat(recipient, text)
            guard confirm(prompt) else { return .failure(.cancelled) }
        }

        let result = runner(scripts.message, [recipient, text])
        if result.succeeded { return .success([recipient]) }
        return .failure(classify(result, runningMarker: "", notRunning: "Messages"))
    }

    // MARK: - 이메일

    static func email(
        config: ContentLinkConfig,
        runner: Runner = defaultRunner
    ) -> Outcome {
        let recipients = (config.recipients ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let body = (config.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !recipients.isEmpty else { return .failure(.emptyRecipients) }
        guard !body.isEmpty else { return .failure(.emptyBody) }

        let outcome = AppleMediaApps.composeMail(
            to: recipients,
            cc: "",
            bcc: "",
            subject: config.subject ?? "",
            body: body,
            attachments: [],
            send: config.resolvedSend,
            runner: runner
        )
        switch outcome {
        case .success(let lines): return .success(lines)
        case .failure(let reason): return .failure(.rejected(reason.message))
        }
    }

    // MARK: - 지도

    /// 지도 URL을 만든다. 운전 `d`, 도보 `w`, 대중교통 `r`.
    static func mapsURL(
        origin: String,
        destination: String,
        mode: ContentLinkConfig.TravelMode
    ) -> URL? {
        let target = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return nil }

        var components = URLComponents(string: "https://maps.apple.com/")
        var items: [URLQueryItem] = []
        let start = origin.trimmingCharacters(in: .whitespacesAndNewlines)
        if !start.isEmpty {
            items.append(URLQueryItem(name: "saddr", value: start))
        }
        items.append(URLQueryItem(name: "daddr", value: target))
        let flag: String
        switch mode {
        case .driving: flag = "d"
        case .walking: flag = "w"
        case .transit: flag = "r"
        }
        items.append(URLQueryItem(name: "dirflg", value: flag))
        components?.queryItems = items
        return components?.url
    }

    static func openMap(
        origin: String,
        destination: String,
        mode: ContentLinkConfig.TravelMode,
        opener: Opener = defaultOpener
    ) -> Outcome {
        guard !destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.emptyDestination)
        }
        guard let url = mapsURL(origin: origin, destination: destination, mode: mode) else {
            return .failure(.emptyDestination)
        }
        guard opener(url) else { return .failure(.invalidURL(url.absoluteString)) }
        return .success([url.absoluteString])
    }

    // MARK: - 웹 콘텐츠

    static func webContent(
        urlString: String,
        mode: ContentLinkConfig.WebContentMode,
        fetcher: Fetcher = defaultFetcher
    ) -> Outcome {
        guard let url = httpURL(urlString) else {
            return .failure(urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? .emptyURL
                : .invalidURL(urlString))
        }

        let data: Data
        switch fetcher(url) {
        case .success(let value): data = value
        case .failure(let error): return .failure(.fetchFailed(error.localizedDescription))
        }

        let html = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
        guard !html.isEmpty else { return .failure(.emptyContent) }

        let value: String
        switch mode {
        case .title: value = title(fromHTML: html)
        case .text: value = plainText(fromHTML: html)
        }
        guard !value.isEmpty else { return .failure(.emptyContent) }
        return .success([value])
    }

    /// `<title>` 내용을 읽는다. 없으면 첫 `<h1>`, 그것도 없으면 첫 문장 일부.
    static func title(fromHTML html: String) -> String {
        if let title = firstMatch(#"<title[^>]*>(.*?)</title>"#, in: html) {
            let decoded = decodeEntities(stripTags(title))
            if !decoded.isEmpty { return decoded }
        }
        if let heading = firstMatch(#"<h1[^>]*>(.*?)</h1>"#, in: html) {
            let decoded = decodeEntities(stripTags(heading))
            if !decoded.isEmpty { return decoded }
        }
        return String(plainText(fromHTML: html).prefix(120))
    }

    /// 태그를 걷어내고 공백을 정리한 본문 텍스트.
    static func plainText(fromHTML html: String) -> String {
        var text = html
        for pattern in [
            #"<script[^>]*>.*?</script>"#,
            #"<style[^>]*>.*?</style>"#,
            #"<!--.*?-->"#,
        ] {
            text = text.replacingOccurrences(
                of: pattern,
                with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        text = stripTags(text)
        text = decodeEntities(text)
        return text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    // MARK: - 웹 연동

    static func webIntegration(
        action: ContentLinkConfig.WebAction,
        input: String,
        fetcher: Fetcher = defaultFetcher
    ) -> Outcome {
        switch action {
        case .fetch:
            return webContent(urlString: input, mode: .text, fetcher: fetcher)

        case .encode:
            let source = input
            guard !source.isEmpty else { return .failure(.emptyBody) }
            var allowed = CharacterSet.urlQueryAllowed
            allowed.remove(charactersIn: "&?=#+")
            guard let encoded = source.addingPercentEncoding(withAllowedCharacters: allowed) else {
                return .failure(.invalidEncoding)
            }
            return .success([encoded])

        case .decode:
            guard !input.isEmpty else { return .failure(.emptyBody) }
            guard let decoded = input.removingPercentEncoding else {
                return .failure(.invalidEncoding)
            }
            return .success([decoded])
        }
    }

    // MARK: - 프레젠테이션

    static func presentation(
        action: ContentLinkConfig.PresentationAction,
        installed: (String) -> Bool = defaultInstalled,
        runner: Runner = defaultRunner
    ) -> Outcome {
        guard installed(keynoteBundleID) else {
            return .failure(.appNotInstalled("Keynote"))
        }
        let result = runner(scripts.presentation(action), [])
        if result.succeeded { return .success(["Keynote"]) }
        return .failure(classify(result, runningMarker: "APEX_KEYNOTE_NOT_RUNNING", notRunning: "Keynote"))
    }

    // MARK: - 단축어 아이콘

    static func createIcon(
        symbolName: String,
        colorHex: String,
        outputPath: String,
        fileManager: FileManager = .default,
        writer: IconWriter = defaultIconWriter
    ) -> Outcome {
        let symbol = symbolName.trimmingCharacters(in: .whitespacesAndNewlines)
        let color = colorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        let destination = iconDestination(outputPath, fileManager: fileManager)
        do {
            try fileManager.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            return .failure(.iconFailed(destination.deletingLastPathComponent().path))
        }

        let usedSymbol = symbol.isEmpty ? "sparkles" : symbol
        let usedColor = color.isEmpty ? "#0A84FF" : color
        guard writer(usedSymbol, usedColor, destination) else {
            return .failure(.iconFailed(destination.path))
        }
        return .success([destination.path])
    }

    static func iconDestination(_ path: String, fileManager: FileManager = .default) -> URL {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        let pictures = fileManager.urls(for: .picturesDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
        guard !trimmed.isEmpty else {
            return pictures.appendingPathComponent("ApexKey-icon.png")
        }
        let url = URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath)
        if url.pathExtension.lowercased() == "png" {
            return url.standardizedFileURL
        }
        return url.appendingPathComponent("ApexKey-icon.png")
    }

    /// 1024×1024 PNG — 둥근 배경 + 흰색 SF Symbol.
    static let defaultIconWriter: IconWriter = { symbol, colorHex, url in
        let size = NSSize(width: 1024, height: 1024)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        (NSColor(hexString: colorHex) ?? .systemBlue).setFill()
        NSBezierPath(
            roundedRect: NSRect(origin: .zero, size: size),
            xRadius: 220,
            yRadius: 220
        ).fill()

        let configuration = NSImage.SymbolConfiguration(pointSize: 520, weight: .semibold)
        guard let symbolImage = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) else {
            return false
        }
        symbolImage.isTemplate = true
        let tinted = NSImage(size: symbolImage.size)
        tinted.lockFocus()
        symbolImage.draw(
            at: .zero,
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
        NSColor.white.setFill()
        NSRect(origin: .zero, size: symbolImage.size).fill(using: .sourceAtop)
        tinted.unlockFocus()

        let origin = NSPoint(
            x: (size.width - symbolImage.size.width) / 2,
            y: (size.height - symbolImage.size.height) / 2
        )
        tinted.draw(at: origin, from: .zero, operation: .sourceOver, fraction: 1)

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            return false
        }
        return (try? png.write(to: url)) != nil
    }

    // MARK: - 네트워크

    static let defaultFetcher: Fetcher = { url in
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("ApexKey/1.8", forHTTPHeaderField: "User-Agent")
        let semaphore = DispatchSemaphore(value: 0)
        var outcome: Result<Data, Error> = .failure(
            NSError(domain: "ApexKey", code: -1, userInfo: [NSLocalizedDescriptionKey: "timeout"])
        )
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                outcome = .failure(error)
            } else if let http = response as? HTTPURLResponse,
                      !(200...299).contains(http.statusCode) {
                outcome = .failure(
                    NSError(
                        domain: "ApexKey",
                        code: http.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"]
                    )
                )
            } else if let data {
                outcome = .success(data)
            }
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 35)
        return outcome
    }

    // MARK: - 스크립트

    enum scripts {
        static let message = """
        on run argv
            set recipientAddress to item 1 of argv
            set messageText to item 2 of argv
            tell application "Messages"
                set targetService to 1st account whose service type = iMessage
                set targetBuddy to participant recipientAddress of targetService
                send messageText to targetBuddy
            end tell
        end run
        """

        static func presentation(_ action: ContentLinkConfig.PresentationAction) -> String {
            let body = action == .start ? "start slideshow" : "stop slideshow"
            return """
            if application "Keynote" is not running then error "APEX_KEYNOTE_NOT_RUNNING"
            tell application "Keynote"
                \(body)
            end tell
            """
        }
    }

    // MARK: - 공통

    static func httpURL(_ value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host?.isEmpty == false else {
            return nil
        }
        return url
    }

    static let defaultInstalled: (String) -> Bool = { bundleID in
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }

    static func classify(
        _ result: ProcessRunner.Result,
        runningMarker: String,
        notRunning: String
    ) -> FailureReason {
        let text = result.standardError + " " + result.standardOutput
        if !runningMarker.isEmpty, text.contains(runningMarker) {
            return .appNotRunning(notRunning)
        }
        if AppleApps.isAutomationDenied(text) { return .automationDenied }
        if result.timedOut { return .scriptFailed("timeout") }
        let detail = result.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
        if !detail.isEmpty { return .scriptFailed(String(detail.prefix(200))) }
        let output = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !output.isEmpty { return .scriptFailed(String(output.prefix(200))) }
        return .scriptFailed("exit \(result.exitCode)")
    }

    // MARK: - HTML

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let groupRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[groupRange])
    }

    private static func stripTags(_ text: String) -> String {
        text.replacingOccurrences(
            of: #"<[^>]+>"#,
            with: " ",
            options: .regularExpression
        )
    }

    private static func decodeEntities(_ text: String) -> String {
        var value = text
        let entities: [String: String] = [
            "&nbsp;": " ",
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&#39;": "'",
            "&apos;": "'",
        ]
        for (entity, replacement) in entities {
            value = value.replacingOccurrences(of: entity, with: replacement, options: .caseInsensitive)
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension NSColor {
    convenience init?(hexString: String) {
        var value = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let number = UInt32(value, radix: 16) else { return nil }
        self.init(
            srgbRed: CGFloat((number >> 16) & 0xFF) / 255,
            green: CGFloat((number >> 8) & 0xFF) / 255,
            blue: CGFloat(number & 0xFF) / 255,
            alpha: 1
        )
    }
}
