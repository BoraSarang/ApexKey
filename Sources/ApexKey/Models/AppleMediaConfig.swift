import Foundation

/// Apple 앱 연동 2 — Mail·Music·Podcasts·Photos 파라미터 (T-215)
///
/// T-214의 `AppleAppConfig`와 같은 관대 디코딩 규칙을 따른다.
/// 메일 발송은 **기본이 초안 열기**다(`sendImmediately` 기본 false).
/// 자동화에서 실수로 메일이 나가는 것이 이 액션의 가장 큰 위험이기 때문이다.
struct AppleMediaConfig: Codable, Hashable {

    /// `album` 동작
    enum AlbumOperation: String, Codable, CaseIterable, Hashable {
        case create
        case list

        var displayName: String {
            switch self {
            case .create: return "media.album.create".localized
            case .list: return "media.album.list".localized
            }
        }
    }

    // === Mail ===
    /// 받는 사람 — 쉼표·세미콜론·줄바꿈 구분
    var to: String?
    /// 참조
    var cc: String?
    /// 숨은 참조
    var bcc: String?
    var subject: String?
    var body: String?
    /// 보내기까지 실행 (기본 false — 초안만 연다)
    var sendImmediately: Bool?
    /// 첨부 파일 경로 — 줄바꿈 구분
    var attachments: String?

    // === Music ===
    /// 곡 이름·아티스트 검색어. 비우면 현재 재생을 이어간다
    var query: String?
    /// 재생할 재생목록 이름
    var playlistName: String?

    // === Podcasts ===
    /// 팟캐스트/에피소드 URL. Podcasts는 AppleScript 사전이 없어 URL scheme만 지원한다
    var podcastURL: String?

    // === Photos ===
    /// `album` 동작 — 기본은 만들기
    var albumOperation: AlbumOperation?
    /// 앨범 이름
    var albumName: String?
    /// 가져올 사진 수 (기본 1, 최대 50)
    var photoCount: Int?

    // === 파일 출력 ===
    /// `getLastPhoto` 내보낼 폴더. 비우면 다운로드 폴더
    var destination: String?

    init(
        to: String? = nil,
        cc: String? = nil,
        bcc: String? = nil,
        subject: String? = nil,
        body: String? = nil,
        sendImmediately: Bool? = nil,
        attachments: String? = nil,
        query: String? = nil,
        playlistName: String? = nil,
        podcastURL: String? = nil,
        albumOperation: AlbumOperation? = nil,
        albumName: String? = nil,
        photoCount: Int? = nil,
        destination: String? = nil
    ) {
        self.to = to
        self.cc = cc
        self.bcc = bcc
        self.subject = subject
        self.body = body
        self.sendImmediately = sendImmediately
        self.attachments = attachments
        self.query = query
        self.playlistName = playlistName
        self.podcastURL = podcastURL
        self.albumOperation = albumOperation
        self.albumName = albumName
        self.photoCount = photoCount
        self.destination = destination
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.to = try c.decodeIfPresent(String.self, forKey: .to)
        self.cc = try c.decodeIfPresent(String.self, forKey: .cc)
        self.bcc = try c.decodeIfPresent(String.self, forKey: .bcc)
        self.subject = try c.decodeIfPresent(String.self, forKey: .subject)
        self.body = try c.decodeIfPresent(String.self, forKey: .body)
        self.sendImmediately = try c.decodeIfPresent(Bool.self, forKey: .sendImmediately)
        self.attachments = try c.decodeIfPresent(String.self, forKey: .attachments)
        self.query = try c.decodeIfPresent(String.self, forKey: .query)
        self.playlistName = try c.decodeIfPresent(String.self, forKey: .playlistName)
        self.podcastURL = try c.decodeIfPresent(String.self, forKey: .podcastURL)
        self.albumOperation = try c.decodeIfPresent(AlbumOperation.self, forKey: .albumOperation)
        self.albumName = try c.decodeIfPresent(String.self, forKey: .albumName)
        self.photoCount = try c.decodeIfPresent(Int.self, forKey: .photoCount)
        self.destination = try c.decodeIfPresent(String.self, forKey: .destination)
    }

    static func decode(from data: Data?) -> AppleMediaConfig {
        guard let data, !data.isEmpty else { return AppleMediaConfig() }
        return (try? JSONDecoder().decode(AppleMediaConfig.self, from: data)) ?? AppleMediaConfig()
    }

    func encode() -> Data? {
        try? JSONEncoder().encode(self)
    }

    var shouldSend: Bool { sendImmediately ?? false }
    var resolvedAlbumOperation: AlbumOperation { albumOperation ?? .create }
    var resolvedPhotoCount: Int { min(max(photoCount ?? 1, 1), 50) }
}
