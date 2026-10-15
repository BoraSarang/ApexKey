import XCTest
@testable import ApexKey

/// 워크플로우 목록 순서 (T-192). 저장소·defaults 격리 (ConfigStoreMutationTests 규칙 준수).
@MainActor
final class ShortcutOrderTests: XCTestCase {

    private var storeDirectory: URL!
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() async throws {
        try await super.setUp()
        storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ApexKeyShortcutOrderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        suiteName = "ApexKeyShortcutOrderTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        HotKeyService.shared.unregisterAll()
        defaults?.removePersistentDomain(forName: suiteName)
        if let dir = storeDirectory { try? FileManager.default.removeItem(at: dir) }
        try await super.tearDown()
    }

    private func makeStore() -> ConfigStore {
        ConfigStore(
            storeDirectory: storeDirectory,
            defaults: defaults,
            seedInstalledApps: false,
            registerSystemIntegrations: false
        )
    }

    func testMoveShortcutsReordersAndPersists() {
        let store = makeStore()
        let a = store.addShortcut(name: "A")!
        let b = store.addShortcut(name: "B")!
        let c = store.addShortcut(name: "C")!
        XCTAssertEqual(store.shortcuts.map(\.id), [a.id, b.id, c.id])

        // A를 끝으로: List onMove 의미 ([0],3)
        store.moveShortcuts(from: IndexSet([0]), to: 3)
        XCTAssertEqual(store.shortcuts.map(\.name), ["B", "C", "A"])

        // 저장된 순서가 그대로 복원되는지 (재로드 없이 정렬 로직으로 검증)
        let saved = defaults.array(forKey: "pref.shortcutOrder") as? [String]
        XCTAssertEqual(saved, [b.id.uuidString, c.id.uuidString, a.id.uuidString])

        // 순서 섞은 뒤 apply가 저장 순서로 되돌림
        store.shortcuts.swapAt(0, 2)
        store.applyShortcutOrder()
        XCTAssertEqual(store.shortcuts.map(\.name), ["B", "C", "A"])
    }

    func testRemoveShortcutPrunesSavedOrder() {
        let store = makeStore()
        let a = store.addShortcut(name: "A")!
        let b = store.addShortcut(name: "B")!
        store.removeShortcut(a)
        let saved = defaults.array(forKey: "pref.shortcutOrder") as? [String]
        XCTAssertEqual(saved, [b.id.uuidString])
    }

    func testApplyKeepsUnknownIDsLast() {
        let store = makeStore()
        let a = store.addShortcut(name: "A")!
        let b = store.addShortcut(name: "B")!
        // 저장분에는 A만 있고 B는 신규처럼 취급
        defaults.set([a.id.uuidString], forKey: "pref.shortcutOrder")
        store.shortcuts.swapAt(0, 1)
        store.applyShortcutOrder()
        XCTAssertEqual(store.shortcuts.map(\.id), [a.id, b.id])
    }
}
