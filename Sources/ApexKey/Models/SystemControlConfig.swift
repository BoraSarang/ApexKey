import Foundation

/// 시스템 제어 액션 파라미터 — Wi-Fi·집중 모드 (T-219)
///
/// 두 액션 모두 **공개 경로만** 사용한다.
/// - Wi-Fi: `/usr/sbin/networksetup` (Apple 공개 CLI)
/// - 집중 모드: 사용자가 Shortcuts 앱에서 만든 "집중 모드 설정" 단축어를 `/usr/bin/shortcuts`로 실행
///
/// 집중 모드는 공개 스크립팅 API가 없어, 사용자가 만든 단축어 이름을 받아 실행한다.
/// 단축어가 없으면 실행 전에 "단축어를 찾지 못했습니다" 사유를 돌려준다.
struct SystemControlConfig: Codable, Hashable {

    enum WiFiAction: String, Codable, CaseIterable, Hashable {
        case status
        case turnOn
        case turnOff

        var displayName: String {
            switch self {
            case .status: return "wifi.action.status".localized
            case .turnOn: return "wifi.action.turn_on".localized
            case .turnOff: return "wifi.action.turn_off".localized
            }
        }
    }

    /// Wi-Fi 동작
    var wifiAction: WiFiAction?
    /// 집중 모드를 바꾸는 Shortcuts 단축어 이름
    var shortcutName: String?

    init(wifiAction: WiFiAction? = nil, shortcutName: String? = nil) {
        self.wifiAction = wifiAction
        self.shortcutName = shortcutName
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.wifiAction = try c.decodeIfPresent(WiFiAction.self, forKey: .wifiAction)
        self.shortcutName = try c.decodeIfPresent(String.self, forKey: .shortcutName)
    }

    static func decode(from data: Data?) -> SystemControlConfig {
        guard let data, !data.isEmpty else { return SystemControlConfig() }
        return (try? JSONDecoder().decode(SystemControlConfig.self, from: data)) ?? SystemControlConfig()
    }

    func encode() -> Data? {
        try? JSONEncoder().encode(self)
    }

    var resolvedWiFiAction: WiFiAction { wifiAction ?? .status }
}
