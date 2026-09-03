import Foundation
import AppKit

/// 앱 검색/추가 유틸리티
enum AppFinder {
    /// /Applications + ~/Applications 에 설치된 앱을 스캔
    static func installedApps() -> [AppItem] {
        var apps: [AppItem] = []
        let appURLs = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: NSHomeDirectory() + "/Applications"),
        ]
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
        return apps.filter {
            guard seen.insert($0.bundleID).inserted else { return false }
            return true
        }
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
            category: categorize(bundleID: bundleID, name: name)
        )
    }

    /// 수동 앱 추가 (NSOpenPanel에서 .app 선택)
    static func appItem(fromPicked url: URL) -> AppItem? {
        appItem(from: url)
    }

    /// 번들ID/이름 기준 기본 카테고리 추정
    static func categorize(bundleID: String, name: String) -> AppCategory {
        let lower = (bundleID + " " + name).lowercased()
        let browsers = ["safari", "chrome", "firefox", "whale", "edge", "arc", "brave", "opera"]
        let dev = ["xcode", "terminal", "iterm", "code", "visual studio", "jetbrains", "android studio", "docker", "postman", "github", "sourcetree"]
        let prod = ["notion", "things", "reminders", "calendar", "obsidian", "bear", "notes", "todoist"]
        let comm = ["slack", "discord", "zoom", "teams", "whatsapp", "messages", "kakaotalk", "telegram", "notion"]
        let media = ["music", "spotify", "iina", "vlc", "quicktime", "podcast", "photos", "preview"]

        if browsers.contains(where: { lower.contains($0) }) { return .browser }
        if dev.contains(where: { lower.contains($0) }) { return .developer }
        if prod.contains(where: { lower.contains($0) }) { return .productivity }
        if comm.contains(where: { lower.contains($0) }) { return .communication }
        if media.contains(where: { lower.contains($0) }) { return .media }
        return .uncategorized
    }
}
