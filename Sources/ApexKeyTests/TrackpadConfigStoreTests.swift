import XCTest
@testable import ApexKey

/// 트랙패드 규칙 **영속화** 테스트 — 인식기 단위 테스트가 못 잡는 저장 경로를 닫는다.
///
/// 실제로 잡은 버그: 로드 중에는 `didSet` 저장을 막는데(`isLoadingTrackpad`),
/// 첫 실행 시드도 그 보호 범위 안에서 일어나 **기본 규칙이 저장되지 않았다.**
/// 결과: 앱을 껐다 켜면 기본 규칙이 사라지고, 시드 플래그만 남아 다시 만들지도 않는다.
/// 그래서 여기서는 "같은 defaults로 ConfigStore를 두 번 만든다"를 반복해서 확인한다.
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

    func testFreshStoreSeedsRightEdgeVolumeSlider() {
        let store = makeStore()
        XCTAssertEqual(store.trackpadSliders.count, 1)
        let rule = store.trackpadSliders[0]
        XCTAssertEqual(rule.edge, .right)
        XCTAssertEqual(rule.fingers, 2)
        XCTAssertEqual(rule.target, .volume)
        XCTAssertTrue(rule.enabled)
        XCTAssertFalse(store.trackpadEnabled, "기본값은 꺼짐이어야 한다")
    }

    /// **회귀** — 시드가 저장되지 않던 버그. 재실행해도 같은 규칙이 남아야 한다.
    func testSeededSliderSurvivesRestart() {
        let first = makeStore()
        let seededID = first.trackpadSliders[0].id

        let second = makeStore()
        XCTAssertEqual(second.trackpadSliders.count, 1, "기본 규칙이 재시작 후 사라졌다")
        XCTAssertEqual(second.trackpadSliders[0].id, seededID, "기본 규칙이 다시 만들어졌다")
    }

    func testDeletedSliderIsNotReseeded() {
        let first = makeStore()
        first.removeTrackpadSlider(id: first.trackpadSliders[0].id)

        let second = makeStore()
        XCTAssertTrue(second.trackpadSliders.isEmpty, "사용자가 지운 규칙을 다시 만들면 안 된다")
    }

    /// **구버전 버그 상태 복구** — `didSeed=1`인데 저장된 배열이 아예 없는 경우
    /// (시드는 메모리에만 들어가고 저장되지 않던 버그). 규칙 0개로 굳지 않고 다시 시드한다.
    func testLegacySeedFlagWithoutDataReseedsOnceAndPersists() {
        defaults.set(true, forKey: ConfigStore.PrefKeys.trackpadDidSeed)
        XCTAssertNil(defaults.data(forKey: ConfigStore.PrefKeys.trackpadSliders))

        let recovered = makeStore()
        XCTAssertEqual(recovered.trackpadSliders.count, 1, "구버전 버그 상태에서 기본 규칙이 복구돼야 한다")

        let next = makeStore()
        XCTAssertEqual(next.trackpadSliders.count, 1, "복구된 규칙이 저장돼야 한다")
        XCTAssertEqual(next.trackpadSliders[0].id, recovered.trackpadSliders[0].id, "재시드로 중복되면 안 된다")
        XCTAssertNotNil(defaults.data(forKey: ConfigStore.PrefKeys.trackpadSliders))
    }

    func testSliderEditsPersist() {
        let first = makeStore()
        var rule = first.trackpadSliders[0]
        rule.edge = .left
        rule.target = .shortcut
        rule.sensitivity = 1.6
        rule.inverted = true
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
            fingers: 3,
            action: GestureAction(kind: .system, systemAction: .wallpaper, systemText: "/tmp/wallpaper.heic")
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
    }

    func testMasterTogglePersists() {
        let first = makeStore()
        first.setTrackpadEnabled(true)

        let second = makeStore()
        XCTAssertTrue(second.trackpadEnabled)
    }

    /// 손상된 JSON이 저장돼 있어도 앱이 죽지 않고 빈 목록으로 시작해야 한다.
    func testCorruptJSONFallsBackToSeed() {
        defaults.set(Data("not json".utf8), forKey: ConfigStore.PrefKeys.trackpadSliders)
        let store = makeStore()
        XCTAssertEqual(store.trackpadSliders.count, 1, "깨진 저장값이면 빈 목록 + 시드여야 한다")
    }

    // MARK: - v0.33.1 기본값 보정

    /// 실기 피드백(너무 예민함 · 두 손가락이 띠에 안 들어감)으로 권장값을 한 번 보정한다.
    func testLegacySeedDefaultsAreTunedOnce() throws {
        let legacy = EdgeSliderRule(edgeWidth: 0.12, startThreshold: 0.06, cooldown: 0.25)
        defaults.set(try JSONEncoder().encode([legacy]), forKey: ConfigStore.PrefKeys.trackpadSliders)
        defaults.set(true, forKey: ConfigStore.PrefKeys.trackpadDidSeed)

        let store = makeStore()
        XCTAssertEqual(store.trackpadSliders[0].edgeWidth, 0.15, accuracy: 0.0001)
        XCTAssertEqual(store.trackpadSliders[0].startThreshold, 0.07, accuracy: 0.0001)
        XCTAssertEqual(store.trackpadSliders[0].cooldown, 0.12, accuracy: 0.0001)
        XCTAssertEqual(store.trackpadSliders[0].id, legacy.id, "규칙 ID는 유지")

        // 두 번째 실행에서는 다시 바꾸지 않는다(사용자가 이후에 만진 값 보존).
        var edited = store.trackpadSliders[0]
        edited.cooldown = 0.4
        store.upsertTrackpadSlider(edited)
        let next = makeStore()
        XCTAssertEqual(next.trackpadSliders[0].cooldown, 0.4, accuracy: 0.0001)
    }

    /// 사용자가 값을 만진 규칙은 보정 대상에서 통째로 제외한다.
    func testTuningLeavesEditedRulesAlone() throws {
        let edited = EdgeSliderRule(edgeWidth: 0.12, startThreshold: 0.06, cooldown: 0.4)
        defaults.set(try JSONEncoder().encode([edited]), forKey: ConfigStore.PrefKeys.trackpadSliders)
        defaults.set(true, forKey: ConfigStore.PrefKeys.trackpadDidSeed)
        defaults.set(1, forKey: ConfigStore.PrefKeys.trackpadTuningVersion)

        let store = makeStore()
        XCTAssertEqual(store.trackpadSliders[0], edited, "만진 규칙은 그대로 둔다")
    }
}
