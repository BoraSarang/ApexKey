import Foundation

/// 파일 열기 부가 설정 — `step.actionParameters`에 JSON으로 저장 (T-188).
///
/// `target`은 파일 경로 한 줄만 담을 수 있어 "어떤 앱으로 열지"를 표현할 수 없다
/// (TextActionConfig가 2입력을 `actionParameters`에 넣은 것과 같은 이유).
/// `ShortcutStep`에 저장 필드를 추가하지 않으므로 기존 blob 디코딩 내성에 영향 없음.
struct FileOpenConfig: Codable, Hashable {
    /// 함께 열 앱 번들ID. 비어 있으면 기본앱으로 열기 (기존 동작).
    var appBundleID: String?

    /// `actionParameters`에서 안전하게 복원 — 없으면 기본앱 동작
    static func decode(from data: Data?) -> FileOpenConfig {
        guard let data, !data.isEmpty else { return FileOpenConfig() }
        return (try? JSONDecoder().decode(FileOpenConfig.self, from: data)) ?? FileOpenConfig()
    }

    func encode() -> Data? {
        try? JSONEncoder().encode(self)
    }
}
