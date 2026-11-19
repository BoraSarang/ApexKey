import XCTest
@testable import ApexKey

/// 트랙패드 규칙 **영속화** 테스트 — 인식기 단위 테스트가 못 잡는 저장 경로를 닫는다.
///
/// v2(2026-11-19)부터 자동 시드를 만들지 않는다. 사용자가 규칙을 전부 지운 상태를
/// 존중하고, 빈 화면에서 "권장 설정 불러오기"로 명시적으로 만든다.
@MainActor
final class TrackpadConfigStoreTests: XCTestCase {

    private var storeDirectory: URL!
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() async throws {
        try await super.setUp()
        storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ApexKeyTrackpadTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        suiteName = "ApexKeyTrackpadTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
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

    func testFreshStoreStartsEmpty() {
        let store = makeStore()
        XCTAssertTrue(store.trackpadSliders.isEmpty, "자동 시드하지 않는다")
        XCTAssertTrue(store.trackpadGestures.isEmpty)
        XCTAssertFalse(store.trackpadEnabled, "기본값은 꺼짐이어야 한다")
    }

    /// 빈 상태의 "권장 설정 불러오기" — 한 손가락·연속 매핑 규칙 하나.
    func testRecommendedPresetCreatesOneContinuousSliderAndPersists() {
        let first = makeStore()
        first.applyRecommendedTrackpadPreset()

        XCTAssertEqual(first.trackpadSliders.count, 1)
        let rule = first.trackpadSliders[0]
        XCTAssertEqual(rule.edge, .right)
        XCTAssertEqual(rule.fingers, 1)
        XCTAssertEqual(rule.target, .volume)
        XCTAssertEqual(rule.mapping, .continuous)
        XCTAssertEqual(rule.sensitivity, 1.5, accuracy: 0.0001)
        XCTAssertEqual(rule.edgeWidth, 0.07, accuracy: 0.0001)
        XCTAssertEqual(rule.startThreshold, 0.015, accuracy: 0.0001)
        XCTAssertTrue(rule.enabled)

        let second = makeStore()
        XCTAssertEqual(second.trackpadSliders.count, 1, "권장 규칙이 재시작 후 사라졌다")
        XCTAssertEqual(second.trackpadSliders[0].id, rule.id, "권장 규칙이 다시 만들어졌다")
    }

    func testDeletedSliderIsNotReseeded() {
        let first = makeStore()
        first.applyRecommendedTrackpadPreset()
        first.removeTrackpadSlider(id: first.trackpadSliders[0].id)

        let second = makeStore()
        XCTAssertTrue(second.trackpadSliders.isEmpty, "사용자가 지운 규칙을 다시 만들면 안 된다")
    }

    func testSliderEditsPersist() {
        let first = makeStore()
        first.applyRecommendedTrackpadPreset()
        var rule = first.trackpadSliders[0]
        rule.edge = .left
        rule.target = .shortcut
        rule.sensitivity = 1.6
        rule.inverted = true
        rule.modifiers = [.option]
        first.upsertTrackpadSlider(rule)

        let second = makeStore()
        XCTAssertEqual(second.trackpadSliders.first, rule)
    }

    func testGestureWithMenuAndParameterPersists() {
        let first = makeStore()
        let gesture = GestureRule(
            kind: .swipe,
            fingers: 4,
            direction: .down,
            action: GestureAction(
                kind: .menu,
                menuBundleID: "com.apple.Safari",
                menuTitle: "한국어로 번역",
                menuPath: ["보기", "번역", "한국어로 번역"]
            ),
            scope: .apps,
            appBundleIDs: ["com.apple.Safari"]
        )
        let parameterized = GestureRule(
            kind: .tap,
            fingers: 4,
            action: GestureAction(kind: .system, systemAction: .wallpaper, systemText: "/tmp/wallpaper.heic"),
            modifiers: [.command]
        )
        first.upsertTrackpadGesture(gesture)
        first.upsertTrackpadGesture(parameterized)

        let second = makeStore()
        XCTAssertEqual(second.trackpadGestures.count, 2)
        let restored = second.trackpadGestures.first(where: { $0.id == gesture.id })
        XCTAssertEqual(restored, gesture)
        XCTAssertEqual(
            second.trackpadGestures.first(where: { $0.id == parameterized.id })?.action.systemText,
            "/tmp/wallpaper.heic"
        )
        XCTAssertEqual(
            second.trackpadGestures.first(where: { $0.id == parameterized.id })?.modifiers,
            [.command]
        )
    }

    func testMasterTogglePersists() {
        let first = makeStore()
        first.setTrackpadEnabled(true)

        let second = makeStore()
        XCTAssertTrue(second.trackpadEnabled)
    }

    /// 손상된 JSON이 저장돼 있어도 앱이 죽지 않고 빈 목록으로 시작해야 한다.
    func testCorruptJSONFallsBackToEmpty() {
        defaults.set(Data("not json".utf8), forKey: ConfigStore.PrefKeys.trackpadSliders)
        let store = makeStore()
        XCTAssertTrue(store.trackpadSliders.isEmpty, "깨진 저장값이면 빈 목록이어야 한다")
    }

    // MARK: - 기본값 마이그레이션

    /// v0.33.0 시드(12%/6%/250ms)는 v2 프로필까지 한 번에 올라간다.
    func testLegacySeedDefaultsMigrateToV2Profile() throws {
        let legacy = EdgeSliderRule(
            fingers: 2,
            sensitivity: 1.0,
            edgeWidth: 0.12,
            startThreshold: 0.06,
            cooldown: 0.25
        )
        defaults.set(try JSONEncoder().encode([legacy]), forKey: ConfigStore.PrefKeys.trackpadSliders)

        let store = makeStore()
        let migrated = store.trackpadSliders[0]
        XCTAssertEqual(migrated.id, legacy.id, "규칙 ID는 유지")
        XCTAssertEqual(migrated.fingers, 1)
        XCTAssertEqual(migrated.edgeWidth, 0.07, accuracy: 0.0001)
        XCTAssertEqual(migrated.startThreshold, 0.015, accuracy: 0.0001)
        XCTAssertEqual(migrated.sensitivity, 1.5, accuracy: 0.0001)
        XCTAssertEqual(migrated.mapping, .continuous)
    }

    /// v0.33.1 시드(15%/7%/120ms)도 v2 프로필로 올라간다.
    func testV2SeedDefaultsMigrateToContinuousOneFinger() throws {
        let seeded = EdgeSliderRule(
            fingers: 2,
            sensitivity: 1.0,
            edgeWidth: 0.15,
            startThreshold: 0.07,
            cooldown: 0.12,
            mapping: .stepped
        )
        defaults.set(try JSONEncoder().encode([seeded]), forKey: ConfigStore.PrefKeys.trackpadSliders)
        defaults.set(2, forKey: ConfigStore.PrefKeys.trackpadTuningVersion)

        let store = makeStore()
        let migrated = store.trackpadSliders[0]
        XCTAssertEqual(migrated.fingers, 1)
        XCTAssertEqual(migrated.mapping, .continuous)
        XCTAssertEqual(migrated.sensitivity, 1.5, accuracy: 0.0001)
    }

    /// 사용자가 값을 만진 규칙은 마이그레이션에서 통째로 제외한다 — 저장된 동작 보존.
    func testTuningLeavesEditedRulesAlone() throws {
        let edited = EdgeSliderRule(
            fingers: 2,
            sensitivity: 1.2,
            edgeWidth: 0.12,
            startThreshold: 0.06,
            cooldown: 0.4,
            mapping: .stepped
        )
        defaults.set(try JSONEncoder().encode([edited]), forKey: ConfigStore.PrefKeys.trackpadSliders)
        defaults.set(1, forKey: ConfigStore.PrefKeys.trackpadTuningVersion)

        let store = makeStore()
        XCTAssertEqual(store.trackpadSliders[0], edited, "만진 규칙은 그대로 둔다")
        XCTAssertEqual(store.trackpadSliders[0].mapping, .stepped)
    }

    /// 마이그레이션은 한 번만 — 이후 사용자가 만진 값은 재시작해도 유지된다.
    func testMigrationRunsOnce() throws {
        let seeded = EdgeSliderRule(
            fingers: 2,
            sensitivity: 1.0,
            edgeWidth: 0.15,
            startThreshold: 0.07,
            cooldown: 0.12
        )
        defaults.set(try JSONEncoder().encode([seeded]), forKey: ConfigStore.PrefKeys.trackpadSliders)

        let store = makeStore()
        var edited = store.trackpadSliders[0]
        edited.cooldown = 0.4
        store.upsertTrackpadSlider(edited)

        let next = makeStore()
        XCTAssertEqual(next.trackpadSliders[0].cooldown, 0.4, accuracy: 0.0001)
        XCTAssertEqual(next.trackpadSliders[0].fingers, 1)
    }
}
