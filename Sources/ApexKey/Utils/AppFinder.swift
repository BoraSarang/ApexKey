import Foundation
import AppKit

/// 앱 검색/추가 유틸리티
enum AppFinder {
    /// /Applications + ~/Applications + (선택) 시스템 앱 디렉터리에 설치된 앱을 스캔
    /// - Parameter includesSystem: true면 /System/Applications(+Utilities)까지 포함
    static func installedApps(includesSystem: Bool = true) -> [AppItem] {
        var apps: [AppItem] = []
        var appURLs = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: NSHomeDirectory() + "/Applications"),
        ]
        if includesSystem {
            appURLs.append(contentsOf: [
                URL(fileURLWithPath: "/System/Applications"),
                URL(fileURLWithPath: "/System/Applications/Utilities"),
            ])
        }
        for dir in appURLs {
            guard let entries = try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }
            for url in entries where url.pathExtension == "app" {
                if let app = appItem(from: url) {
                    apps.append(app)
                }
            }
        }
        // 중복 제거 (bundleID 기준)
        var seen = Set<String>()
        var deduped = apps.filter {
            guard seen.insert($0.bundleID).inserted else { return false }
            return true
        }
        // Finder는 /System/Library/CoreServices에 있어 스캔 대상 밖 — 명시 추가
        if !seen.contains("com.apple.finder"), let finder = finderApp() {
            deduped.append(finder)
        }
        return deduped
    }

    /// Finder 명시 조회 (/System/Library/CoreServices/Finder.app).
    /// 항상 실행 중인 특수 앱이라 LaunchServices 등록 조회와 무관하게 경로로 확정한다.
    static func finderApp() -> AppItem? {
        let url = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return appItem(from: url)
    }

    /// .app URL → AppItem
    static func appItem(from url: URL) -> AppItem? {
        guard let bundle = Bundle(url: url) else { return nil }
        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        let bundleID = bundle.bundleIdentifier ?? url.deletingPathExtension().lastPathComponent
        return AppItem(
            name: name,
            bundleID: bundleID,
            path: url.path,
            category: categorize(path: url.path)
        )
    }

    /// 수동 앱 추가 (NSOpenPanel에서 .app 선택)
    static func appItem(fromPicked url: URL) -> AppItem? {
        appItem(from: url)
    }

    // MARK: - 카테고리 분류 (App Store 표준 메타데이터 기반, 키워드 하드코딩 없음)

    /// 실제 앱 메타데이터 기준 카테고리 판정.
    /// 1순위: Spotlight kMDItemAppStoreCategory → 2순위: Info.plist LSApplicationCategoryType
    /// → 3순위: http/https URL scheme 등록 앱(브라우저·웹 핸들러) → 기타
    static func categorize(path: String) -> AppCategory {
        // 1순위: Spotlight 메타데이터 (한국어/영어 값 모두 인식)
        if let spotlight = spotlightCategory(path: path),
           let category = mapSpotlight(spotlight) {
            return category
        }
        // 2순위: Info.plist LSApplicationCategoryType (언어 무관 UTI)
        if let bundle = Bundle(url: URL(fileURLWithPath: path)),
           let uti = bundle.object(forInfoDictionaryKey: "LSApplicationCategoryType") as? String,
           let category = mapUTI(uti) {
            return category
        }
        // 3순위: http/https 처리 앱 (브라우저·웹 핸들러) → 유틸리티. 이름 하드코딩 없이 앱이 등록한 URL scheme로 판별
        let schemes = urlSchemes(for: path).map { $0.lowercased() }
        if schemes.contains("http") || schemes.contains("https") {
            return .utilities
        }
        // 4순위: 기타
        return .uncategorized
    }

    /// spotlight 경로의 kMDItemAppStoreCategory 값을 읽는다 (없으면 nil)
    private static func spotlightCategory(path: String) -> String? {
        guard !path.isEmpty, FileManager.default.fileExists(atPath: path) else { return nil }
        let item = NSMetadataItem(url: URL(fileURLWithPath: path))
        return item?.value(forAttribute: "kMDItemAppStoreCategory") as? String
    }

    /// Spotlight 카테고리 표시값(한국어/영어) → AppCategory
    private static func mapSpotlight(_ raw: String) -> AppCategory? {
        let en = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        switch en {
        case "productivity", "생산성", "reference", "참고 자료", "finance", "금융":
            return .productivity
        case "utilities", "유틸리티":
            return .utilities
        case "photo & video", "사진 및 비디오", "photography", "사진",
             "video", "비디오", "graphics & design", "그래픽 및 디자인":
            return .photoVideo
        case "games", "게임", "entertainment", "엔터테인먼트":
            return .games
        case "business", "비즈니스":
            return .business
        case "education", "교육":
            return .education
        case "music", "음악":
            return .music
        case "social networking", "소셜 네트워킹", "news", "뉴스", "lifestyle", "라이프스타일":
            return .socialNetworking
        default:
            return nil
        }
    }

    /// Info.plist LSApplicationCategoryType (public.app-category.*) → AppCategory
    private static func mapUTI(_ uti: String) -> AppCategory? {
        let id = uti.lowercased().replacingOccurrences(of: "public.app-category.", with: "")
        switch id {
        case "productivity", "reference", "finance":
            return .productivity
        case "utilities":
            return .utilities
        case "photography", "video", "graphics-design":
            return .photoVideo
        case "games", "entertainment":
            return .games
        case "business":
            return .business
        case "education":
            return .education
        case "music":
            return .music
        case "social-networking", "news", "lifestyle":
            return .socialNetworking
        default:
            return nil
        }
    }

    /// 앱이 등록한 URL scheme 목록 (Info.plist CFBundleURLTypes). 경로가 비어있거나 읽기 불가면 빈 배열.
    static func urlSchemes(for path: String) -> [String] {
        guard !path.isEmpty, FileManager.default.fileExists(atPath: path),
              let bundle = Bundle(url: URL(fileURLWithPath: path)) else { return [] }
        guard let types = bundle.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else { return [] }
        return types.compactMap { $0["CFBundleURLSchemes"] as? [String] }.flatMap { $0 }
    }
}
