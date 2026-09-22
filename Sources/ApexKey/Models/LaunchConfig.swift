import Foundation

/// 앱 실행/토글 단계의 구조화 설정 (P0).
/// 기존 `target=bundleID` 문자열과의 하위호환을 유지한다:
/// - `launchConfig == nil`이면 `target`을 bundleID로 간주 (레거시)
/// - `launchConfig != nil`이면 구조화 설정을 우선 사용
struct LaunchConfig: Codable, Hashable {
    /// 대상 앱 번들 ID (예: com.apple.Safari). 비어 있으면 앱 미지정.
    var bundleID: String
    /// 명시적 .app 경로 (비어 있으면 LaunchServices 등록 정보로 해석)
    var path: String
    /// 실행 모드
    var mode: LaunchMode
    /// 실행 인자 (예: --incognito). 셸 파싱 없이 공백 기준 분할하되 따옴표 유지.
    var args: String
    /// URL 스킴 실행 (예: obsidian://open?vault=x). 비어 있지 않으면 bundleID보다 우선.
    var urlScheme: String

    init(
        bundleID: String = "",
        path: String = "",
        mode: LaunchMode = .toggle,
        args: String = "",
        urlScheme: String = ""
    ) {
        self.bundleID = bundleID
        self.path = path
        self.mode = mode
        self.args = args
        self.urlScheme = urlScheme
    }

    /// 레거시 target 문자열에서 마이그레이션 (bundleID로 간주)
    static func migrated(fromLegacyTarget target: String) -> LaunchConfig {
        LaunchConfig(bundleID: target.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// 실행에 사용할 표시 이름
    var displayName: String {
        if !urlScheme.isEmpty { return urlScheme }
        if !bundleID.isEmpty { return bundleID }
        if !path.isEmpty { return (path as NSString).lastPathComponent }
        return ""
    }

    var hasURLScheme: Bool {
        !urlScheme.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 인자 문자열 → [String] (따옴표 묶음 유지)
    var parsedArgs: [String] {
        LaunchConfig.parseArgs(args)
    }

    /// 공백 분할 + 작은/큰따옴표 그룹 유지. 예: `--a "hello world" --b` → ["--a","hello world","--b"]
    static func parseArgs(_ raw: String) -> [String] {
        var result: [String] = []
        var current = ""
        var quote: Character?
        for ch in raw {
            if let q = quote {
                if ch == q {
                    quote = nil
                } else {
                    current.append(ch)
                }
            } else if ch == "\"" || ch == "'" {
                quote = ch
            } else if ch == " " || ch == "\t" {
                if !current.isEmpty {
                    result.append(current)
                    current = ""
                }
            } else {
                current.append(ch)
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }
}

/// `json:{LaunchConfig}` target 코덱 — 단일 출처 (D3).
/// ActionExecutor·StepSettingsView·Shortcut이 공유. 포맷 변경 시 여기만 수정한다.
enum LaunchConfigCodec {
    static let prefix = "json:"

    /// target → LaunchConfig (`json:` 없으면 nil = 레거시 bundleID 취급)
    static func decode(from target: String) -> LaunchConfig? {
        guard target.hasPrefix(prefix) else { return nil }
        let json = String(target.dropFirst(prefix.count))
        guard let data = json.data(using: .utf8) else {
            Logger.error("E-MAC-APP-4003", "LaunchConfig UTF-8 변환 실패")
            return nil
        }
        do {
            return try JSONDecoder().decode(LaunchConfig.self, from: data)
        } catch {
            Logger.error("E-MAC-APP-4003", "LaunchConfig 디코딩 실패: \(error.localizedDescription)")
            return nil
        }
    }

    /// LaunchConfig → target (실패 시 bundleID 폴백)
    static func encode(_ config: LaunchConfig) -> String {
        do {
            let data = try JSONEncoder().encode(config)
            guard let json = String(data: data, encoding: .utf8) else {
                Logger.error("E-MAC-APP-4003", "LaunchConfig 인코딩 문자열 변환 실패 — bundleID 폴백")
                return config.bundleID
            }
            return prefix + json
        } catch {
            Logger.error("E-MAC-APP-4003", "LaunchConfig 인코딩 실패: \(error.localizedDescription) — bundleID 폴백")
            return config.bundleID
        }
    }
}

/// 앱 실행 모드 (Thor 스타일 토글 유지)
enum LaunchMode: String, Codable, CaseIterable, Identifiable {
    case toggle    // 실행 중+전면이면 숨김, 아니면 활성화/실행
    case activate  // 항상 활성화 (숨김 동작 없음)
    case launch    // 단순 실행만 (이미 실행 중이면 활성화만)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .toggle: return "launch.mode.toggle".localized
        case .activate: return "launch.mode.activate".localized
        case .launch: return "launch.mode.launch".localized
        }
    }
}
