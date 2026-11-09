import Foundation

/// 콘텐츠·위치·웹 액션 파라미터 (T-221)
///
/// 대상: 메시지·이메일·지도·대중교통·웹 콘텐츠·프레젠테이션·웹 연동·단축어 아이콘.
/// 모두 공개 URL scheme·AppleScript·AppKit만 사용한다.
struct ContentLinkConfig: Codable, Hashable {

    enum WebContentMode: String, Codable, CaseIterable, Hashable {
        case title
        case text

        var displayName: String {
            switch self {
            case .title: return "content.mode.title".localized
            case .text: return "content.mode.text".localized
            }
        }
    }

    enum WebAction: String, Codable, CaseIterable, Hashable {
        case fetch
        case encode
        case decode

        var displayName: String {
            switch self {
            case .fetch: return "content.web.fetch".localized
            case .encode: return "content.web.encode".localized
            case .decode: return "content.web.decode".localized
            }
        }
    }

    enum PresentationAction: String, Codable, CaseIterable, Hashable {
        case start
        case stop

        var displayName: String {
            switch self {
            case .start: return "content.presentation.start".localized
            case .stop: return "content.presentation.stop".localized
            }
        }
    }

    enum TravelMode: String, Codable, CaseIterable, Hashable {
        case driving
        case walking
        case transit

        var displayName: String {
            switch self {
            case .driving: return "content.travel.driving".localized
            case .walking: return "content.travel.walking".localized
            case .transit: return "content.travel.transit".localized
            }
        }
    }

    var recipients: String?
    var subject: String?
    var body: String?
    var url: String?
    var origin: String?
    var destination: String?
    var preview: Bool?
    var sendImmediately: Bool?
    var webContentMode: WebContentMode?
    var webAction: WebAction?
    var presentationAction: PresentationAction?
    var travelMode: TravelMode?
    var symbolName: String?
    var colorHex: String?
    var outputPath: String?

    init(
        recipients: String? = nil,
        subject: String? = nil,
        body: String? = nil,
        url: String? = nil,
        origin: String? = nil,
        destination: String? = nil,
        preview: Bool? = nil,
        sendImmediately: Bool? = nil,
        webContentMode: WebContentMode? = nil,
        webAction: WebAction? = nil,
        presentationAction: PresentationAction? = nil,
        travelMode: TravelMode? = nil,
        symbolName: String? = nil,
        colorHex: String? = nil,
        outputPath: String? = nil
    ) {
        self.recipients = recipients
        self.subject = subject
        self.body = body
        self.url = url
        self.origin = origin
        self.destination = destination
        self.preview = preview
        self.sendImmediately = sendImmediately
        self.webContentMode = webContentMode
        self.webAction = webAction
        self.presentationAction = presentationAction
        self.travelMode = travelMode
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.outputPath = outputPath
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.recipients = try c.decodeIfPresent(String.self, forKey: .recipients)
        self.subject = try c.decodeIfPresent(String.self, forKey: .subject)
        self.body = try c.decodeIfPresent(String.self, forKey: .body)
        self.url = try c.decodeIfPresent(String.self, forKey: .url)
        self.origin = try c.decodeIfPresent(String.self, forKey: .origin)
        self.destination = try c.decodeIfPresent(String.self, forKey: .destination)
        self.preview = try c.decodeIfPresent(Bool.self, forKey: .preview)
        self.sendImmediately = try c.decodeIfPresent(Bool.self, forKey: .sendImmediately)
        self.webContentMode = try c.decodeIfPresent(WebContentMode.self, forKey: .webContentMode)
        self.webAction = try c.decodeIfPresent(WebAction.self, forKey: .webAction)
        self.presentationAction = try c.decodeIfPresent(PresentationAction.self, forKey: .presentationAction)
        self.travelMode = try c.decodeIfPresent(TravelMode.self, forKey: .travelMode)
        self.symbolName = try c.decodeIfPresent(String.self, forKey: .symbolName)
        self.colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex)
        self.outputPath = try c.decodeIfPresent(String.self, forKey: .outputPath)
    }

    static func decode(from data: Data?) -> ContentLinkConfig {
        guard let data, !data.isEmpty else { return ContentLinkConfig() }
        return (try? JSONDecoder().decode(ContentLinkConfig.self, from: data)) ?? ContentLinkConfig()
    }

    func encode() -> Data? {
        try? JSONEncoder().encode(self)
    }

    var resolvedPreview: Bool { preview ?? true }
    var resolvedSend: Bool { sendImmediately ?? false }
    var resolvedWebContentMode: WebContentMode { webContentMode ?? .text }
    var resolvedWebAction: WebAction { webAction ?? .fetch }
    var resolvedPresentationAction: PresentationAction { presentationAction ?? .start }
    var resolvedTravelMode: TravelMode { travelMode ?? .driving }
    var resolvedSymbol: String { symbolName?.isEmpty == false ? symbolName! : "sparkles" }
    var resolvedColorHex: String { colorHex?.isEmpty == false ? colorHex! : "#0A84FF" }
}
