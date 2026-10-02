import Foundation

/// 팔레트 앱 실행 기록 — UserDefaults 영속 (자주 쓰는 앱/최근 사용 섹션용).
/// 워크플로우와 달리 AppItem에는 실행 통계가 없으므로 별도 저장한다.
enum PaletteAppRecents {
    struct Entry: Codable, Equatable {
        var bundleID: String
        var name: String
        var path: String
        var count: Int
        var lastUsed: Date
    }

    static let maxRecents = 5
    static let maxFrequent = 5
    private static let storeKey = "PaletteAppRecents.v1"
    private static let clearedAtKey = "PaletteRecentsClearedAt.v1"

    // MARK: - 기록

    static func record(bundleID: String, name: String, path: String, defaults: UserDefaults = .standard) {
        var all = loadAll(defaults: defaults)
        if var e = all[bundleID] {
            e.count += 1
            e.lastUsed = Date()
            e.name = name
            e.path = path
            all[bundleID] = e
        } else {
            all[bundleID] = Entry(bundleID: bundleID, name: name, path: path, count: 1, lastUsed: Date())
        }
        save(all, defaults: defaults)
    }

    /// 최근 사용 지우기 — 앱 기록 삭제 + 워크플로우 최근 숨김 기준시각 갱신.
    /// 워크플로우 `lastRunAt` 통계는 건드리지 않는다 (표시만 숨김, 이후 실행분부터 재노출).
    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storeKey)
        defaults.set(Date().timeIntervalSince1970, forKey: clearedAtKey)
    }

    static func clearedAt(defaults: UserDefaults = .standard) -> Date {
        Date(timeIntervalSince1970: defaults.double(forKey: clearedAtKey))
    }

    // MARK: - 조회 (순수 정렬 — 테스트 대상)

    static func recents(defaults: UserDefaults = .standard, max: Int = maxRecents) -> [Entry] {
        loadAll(defaults: defaults).values
            .sorted { $0.lastUsed > $1.lastUsed }
            .prefix(max)
            .map { $0 }
    }

    static func frequent(defaults: UserDefaults = .standard, max: Int = maxFrequent) -> [Entry] {
        loadAll(defaults: defaults).values
            .filter { $0.count > 1 }
            .sorted { ($0.count, $0.lastUsed) > ($1.count, $1.lastUsed) }
            .prefix(max)
            .map { $0 }
    }

    // MARK: - 영속

    private static func loadAll(defaults: UserDefaults) -> [String: Entry] {
        guard let data = defaults.data(forKey: storeKey),
              let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private static func save(_ all: [String: Entry], defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(all) {
            defaults.set(data, forKey: storeKey)
        }
    }
}

/// 워크플로우 자주 사용 (runCount 순, 최근 섹션과 중복 제외) — 순수 함수, 테스트 대상.
enum PaletteWorkflowRank {
    static func frequent(from shortcuts: [ShortcutItem], excluding recentIDs: Set<UUID>, max: Int = 5) -> [ShortcutItem] {
        shortcuts
            .filter { $0.runCount > 0 && !recentIDs.contains($0.id) }
            .sorted { ($0.runCount, $0.lastRunAt ?? .distantPast) > ($1.runCount, $1.lastRunAt ?? .distantPast) }
            .prefix(max)
            .map { $0 }
    }

    /// 지우기 이후 실행분만 최근으로 노출 (통계는 유지).
    static func visibleRecents(from recents: [ShortcutItem], clearedAt: Date) -> [ShortcutItem] {
        recents.filter { ($0.lastRunAt ?? .distantPast) > clearedAt }
    }
}
