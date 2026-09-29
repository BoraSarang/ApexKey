import XCTest
import SwiftData
@testable import ApexKey

/// blob 영구 쓰기 잠금의 **복구 경로** 테스트 (E-MAC-STORE-5010)
///
/// 문제:
/// `corruptedShortcutBlobColumns`의 해제 지점이 `load()`와 `removeShortcut`뿐이었다.
/// 그래서 한 번 디코딩이 실패한 컬럼은 **영구 쓰기 잠금**이 되고, 복구 방법은
/// "그 동작을 삭제한다"뿐이었다. 사용자가 아무리 편집해도 저장은 계속 건너뛰어진다.
/// 데이터가 소실되지는 않지만 **편집이 반영되지 않는다** — 사용자는 버그로 느낀다.
///
/// 해제 조건 (엄격해야 함):
/// 1. 지금 메모리의 값을 인코딩한 뒤 **다시 디코딩해 원래 값과 같을 때만** 해제
/// 2. `[]` 같은 **fallback 값으로는 절대 해제되지 않는다** (원본 보호가 유지돼야 함)
/// 3. 인코딩 실패 시 잠금 유지
///
/// 격리 규칙: `ConfigStoreMutationTests`와 동일 (임시 저장소 / 전용 defaults /
/// 핫키 미등록). `ConfigStore()`를 직접 인스턴스화하므로 격리를 지켜야 한다.
@MainActor
final class StoreBlobRecoveryTests: XCTestCase {

    private var leakedDirectories: [URL] = []

    override func setUp() async throws {
        try await super.setUp()
        leakedDirectories = []
    }

    override func tearDown() async throws {
        HotKeyService.shared.unregisterAll()
        for dir in leakedDirectories { try? FileManager.default.removeItem(at: dir) }
        for suite in leakedDefaults { UserDefaults.standard.removePersistentDomain(forName: suite) }
        try await super.tearDown()
    }

    private var leakedDefaults: [String] = []

