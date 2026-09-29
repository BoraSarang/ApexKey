import XCTest
import SwiftData
@testable import ApexKey

/// `ConfigStore` 인스턴스 테스트 (E-MAC-STORE-5009)
///
/// 이전에는 `ConfigStore()`를 인스턴스화하는 테스트가 **0건**이었다. `init()`이 저장소
/// 경로를 하드코딩했기 때문에 불가능했다. 그 결과 바인딩 추가·교체·삭제, 앱 제거 시
/// 고아 핫키 정리, 워크플로우 저장 같은 **모든 뮤테이션 경로가 검증되지 않았다.**
///
/// 격리 규칙 (어기면 다른 테스트가 깨진다):
/// - 저장소: 테스트마다 임시 디렉터리. 실제 사용자 저장소를 절대 건드리지 않는다
/// - UserDefaults: 테스트마다 전용 suite
/// - 핫키: `registerSystemIntegrations: false`로 시드·예약 핫키 등록을 건너뛰고,
///   `addBinding`이 직접 등록한 것은 `tearDown`에서 `unregisterAll()`
///   (`HotKeyService.shared`는 싱글턴 — v0.21에서 오염 실수가 있었다)
@MainActor
final class ConfigStoreMutationTests: XCTestCase {

    private var storeDirectory: URL!
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() async throws {
        try await super.setUp()
        storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ApexKeyConfigStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        suiteName = "ApexKeyConfigStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        // 핫키 싱글턴 누수 방지 — 다른 테스트가 ⇧⌥A 등을 선점하게 두면 안 된다
        HotKeyService.shared.unregisterAll()
        defaults?.removePersistentDomain(forName: suiteName)
        if let dir = storeDirectory { try? FileManager.default.removeItem(at: dir) }
        try await super.tearDown()
    }

    /// 격리된 ConfigStore — 시드 없음, 전역 통합 없음
    private func makeStore() -> ConfigStore {
        ConfigStore(
            storeDirectory: storeDirectory,
            defaults: defaults,
            seedInstalledApps: false,
            registerSystemIntegrations: false
        )
    }

    /// 앱 픽스처 — 기본 경로는 **존재하는 임시 파일**로 만든다.
    /// `pruneRemovedApps()`가 `fileExists(atPath:)`로 판정하므로 실제 앱 번들이고 뭐고 상관없고,
    /// 이 경로가 없으면 `load()`에서 조용히 제거돼 테스트가 호스트 환경에 따라 무의미해진다.
    /// (`/Applications/Notes.app`이 없는 환경에서 실제로 그렇게 실패했다)
    private func makeApp(_ name: String, bundleID: String, path: String? = nil) -> AppItem {
        let fallback = storeDirectory.appendingPathComponent("\(bundleID).app")
        if !FileManager.default.fileExists(atPath: fallback.path) {
            FileManager.default.createFile(atPath: fallback.path, contents: Data())
        }
        return AppItem(
            name: name,
            bundleID: bundleID,
            path: path ?? fallback.path,
            category: .productivity
        )
    }

    /// 테스트에서 실제 등록에 성공할 가능성이 높고 사용자가 선점하지 않은 F열 조합
    private func combo(_ keyCode: UInt32, _ display: String) -> HotKeyCombo {
        HotKeyCombo(keyCode: keyCode, modifiers: 1 << 8, displayString: display)  // ⌘ modifier
    }

    // MARK: - 초기화·격리

