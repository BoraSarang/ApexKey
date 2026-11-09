import Foundation

/// 미디어 편집·캡처 파라미터 (T-220)
///
/// 대상: 이미지 회전/자르기, 비디오 자르기, 카메라 촬영, 출력 볼륨, 현재 곡 이동,
/// 음악 재생 제어. 모든 필드는 선택값이라 일부만 저장된 설정도 살아남는다.
struct MediaEditingConfig: Codable, Hashable {

    enum PlaybackCommand: String, Codable, CaseIterable, Hashable {
        case play
        case pause
        case playPause
        case next
        case previous
        case stop

        var displayName: String {
            switch self {
            case .play: return "media.playback.play".localized
            case .pause: return "media.playback.pause".localized
            case .playPause: return "media.playback.play_pause".localized
            case .next: return "media.playback.next".localized
            case .previous: return "media.playback.previous".localized
            case .stop: return "media.playback.stop".localized
            }
        }
    }

    var path: String?
    var outputPath: String?
    var angle: Double?
    var cropX: Double?
    var cropY: Double?
    var cropWidth: Double?
    var cropHeight: Double?
    var startSeconds: Double?
    var endSeconds: Double?
    var volume: Int?
    var destination: String?
    var confirmBeforeChange: Bool?
    var playback: PlaybackCommand?

    init(
        path: String? = nil,
        outputPath: String? = nil,
        angle: Double? = nil,
        cropX: Double? = nil,
        cropY: Double? = nil,
        cropWidth: Double? = nil,
        cropHeight: Double? = nil,
        startSeconds: Double? = nil,
        endSeconds: Double? = nil,
        volume: Int? = nil,
        destination: String? = nil,
        confirmBeforeChange: Bool? = nil,
        playback: PlaybackCommand? = nil
    ) {
        self.path = path
        self.outputPath = outputPath
        self.angle = angle
        self.cropX = cropX
        self.cropY = cropY
        self.cropWidth = cropWidth
        self.cropHeight = cropHeight
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.volume = volume
        self.destination = destination
        self.confirmBeforeChange = confirmBeforeChange
        self.playback = playback
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.path = try c.decodeIfPresent(String.self, forKey: .path)
        self.outputPath = try c.decodeIfPresent(String.self, forKey: .outputPath)
        self.angle = try c.decodeIfPresent(Double.self, forKey: .angle)
        self.cropX = try c.decodeIfPresent(Double.self, forKey: .cropX)
        self.cropY = try c.decodeIfPresent(Double.self, forKey: .cropY)
        self.cropWidth = try c.decodeIfPresent(Double.self, forKey: .cropWidth)
        self.cropHeight = try c.decodeIfPresent(Double.self, forKey: .cropHeight)
        self.startSeconds = try c.decodeIfPresent(Double.self, forKey: .startSeconds)
        self.endSeconds = try c.decodeIfPresent(Double.self, forKey: .endSeconds)
        self.volume = try c.decodeIfPresent(Int.self, forKey: .volume)
        self.destination = try c.decodeIfPresent(String.self, forKey: .destination)
        self.confirmBeforeChange = try c.decodeIfPresent(Bool.self, forKey: .confirmBeforeChange)
        self.playback = try c.decodeIfPresent(PlaybackCommand.self, forKey: .playback)
    }

    static func decode(from data: Data?) -> MediaEditingConfig {
        guard let data, !data.isEmpty else { return MediaEditingConfig() }
        return (try? JSONDecoder().decode(MediaEditingConfig.self, from: data)) ?? MediaEditingConfig()
    }

    func encode() -> Data? {
        try? JSONEncoder().encode(self)
    }

    var resolvedAngle: Double { angle ?? 90 }
    var resolvedVolume: Int { volume ?? 50 }
    var resolvedPlayback: PlaybackCommand { playback ?? .playPause }
    var resolvedConfirm: Bool { confirmBeforeChange ?? true }
    var resolvedStart: Double { startSeconds ?? 0 }
    var resolvedEnd: Double { endSeconds ?? 0 }
}
