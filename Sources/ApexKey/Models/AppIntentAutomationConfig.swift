import Foundation

/// App Intents·자동화 카탈로그 파라미터 (T-222)
///
/// `appIntent`는 Shortcuts 앱에서 만든 단축어를 실행한다. App Intent를 직접
/// 호출하는 공개 런타임 API가 없으므로, 사용자가 단축어로 감싼 뒤 이름으로 실행한다.
/// `appAction`은 앱의 URL scheme을 열어 동작을 실행한다.
struct AppIntentAutomationConfig: Codable, Hashable {

    var query: String?
    var shortcutName: String?
    var input: String?
    var url: String?
    var triggerName: String?
    var includeSystemApps: Bool?
    var includeUnsupported: Bool?

    init(
        query: String? = nil,
        shortcutName: String? = nil,
        input: String? = nil,
        url: String? = nil,
        triggerName: String? = nil,
        includeSystemApps: Bool? = nil,
        includeUnsupported: Bool? = nil
    ) {
        self.query = query
        self.shortcutName = shortcutName
        self.input = input
        self.url = url
        self.triggerName = triggerName
        self.includeSystemApps = includeSystemApps
        self.includeUnsupported = includeUnsupported
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.query = try c.decodeIfPresent(String.self, forKey: .query)
        self.shortcutName = try c.decodeIfPresent(String.self, forKey: .shortcutName)
        self.input = try c.decodeIfPresent(String.self, forKey: .input)
        self.url = try c.decodeIfPresent(String.self, forKey: .url)
        self.triggerName = try c.decodeIfPresent(String.self, forKey: .triggerName)
        self.includeSystemApps = try c.decodeIfPresent(Bool.self, forKey: .includeSystemApps)
        self.includeUnsupported = try c.decodeIfPresent(Bool.self, forKey: .includeUnsupported)
    }

    static func decode(from data: Data?) -> AppIntentAutomationConfig {
        guard let data, !data.isEmpty else { return AppIntentAutomationConfig() }
        return (try? JSONDecoder().decode(AppIntentAutomationConfig.self, from: data))
            ?? AppIntentAutomationConfig()
    }

    func encode() -> Data? {
        try? JSONEncoder().encode(self)
    }

    var resolvedIncludeSystemApps: Bool { includeSystemApps ?? true }
    var resolvedIncludeUnsupported: Bool { includeUnsupported ?? true }
}
