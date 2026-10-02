import AppKit

/// 설치 앱 아이콘 캐시 — 팔레트 앱 행 표시용.
/// `NSWorkspace.icon(forFile:)`은 호출당 디스크 조회가 있어 행마다 직접 부르면
/// 스크롤·필터 시 버벅이므로 bundleID 기준으로 메모이즈한다.
enum AppIconCache {
    private static let cache = NSCache<NSString, NSImage>()

    /// 앱 실제 아이콘. 경로가 없거나 파일이 없으면 nil (호출부는 SF Symbol 폴백).
    static func icon(for app: AppItem) -> NSImage? {
        let key = (app.bundleID.isEmpty ? app.path : app.bundleID) as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard !app.path.isEmpty,
              FileManager.default.fileExists(atPath: app.path) else { return nil }
        let img = NSWorkspace.shared.icon(forFile: app.path)
        cache.setObject(img, forKey: key)
        return img
    }
}