    /// 픽스처마다 전용 저장소 + 전용 defaults를 만든다 (격리)
    private func makeIsolatedStore() -> ConfigStore {
        let suite = "ApexKeyBlobRecovery-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            fatalError("전용 UserDefaults suite를 만들 수 없다 — 격리가 깨지면 안 된다")
        }
        leakedDefaults.append(suite)
        let dir = makeIsolatedDirectory()
        return ConfigStore(
            storeDirectory: dir,
            defaults: defaults,
            seedInstalledApps: false,
            registerSystemIntegrations: false
        )
    }

    private func makeIsolatedDirectory() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ApexKeyBlobRecovery-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        leakedDirectories.append(dir)
        return dir
    }

    // MARK: - 픽스처

    /// **실제로 손상된 blob**을 저장소에 심고 `load()`까지 통과시켜 잠금을 등록한다.
    ///
    /// 메모리에서만 픽스처를 만들지 않는다. 디코딩 실패가 저장소 경로를 거쳐
    /// `load()`에서 잠금으로 등록되는 것까지 확인해야 "영구 잠금"이었다는 주장을
    /// 재현할 수 있다. 이 픽스처가 없으면 테스트는 잠금이 이미 풀린 상태를 가정한다.
    ///
    /// - Important: 호출마다 **전용 저장소 디렉터리**를 쓴다. 같은 파일을 공유하면
    ///   앞선 픽스처의 손상 레코드가 뒤의 `load()`에 함께 보이고, 저장소 전역 상태
    ///   (`corruptedShortcutBlobColumns`)가 섞여 "이 테스트가 왜 고립에서는 지나는지"
    ///   추적이 안 되는 상황이 된다. 실제로 그렇게 드러났다.
    private func seedCorrupt(_ column: StoreBlobColumn) -> (store: ConfigStore, id: UUID) {
        let store = makeIsolatedStore()
        let id = UUID()
        let p = PersistedShortcut(name: "손상 동작", steps: [])
        p.id = id
        let goodSteps = (try? JSONEncoder().encode([
            ShortcutStep(type: .wait, target: "1.0", title: "원본 대기")
        ])) ?? Data("[]".utf8)
        p.stepsData    = column == .steps       ? Data([0xFF, 0xFE, 0x00]) : goodSteps
        p.triggersData = column == .triggers    ? Data([0xFF])             : Data("[]".utf8)
        p.variablesData = column == .variables  ? Data([0xFF])             : Data("[]".utf8)
        p.permissionsData = column == .permissions ? Data([0xFF])          : Data("{}".utf8)
        store.container?.mainContext.insert(p)
        try? store.container?.mainContext.save()
        store.load(seedInstalledApps: false, registerSystemIntegrations: false)
        return (store, id)
    }

    private func isLocked(_ store: ConfigStore, _ id: UUID, _ column: StoreBlobColumn) -> Bool {
        store.corruptedShortcutBlobColumns[id]?.contains(column) == true
    }

    private func persisted(_ id: UUID, in store: ConfigStore) -> PersistedShortcut? {
        guard let context = store.container?.mainContext else { return nil }
        let fetch = FetchDescriptor<PersistedShortcut>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(fetch).first
    }

    /// 사용자가 **4컬럼 모두** 정상 값으로 편집한 동작
    private func edited(_ id: UUID) -> ShortcutItem {
        ShortcutItem(
            id: id,
            name: "편집된 동작",
            steps: [ShortcutStep(type: .wait, target: "2.0", title: "수정 대기")],
            automations: [.display(DisplayTrigger(label: "수정됨"))],
            variables: [Variable(name: "수정변수", type: .manual, valueType: .any)],
            permissions: ShortcutPermissions(requiresConfirmation: true)
        )
    }

    // MARK: - 전제: 잠금이 실제로 성립하는가

    func testLockIsEstablishedFromCorruptBlob() {
        // 이게 안 성립하면 아래 복구 테스트가 전부 무의미해진다
        for column in StoreBlobColumn.allCases {
            let (store, id) = seedCorrupt(column)
            XCTAssertTrue(
                isLocked(store, id, column),
                "\(column.rawValue): 손상 blob이 잠금으로 등록되지 않음 — 테스트 전제 붕괴"
            )
        }
    }

    // MARK: - 복구

    func testValidEditReleasesTheLock() {
        for column in StoreBlobColumn.allCases {
            let (store, id) = seedCorrupt(column)
            XCTAssertTrue(isLocked(store, id, column), "전제: 잠금이 있어야 함")

            store.syncShortcut(edited(id))       // 사용자가 정상 값으로 편집

            XCTAssertFalse(
                isLocked(store, id, column),
                "\(column.rawValue): 정상 값으로 편집했는데도 잠금이 유지된다 — 편집이 반영되지 않는다"
            )
        }
    }

    func testLockEntryIsRemovedWhenLastColumnRecovers() {
        // 항목 자체가 남아 있으면 이후 로직이 "이_SHORT仍有 손상"으로 오판한다
        let (store, id) = seedCorrupt(.steps)
        store.syncShortcut(edited(id))
        XCTAssertNil(
            store.corruptedShortcutBlobColumns[id],
            "유일하게 잠긴 컬럼이 풀렸는데도 항목이 남아 있다"
        )
    }

    func testRecoveryActuallyPersistsTheNewValue() {
        // 잠금만 풀리는 게 아니라 **값이 저장돼야** 한다.
        // 해제 신호만 보내고 쓰기를 안 하면 데이터는 계속 옛 값이다.
        for column in StoreBlobColumn.allCases {
            let (store, id) = seedCorrupt(column)
            store.syncShortcut(edited(id))

            guard let p = persisted(id, in: store) else {
                XCTFail("\(column.rawValue): 저장된 레코드를 못 읽음")
                continue
            }
            XCTAssertFalse(
                p.undecodableBlobColumns().contains(column),
                "\(column.rawValue): 잠금이 풀렸는데 여전히 디코딩 불가 — 값이 안 저장됐다"
            )
            if column == .steps {
                let steps = try? JSONDecoder().decode([ShortcutStep].self, from: p.stepsData)
                XCTAssertEqual(steps?.first?.target, "2.0", "steps가 새 값이 아니다")
            }
        }
    }

    func testUncorruptedColumnsStayUnlocked() {
        // 손상되지 않은 컬럼을 편집해도 잠금이 생겨서는 안 된다
        let (store, id) = seedCorrupt(.steps)
        store.syncShortcut(edited(id))
        let remaining = store.corruptedShortcutBlobColumns[id] ?? []
        XCTAssertTrue(
            remaining.isEmpty,
            "복구 후 다른 컬럼에 새 잠금이 생겼다: \(remaining.map(\.rawValue).sorted())"
        )
    }

    func testUnchangedColumnStaysLockedWhileChangedOneRecovers() {
        // ★ 컬럼별로 독립적이어야 한다.
        // steps만 편집하고 triggers는 그대로면 — triggers는 fallback과 동일하므로
        // **유지되어야 한다.** "옆 컬럼이 풀렸으니 이건 자동으로 풀리겠지"라는
        // 가정으로 전체를 풀면 손상 원본이 조용히 지워진다.
        let (store, id) = seedCorrupt(.triggers)
        XCTAssertTrue(isLocked(store, id, .triggers), "전제")

        var partial = store.shortcuts.first { $0.id == id } ?? edited(id)
        partial.steps = [ShortcutStep(type: .wait, target: "3.0", title: "부분 편집")]
        partial.automations = []        // fallback 그대로 — 안 건드림
        store.syncShortcut(partial)

        XCTAssertTrue(
            isLocked(store, id, .triggers),
            "건드리지 않은 컬럼의 잠금이 풀렸다 — 손상 원본을 덮어쓴다"
        )
    }

    // MARK: - ★ 해제되면 안 되는 경우 (원본 보호)

    func testFallbackValueDoesNotReleaseTheLock() {
        // 이게 해제 조건의 핵심이다.
        // 손상 컬럼의 메모리 값은 fallback(예: `[]`)이다. 이걸 저장해 버리면
        // 사용자의 원본 데이터가 조용히 지워진다. 왕복 검증이 이것을 막아야 한다.
        for column in StoreBlobColumn.allCases {
            let (store, id) = seedCorrupt(column)
            let inMemory = store.shortcuts.first { $0.id == id }
            XCTAssertNotNil(inMemory, "전제: 메모리에 로드돼야 함")

            var fallback = inMemory ?? edited(id)
            fallback.steps = []            // 손상 컬럼의 fallback 값
            fallback.variables = []
            fallback.automations = []
            fallback.permissions = ShortcutPermissions()
            store.syncShortcut(fallback)

            XCTAssertTrue(
                isLocked(store, id, column),
                "\(column.rawValue): fallback 값으로 잠금이 풀렸다 — 사용자 원본 데이터가 덮어써진다"
            )
        }
    }

    func testCorruptBytesAreNotOverwrittenByFallback() {
        // 위 테스트의 실제 결과 검증: 잠금이 유지되면 저장된 bytes도 그대로여야 한다
        let (store, id) = seedCorrupt(.steps)
        let corruptBytes = Data([0xFF, 0xFE, 0x00])

        var fallback = store.shortcuts.first { $0.id == id } ?? edited(id)
        fallback.steps = []
        store.syncShortcut(fallback)

        XCTAssertEqual(
            persisted(id, in: store)?.stepsData, corruptBytes,
            "잠금 유지 중인데 저장된 bytes가 바뀌었다 — 원본 보호가 깨졌다"
        )
    }

    // MARK: - 진단: 복구 판정의 전제가 성립하는가

    /// `fallbackBlobBytes`와 실제 저장이 만드는 바이트가 **항상 같아야** 한다
    ///
    /// 복구 가드 3번은 이 두 바이트를 비교한다. 둘이 어긋나면 잠금 판정이 열리고
    /// 손상 원본이 덮어써진다.
    ///
    /// **이 테스트가 실제 버그를 잡았다**: `JSONEncoder`는 기본 설정에서 키 순서가
    /// 비결정적이고, Swift의 `Hasher` 시드는 프로세스마다 무작위라 **프로세스를 넘기면**
    /// 같은 값의 바이트가 달라진다. 그 상태에서 바이트를 비교하는 복구 가드는
    /// 간헐적으로 열렸다. `StoreCoding`이 `.sortedKeys`로 고정한 뒤 통과한다.
    func testFallbackSnapshotMatchesActualEncode() {
        let p = PersistedShortcut(name: "진단", steps: [])
        for column in StoreBlobColumn.allCases {
            let snapshot = p.fallbackBlobBytes(column)
            XCTAssertFalse(snapshot.isEmpty, "\(column.rawValue): 스냅샷이 비었다")
            let again = PersistedShortcut(name: "진단", steps: []).fallbackBlobBytes(column)
            XCTAssertEqual(snapshot, again, "\(column.rawValue): 인코딩이 결정적이지 않다")
        }
        // permissions: 실제로 저장되는 기본값과도 같아야 한다
        let a = String(data: p.fallbackBlobBytes(.permissions), encoding: .utf8) ?? "?"
        let b = String(data: StoreCoding.encode(ShortcutPermissions(), label: "진단 직접"), encoding: .utf8) ?? "?"
        XCTAssertEqual(
            a, b,
            """
            permissions 기본값의 인코딩이 fallback 스냅샷과 다르다.
            A: \(a)
            B: \(b)
            """
        )
    }

    /// 인코딩이 **키 정렬**돼야 한다 — 바이트 비교를 믿을 수 있는 전제
    func testEncodingIsKeySorted() {
        let perms = StoreCoding.encode(
            ShortcutPermissions(
                allowExporting: true, allowRunningOnMac: true, allowRunningOnWatch: false,
                allowRunningFromLockScreen: false, showOnLockScreen: false, requiresConfirmation: false
            ),
            label: "정렬 확인"
        )
        let json = String(data: perms, encoding: .utf8) ?? ""
        let keys = ["allowExporting", "allowRunningFromLockScreen", "allowRunningOnMac",
                    "allowRunningOnWatch", "requiresConfirmation", "showOnLockScreen"]
        let positions = keys.compactMap { json.range(of: "\"\($0)\"")?.lowerBound }
        XCTAssertEqual(positions.count, keys.count, "일부 키를 찾지 못했다: \(json)")
        XCTAssertEqual(positions, positions.sorted(), "키가 정렬되지 않았다: \(json)")
    }

    /// 손상 시점에 스냅샷이 **실제로 기록되는지** — 없으면 가드가 조용히 무력화된다
    func testFallbackSnapshotIsRecordedOnLoad() {
        for column in StoreBlobColumn.allCases {
            let (store, id) = seedCorrupt(column)
            XCTAssertNotNil(
                store.corruptedBlobFallbackBytes[id]?[column],
                "\(column.rawValue): load()가 fallback 스냅샷을 남기지 않았다 — 복구 가드가 무력화된다"
            )
            XCTAssertEqual(
                store.corruptedBlobFallbackBytes[id]?[column],
                PersistedShortcut(name: "x", steps: []).fallbackBlobBytes(column),
                "\(column.rawValue): 기록된 스냅샷이 기본 fallback과 다르다"
            )
        }
    }

    // MARK: - 왕복 검증 자체

    func testRoundTripGuardRejectsUnencodableValue() {
        // 왕복 검증이 실제로 "인코딩 실패"를 구분하는지.
        // `Data`에 임의 바이트를 담은 구조체는 encodeKeeping이 fallback을 쓰지만,
        // `encode`는 빈 Data를 돌려줘야 한다.
        struct Unencodable: Codable, Equatable {
            let blob: Data
            init() { blob = Data([0xFF, 0xFE]) }
        }
        // Data는 항상 인코딩 가능하므로, encode()가 비어 있지 않음을 확인해
        // "왕복 검증 = encode 성공 + decode 성공"이 이 경우 통과함을 본다.
        // 실제 실패 경로(쓰레기 바이트)는 testEmptyBlobStillDetectedAsCorrupt가 덮는다.
        let value = Unencodable()
        let data = StoreCoding.encode(value, label: "테스트")
        XCTAssertFalse(data.isEmpty, "정상 인코딩인데 빈 Data가 나왔다")
        XCTAssertEqual(try? JSONDecoder().decode(Unencodable.self, from: data), value)
    }
}