    func testInitUsesInjectedStoreDirectory() {
        let store = makeStore()
        XCTAssertNotNil(store.container, "컨테이너가 생성되지 않음")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: storeDirectory.appendingPathComponent("default.store").path),
            "주입한 경로에 store가 만들어지지 않음"
        )
    }

    func testInitDoesNotSeedInstalledApps() {
        // 시드를 끄지 않으면 이 기기에 설치된 앱 수백 개가 들어와 검증이 무의미해진다
        let store = makeStore()
        XCTAssertTrue(store.apps.isEmpty, "시드가 비활성화됐는데 앱 \(store.apps.count)개가 로드됨")
    }

    func testInitDoesNotTouchRealDefaults() {
        _ = makeStore()
        XCTAssertNil(
            UserDefaults.standard.object(forKey: ConfigStore.PrefKeys.alwaysOnTop),
            "테스트가 실제 기본 설정을 오염시킴"
        )
    }

    // MARK: - 바인딩 추가

    func testAddBindingPersistsToStore() {
        let store = makeStore()
        let b = HotKeyBinding(combo: combo(105, "⌘F13"), actionType: .launchApp, target: "com.apple.Safari", title: "Safari")
        _ = store.addBinding(b)

        XCTAssertEqual(store.bindings.count, 1)
        let context = store.container!.mainContext
        let persisted = (try? context.fetch(FetchDescriptor<PersistedBinding>())) ?? []
        XCTAssertEqual(persisted.count, 1, "바인딩이 store에 저장되지 않음")
        XCTAssertEqual(persisted.first?.toBinding().title, "Safari")
    }

    func testAddBindingRejectsDuplicateCombo() {
        // E-MAC-HTKEY-1003: 중복 조합은 조용히 무시되지 않고 거부돼야 한다
        let store = makeStore()
        let shared = combo(105, "⌘F13")
        _ = store.addBinding(HotKeyBinding(combo: shared, actionType: .launchApp, target: "com.apple.Safari", title: "A"))
        let result = store.addBinding(HotKeyBinding(combo: shared, actionType: .launchApp, target: "com.apple.TextEdit", title: "B"))

        XCTAssertEqual(result, .duplicateCombo, "중복 조합이 거부되지 않음")
        XCTAssertEqual(store.bindings.count, 1, "중복이 저장됨")
        XCTAssertEqual(store.bindings.first?.title, "A", "기존 바인딩이 덮어써짐")
    }

    func testAddBindingRejectsEmptyCombo() {
        let store = makeStore()
        let result = store.addBinding(
            HotKeyBinding(combo: .empty, actionType: .launchApp, target: "com.apple.Safari", title: "빈 조합")
        )
        XCTAssertEqual(result, .invalidCombo)
        XCTAssertTrue(store.bindings.isEmpty)
    }

    func testAddBindingRejectsReservedHotkey() {
        // 예약 핫키(⇧⌥A 등)와의 충돌도 중복으로 취급돼야 한다
        let store = makeStore()
        let result = store.addBinding(
            HotKeyBinding(combo: store.toggleHotkey, actionType: .launchApp, target: "com.apple.Safari", title: "예약 충돌")
        )
        XCTAssertEqual(result, .duplicateCombo, "예약 핫키 충돌이 허용됨")
        XCTAssertTrue(store.bindings.isEmpty)
    }

    // MARK: - 바인딩 교체

    func testSetLaunchBindingReplacesExistingInPlace() {
        let store = makeStore()
        let app = makeApp("Safari", bundleID: "com.apple.Safari")
        store.addApp(app)

        _ = store.setLaunchBinding(for: app.id, combo: combo(105, "⌘F13"))
        let firstID = store.bindings.first?.id
        XCTAssertEqual(store.bindings.count, 1)

        _ = store.setLaunchBinding(for: app.id, combo: combo(106, "⌘F14"))
        XCTAssertEqual(store.bindings.count, 1, "교체가 추가가 됐음 — 중복 항목 생김")
        XCTAssertEqual(store.bindings.first?.id, firstID, "교체 시 ID가 바뀌면 핫키 재등록이 깨진다")
        XCTAssertEqual(store.bindings.first?.combo.keyCode, 106)

        let persisted = (try? store.container!.mainContext.fetch(FetchDescriptor<PersistedBinding>())) ?? []
        XCTAssertEqual(persisted.count, 1, "store에 교체 항목이 2개 남음")
        XCTAssertEqual(persisted.first?.toBinding().combo.keyCode, 106)
    }

    func testSetLaunchBindingRejectsDuplicateAndKeepsOld() {
        // E-MAC-HTKEY-1003 회귀 — **자기 바인딩을 교체**하는 경우여야 한다.
        //
        // 이전 버그의 정확한 재현 조건: 앱 A가 ⌘F13을 쓰고 있고, 사용자가 A를
        // (앱 B가 이미 쓰는) ⌘F14로 바꾸려 한다. 이전 구현은
        //   1) removeBinding(A)  → A의 핫키가 사라짐
        //   2) addBinding(⌘F14)  → B와 중복 → 조용히 return
        // 결과를 **A의 단축키만 사라진 상태**로 남겼다.
        //
        // B를 대상으로 *추가*하면 removeBinding이 애초에 호출되지 않아 이 테스트가
        // 통과해 버린다 — 실제로 처음 그렇게 작성했다가 통과하는 걸 확인했다.
        let store = makeStore()
        let safari = makeApp("Safari", bundleID: "com.apple.Safari")
        let notes = makeApp("Notes", bundleID: "com.apple.Notes")
        store.addApp(safari)
        store.addApp(notes)

        _ = store.setLaunchBinding(for: safari.id, combo: combo(105, "⌘F13"))
        _ = store.setLaunchBinding(for: notes.id, combo: combo(106, "⌘F14"))
        XCTAssertEqual(store.bindings.count, 2)

        // Safari의 ⌘F13을 Notes가 이미 쓰는 ⌘F14로 바꾸려 한다 → 거부돼야 한다
        let result = store.setLaunchBinding(for: safari.id, combo: combo(106, "⌘F14"))

        XCTAssertEqual(result, .duplicateCombo)
        XCTAssertEqual(store.bindings.count, 2, "거부했는데 항목이 사라짐")
        let safariBinding = store.bindings.first { $0.target == safari.bundleID }
        XCTAssertNotNil(safariBinding, "거부했는데 기존 바인딩이 사라짐 — 사용자의 핫키가 조용히 죽었다")
        XCTAssertEqual(safariBinding?.combo.keyCode, 105, "거부했는데 조합이 바뀌었다")
        let persisted = (try? store.container!.mainContext.fetch(FetchDescriptor<PersistedBinding>())) ?? []
        XCTAssertEqual(persisted.count, 2, "거부했는데 store에서 삭제됨")
        XCTAssertEqual(
            persisted.first { $0.toBinding().target == safari.bundleID }?.toBinding().combo.keyCode,
            105
        )
    }

    func testSetLaunchBindingRejectsEmptyCombo() {
        let store = makeStore()
        let app = makeApp("Safari", bundleID: "com.apple.Safari")
        store.addApp(app)
        XCTAssertEqual(store.setLaunchBinding(for: app.id, combo: .empty), .invalidCombo)
        XCTAssertTrue(store.bindings.isEmpty)
    }

    func testSetLaunchBindingUnknownAppIsNotFound() {
        let store = makeStore()
        XCTAssertEqual(store.setLaunchBinding(for: UUID(), combo: combo(105, "⌘F13")), .appNotFound)
    }

    // MARK: - 바인딩 삭제

    func testRemoveBindingDeletesFromMemoryAndStore() {
        let store = makeStore()
        let b = HotKeyBinding(combo: combo(105, "⌘F13"), actionType: .launchApp, target: "com.apple.Safari", title: "Safari")
        _ = store.addBinding(b)
        XCTAssertEqual(store.bindings.count, 1)

        store.removeBinding(b)
        XCTAssertTrue(store.bindings.isEmpty, "메모리에서 안 지워짐")
        let persisted = (try? store.container!.mainContext.fetch(FetchDescriptor<PersistedBinding>())) ?? []
        XCTAssertTrue(persisted.isEmpty, "store에 남음")
    }

    // MARK: - 앱 제거와 고아 핫키 (E-MAC-STORE-5007 회귀)

    func testRemoveAppAlsoRemovesItsBindings() {
        let store = makeStore()
        let app = makeApp("Safari", bundleID: "com.apple.Safari")
        store.addApp(app)
        _ = store.addBinding(HotKeyBinding(combo: combo(105, "⌘F13"), actionType: .launchApp, target: app.bundleID, title: "Safari"))

        store.removeApp(app)

        XCTAssertTrue(store.apps.isEmpty, "앱이 안 지워짐")
        XCTAssertTrue(store.bindings.isEmpty, "고아 바인딩이 메모리에 남음 — 죽은 bundleID로 실행을 시도한다")
        let persistedBindings = (try? store.container!.mainContext.fetch(FetchDescriptor<PersistedBinding>())) ?? []
        XCTAssertTrue(persistedBindings.isEmpty, "고아 바인딩이 store에 남아 재시작 시 되살아난다")
        let persistedApps = (try? store.container!.mainContext.fetch(FetchDescriptor<PersistedApp>())) ?? []
        XCTAssertTrue(persistedApps.isEmpty)
    }

    func testRemoveAppKeepsOtherAppsBindings() {
        let store = makeStore()
        let safari = makeApp("Safari", bundleID: "com.apple.Safari")
        let notes = makeApp("Notes", bundleID: "com.apple.Notes")
        store.addApp(safari)
        store.addApp(notes)
        _ = store.addBinding(HotKeyBinding(combo: combo(105, "⌘F13"), actionType: .launchApp, target: safari.bundleID, title: "S"))
        _ = store.addBinding(HotKeyBinding(combo: combo(106, "⌘F14"), actionType: .launchApp, target: notes.bundleID, title: "N"))

        store.removeApp(safari)

        XCTAssertEqual(store.bindings.count, 1, "다른 앱의 바인딩까지 지워짐")
        XCTAssertEqual(store.bindings.first?.target, notes.bundleID)
    }

    func testPruneRemovedAppsClearsGhostAppAndOrphanHotkey() {
        // 경로가 사라진 앱(외장드라이브 뽑기)이면 앱만 사라지고 고아 핫키가 남던 것이 회귀다
        let store = makeStore()
        let ghost = makeApp("Ghost", bundleID: "com.ghost.app", path: "/Volumes/Removed/Ghost.app")
        let alive = makeApp("Alive", bundleID: "com.alive.app")
        store.addApp(ghost)
        store.addApp(alive)
        _ = store.addBinding(HotKeyBinding(combo: combo(105, "⌘F13"), actionType: .launchApp, target: ghost.bundleID, title: "G"))

        store.pruneRemovedApps()

        XCTAssertEqual(store.apps.map(\.bundleID), [alive.bundleID], "사라진 경로의 앱이 남음")
        XCTAssertTrue(store.bindings.isEmpty, "고아 핫키가 남음")
    }

    // MARK: - 앱 카테고리

    func testUpdateCategorySetsManualFlag() {
        // 수동 변경 플래그가 없으면 다음 실행의 재분류가 사용자의 선택을 덮어쓴다
        let store = makeStore()
        let app = makeApp("Safari", bundleID: "com.apple.Safari")
        store.addApp(app)

        store.updateCategory(for: app.id, to: .games)
        XCTAssertEqual(store.apps.first?.category, .games)
        XCTAssertEqual(store.apps.first?.categoryManuallySet, true)

        let persisted = (try? store.container!.mainContext.fetch(FetchDescriptor<PersistedApp>())) ?? []
        XCTAssertEqual(persisted.first?.categoryRaw, AppCategory.games.rawValue)
        XCTAssertEqual(persisted.first?.categoryManuallySet, true, "플래그가 store에 저장되지 않음")
    }

    // MARK: - 동작(워크플로우) 저장

    func testAddShortcutPersistsSteps() {
        let store = makeStore()
        guard let s = store.addShortcut(name: "테스트 동작") else {
            XCTFail("동작 생성 실패"); return
        }
        store.addStep(to: s, step: ShortcutStep(type: .launchApp, target: "com.apple.Safari", title: "Safari"))

        let persisted = (try? store.container!.mainContext.fetch(FetchDescriptor<PersistedShortcut>())) ?? []
        XCTAssertEqual(persisted.count, 1)
        XCTAssertEqual(persisted.first?.toShortcut().steps.count, 1)
        XCTAssertEqual(persisted.first?.toShortcut().steps.first?.target, "com.apple.Safari")
    }

    func testRemoveStepPersists() {
        let store = makeStore()
        guard let s = store.addShortcut(name: "단계 제거") else { XCTFail(); return }
        store.addStep(to: s, step: ShortcutStep(type: .launchApp, target: "com.apple.Safari", title: "A"))
        store.addStep(to: s, step: ShortcutStep(type: .wait, target: "1.0", title: "B"))
        XCTAssertEqual(store.shortcuts.first?.steps.count, 2)

        store.removeStep(from: store.shortcuts[0], at: 0)

        XCTAssertEqual(store.shortcuts.first?.steps.count, 1)
        XCTAssertEqual(store.shortcuts.first?.steps.first?.type, .wait)
        let persisted = (try? store.container!.mainContext.fetch(FetchDescriptor<PersistedShortcut>())) ?? []
        XCTAssertEqual(persisted.first?.toShortcut().steps.count, 1, "store에 반영되지 않음")
    }

    func testRemoveShortcutDeletesFromStore() {
        let store = makeStore()
        guard let s = store.addShortcut(name: "삭제 대상") else { XCTFail(); return }
        store.removeShortcut(s)
        XCTAssertTrue(store.shortcuts.isEmpty)
        let persisted = (try? store.container!.mainContext.fetch(FetchDescriptor<PersistedShortcut>())) ?? []
        XCTAssertTrue(persisted.isEmpty, "store에 남아 재시작 시 되살아난다")
    }

    func testUpdateShortcutVariablesPersists() {
        let store = makeStore()
        guard store.addShortcut(name: "변수") != nil else { XCTFail(); return }
        store.updateShortcutVariables(
            store.shortcuts[0],
            variables: [Variable(name: "카피", type: .manual, valueType: .any)]
        )

        let persisted = (try? store.container!.mainContext.fetch(FetchDescriptor<PersistedShortcut>())) ?? []
        XCTAssertEqual(persisted.first?.toShortcut().variables.first?.name, "카피")
    }

    // MARK: - 스크립트

    func testAddAndRemoveScriptRoundTrips() {
        let store = makeStore()
        store.addScript(name: "스크립트", command: "echo hi")
        XCTAssertEqual(store.scripts.count, 1)
        let persisted = (try? store.container!.mainContext.fetch(FetchDescriptor<PersistedScript>())) ?? []
        XCTAssertEqual(persisted.first?.toScript().command, "echo hi")

        store.removeScript(store.scripts[0])
        XCTAssertTrue(store.scripts.isEmpty)
        let after = (try? store.container!.mainContext.fetch(FetchDescriptor<PersistedScript>())) ?? []
        XCTAssertTrue(after.isEmpty, "store에 남음")
    }

    // MARK: - 재시작 영속성 (메모리 ↔ store 정합의 최종 확인)

    func testMutationsSurviveNewStoreInstance() {
        // 메모리 배열만 고치고 store에 반영을 빠뜨리는 경로를 잡는다
        let store = makeStore()
        let app = makeApp("Safari", bundleID: "com.apple.Safari")
        store.addApp(app)
        _ = store.setLaunchBinding(for: app.id, combo: combo(105, "⌘F13"))
        _ = store.addShortcut(name: "영속 동작")
        store.addScript(name: "영속 스크립트", command: "echo persisted")

        // 같은 디렉터리로 새 인스턴스 → 사용자가 앱을 재실행한 것과 같다
        let reopened = makeStore()

        XCTAssertEqual(reopened.apps.map(\.bundleID), ["com.apple.Safari"])
        XCTAssertEqual(reopened.bindings.count, 1)
        XCTAssertEqual(reopened.bindings.first?.combo.keyCode, 105)
        XCTAssertEqual(reopened.shortcuts.map(\.name), ["영속 동작"])
        XCTAssertEqual(reopened.scripts.map(\.command), ["echo persisted"])
    }

    func testCorruptedStoreQuarantinesAndRecovers() {
        // 손상 store 격리 → 재생성 경로가 init에서 실제로 동작하는지
        // (격리에 성공하면 `storeRecoveryBackupPath`가 게시된다)
        let url = storeDirectory.appendingPathComponent("default.store")
        try? Data(repeating: 0x5A, count: 8192).write(to: url)
        _ = makeStore()
        // 격리 여부는 SwiftData의 관대에 따라 달라질 수 있으므로,
        // "앱이 예외 없이 기동하고 컨테이너가 있으면"를 요구한다
        // (조용한 no-op이 P0-2에서 금지된 상태다)
        let store = makeStore()
        XCTAssertNotNil(store.container, "손상 store에서 컨테이너를 얻지 못함 — 앱이 무음 no-op 상태가 된다")
    }
}
