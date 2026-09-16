import Foundation

/// 앱 언어 관리 — 표준 AppleLanguages 키 사용, 재시작 시 반영
@MainActor
final class LanguageManager {
    static let shared = LanguageManager()

    private let defaults = UserDefaults.standard
    private let appleLanguagesKey = "AppleLanguages"

    private init() {}

    /// 지원 언어 목록 (시스템 포함)
    let supportedLanguages: [(code: String?, displayName: String)] = [
        (nil, "settings.language.system".localized),
        ("ko", "settings.language.korean".localized),
        ("en", "settings.language.english".localized),
    ]

    /// 현재 설정된 언어 코드 (nil = 시스템)
    var currentLanguageCode: String? {
        guard let languages = defaults.array(forKey: appleLanguagesKey) as? [String],
              let first = languages.first else {
            return nil
        }
        return first
    }

    /// 언어 변경 — 재시작 후 적용됨
    func setLanguage(_ code: String?) {
        if let code {
            defaults.set([code], forKey: appleLanguagesKey)
        } else {
            defaults.removeObject(forKey: appleLanguagesKey)
        }
        // 동기화 강제
        defaults.synchronize()
        Logger.info("LanguageManager", "언어 설정 변경: \(code ?? "시스템") — 재시작 필요")
    }

    /// 언어 변경 필요 여부 (UI 배너 표시용)
    var needsRestart: Bool {
        guard let stored = currentLanguageCode else { return false }
        // 현재 번들의 주 언어와 다를 때
        let currentBundleLang = Bundle.main.preferredLocalizations.first ?? "en"
        return stored != currentBundleLang
    }

    /// 표시용 현재 언어 이름
    var currentLanguageDisplayName: String {
        guard let code = currentLanguageCode else {
            return supportedLanguages.first(where: { $0.code == nil })?.displayName ?? "System"
        }
        return supportedLanguages.first(where: { $0.code == code })?.displayName ?? code
    }
}

// MARK: - String Extension for Localization

extension String {
    /// Localizable.strings에서 지역화된 문자열 반환
    var localized: String {
        NSLocalizedString(self, comment: "")
    }

    /// 포맷팅된 지역화 문자열
    func localizedFormat(_ args: CVarArg...) -> String {
        String(format: self.localized, args)
    }
}