import Foundation

/// 터미널에서 열기 부가 설정 — `step.actionParameters`에 JSON으로 저장 (T-195).
///
/// `ShortcutStep`에 저장 필드를 추가하지 않는다 → `stepsData` blob의 키 누락 내성
/// (E-MAC-STORE-5008)을 깨지 않는다. `FileOpenConfig`(T-188)와 같은 이유·같은 패턴.
struct TerminalOpenConfig: Codable, Hashable {
    /// 터미널 앱 번들ID. 비어 있으면 **자동** (iTerm2가 있으면 iTerm2, 없으면 터미널).
    var appBundleID: String?
    /// 새 탭으로 열기. false(기본)면 새 창 — 새 창은 Automation 권한이 필요 없다.
    var openInNewTab: Bool

    init(appBundleID: String? = nil, openInNewTab: Bool = false) {
        self.appBundleID = appBundleID
        self.openInNewTab = openInNewTab
    }

    /// **관대 디코딩**: 키가 없어도 실패하지 않는다 (E-MAC-STORE-5008).
    /// 합성 `Decodable`은 프로퍼티 기본값을 쓰지 않으므로 키 하나 빠지면 디코딩이 통째로
    /// 실패한다 — 그러면 저장된 설정이 조용히 기본값으로 되돌아간다. 직접 읽는다.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.appBundleID = try c.decodeIfPresent(String.self, forKey: .appBundleID)
        self.openInNewTab = try c.decodeIfPresent(Bool.self, forKey: .openInNewTab) ?? false
    }

    /// `actionParameters`에서 안전하게 복원 — 없거나 깨졌으면 기본값(자동·새 창)
    static func decode(from data: Data?) -> TerminalOpenConfig {
        guard let data, !data.isEmpty else { return TerminalOpenConfig() }
        return (try? JSONDecoder().decode(TerminalOpenConfig.self, from: data)) ?? TerminalOpenConfig()
    }

    func encode() -> Data? {
        try? JSONEncoder().encode(self)
    }
}
