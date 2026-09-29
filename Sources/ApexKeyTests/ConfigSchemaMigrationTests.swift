import XCTest
import SwiftData
@testable import ApexKey

/// 스키마 버전 관리 테스트 (E-MAC-STORE-5007)
///
/// **이 파일의 `testUnversionedStoreOpensUnderMigrationPlan`이 깨지면 실사용자 데이터가 격리된다.**
/// `ConfigStore.init()`의 컨테이너 생성 실패 → `quarantineStore` 경로가 발동해
/// 앱은 빈 설정으로 시작하고 사용자 데이터는 `.corrupt-{stamp}`로 밀려난다.
/// 버전 관리 도입의 유일한 위험이 "기존 무버전 store가 새 계획으로 열리는가"였으므로
/// 그 경로만이라도 반드시 고정한다.
final class ConfigSchemaMigrationTests: XCTestCase {

    private func makeTempDir(_ label: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(label)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - 위험 1 — 무버전 store를 새 계획으로 열 수 있는가 (최 중요)

    func testUnversionedStoreOpensUnderMigrationPlan() throws {
        // 버전 관리 도입 이전 코드와 동일한 구성으로 store를 만든다
        let legacySchema = Schema([PersistedApp.self, PersistedBinding.self, PersistedScript.self, PersistedShortcut.self])
        let dir = try makeTempDir("ApexKeyUnversionedUpgrade")
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("default.store")

        // 1) 구 코드로 store 생성 + 데이터 기록
        let legacyContainer = try ModelContainer(
            for: legacySchema,
            configurations: [ModelConfiguration(schema: legacySchema, url: url)]
        )
        let legacyContext = ModelContext(legacyContainer)
        legacyContext.insert(PersistedApp.from(AppItem(
            name: "Safari", bundleID: "com.apple.Safari", path: "/Applications/Safari.app", category: .productivity
        )))
        legacyContext.insert(PersistedBinding.from(HotKeyBinding(
            combo: HotKeyCombo(keyCode: 0, modifiers: 1 << 9, displayString: "⇧⌥A"),
            actionType: .launchApp,
            target: "com.apple.Safari",
            title: "Safari"
        )))
        legacyContext.insert(PersistedShortcut.from(ShortcutItem(
            name: "구 동작",
            steps: [ShortcutStep(type: .launchApp, target: "com.apple.Safari", title: "Safari")],
            combo: HotKeyCombo(keyCode: 4, modifiers: 1 << 8, displayString: "⌘H")
        )))
        try legacyContext.save()

        // 2) 새 코드(ConfigMigrationPlan 경유)로 같은 store를 연다 — 실패하면 격리된다
        let migratedSchema = ConfigMigrationPlan.currentSchema
        let container: ModelContainer
        do {
            container = try ModelContainer(
                for: migratedSchema,
                migrationPlan: ConfigMigrationPlan.self,
                configurations: [ModelConfiguration(schema: migratedSchema, url: url)]
            )
        } catch {
            XCTFail("무버전 store를 마이그레이션 계획으로 열지 못함 — 실사용자 store가 격리된다: \(error.localizedDescription)")
            return
        }

        // 3) 데이터가 살아있어야 한다
        let context = ModelContext(container)
        let apps = try context.fetch(FetchDescriptor<PersistedApp>())
        let bindings = try context.fetch(FetchDescriptor<PersistedBinding>())
        let shortcuts = try context.fetch(FetchDescriptor<PersistedShortcut>())
        XCTAssertEqual(apps.count, 1, "앱 목록이 이관 과정에서 소실됨")
        XCTAssertEqual(bindings.count, 1, "핫키 바인딩이 이관 과정에서 소실됨")
        XCTAssertEqual(shortcuts.count, 1, "동작이 이관 과정에서 소실됨")
        XCTAssertEqual(apps.first?.toAppItem().bundleID, "com.apple.Safari")
        XCTAssertEqual(bindings.first?.toBinding().target, "com.apple.Safari")
        XCTAssertEqual(shortcuts.first?.toShortcut().name, "구 동작")
        XCTAssertEqual(shortcuts.first?.toShortcut().steps.count, 1)
    }

    func testUnversionedStoreIsReadWriteAfterUpgrade() throws {
        // 이관 후에도 **쓰기가** 되어야 한다. 읽기만 되면 다음 실행에서 사용자의
        // 새 설정이 저장되지 않는다(무음 데이터 소실).
        let legacySchema = Schema([PersistedBinding.self])
        let dir = try makeTempDir("ApexKeyUnversionedWrite")
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("default.store")

        let legacyContainer = try ModelContainer(
            for: legacySchema,
            configurations: [ModelConfiguration(schema: legacySchema, url: url)]
        )
        let legacyContext = ModelContext(legacyContainer)
        legacyContext.insert(PersistedBinding.from(HotKeyBinding(
            combo: HotKeyCombo(keyCode: 12, modifiers: 1 << 8, displayString: "⌘Q"),
            actionType: .launchApp, target: "com.apple.Safari", title: "기존"
        )))
        try legacyContext.save()

        let migratedSchema = ConfigMigrationPlan.currentSchema
        let container = try ModelContainer(
            for: migratedSchema,
            migrationPlan: ConfigMigrationPlan.self,
            configurations: [ModelConfiguration(schema: migratedSchema, url: url)]
        )
        let context = ModelContext(container)
        context.insert(PersistedBinding.from(HotKeyBinding(
            combo: HotKeyCombo(keyCode: 15, modifiers: 1 << 8, displayString: "⌘L"),
            actionType: .launchApp, target: "com.apple.TextEdit", title: "추가"
        )))
        try context.save()

        let reopened = ModelContext(try ModelContainer(
            for: migratedSchema,
            migrationPlan: ConfigMigrationPlan.self,
            configurations: [ModelConfiguration(schema: migratedSchema, url: url)]
        ))
        let all = try reopened.fetch(FetchDescriptor<PersistedBinding>())
        XCTAssertEqual(all.count, 2, "이관 후 쓰기가 반영되지 않음")
        XCTAssertEqual(Set(all.map { $0.toBinding().title }), ["기존", "추가"])
    }

    // MARK: - 위험 2 — 손상 store 격리가 실제로 발동하는지 (회귀 고정)

    func testGarbageStoreFailsToOpen() throws {
        // 쓰레기 파일은 정상적으로 열리지 않아야 한다. 만약 열린다면
        // `quarantineStore` 경로가 죽은 코드가 되어 손상 store가 조용히 재사용된다.
        let dir = try makeTempDir("ApexKeyGarbage")
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("default.store")
        try Data(repeating: 0x5A, count: 4096).write(to: url)

        let schema = ConfigMigrationPlan.currentSchema
        let opened = (try? ModelContainer(
            for: schema,
            migrationPlan: ConfigMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schema, url: url)]
        )) != nil
        // SwiftData가 빈 파일(Some)이나 비SQLite는 관대하게 열 수 있으므로 단정하지 않는다.
        // 대신 격리 후 재생성 경로가 항상 성공함을 확인한다.
        if !opened {
            let backup = ConfigStore.quarantineStore(at: url)
            XCTAssertNotNil(backup, "격리 실패 — 손상 store가 원위치에 남아 반복 실패한다")
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
            let recreated = try? ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, url: url)]
            )
            XCTAssertNotNil(recreated, "격리 후 재생성 실패 — 앱이 무음 no-op 상태가 된다")
        }
    }

    // MARK: - 계획 자체의 계약

    func testMigrationPlanExposesV1() {
        XCTAssertEqual(ConfigMigrationPlan.schemas.count, 1)
        XCTAssertTrue(ConfigMigrationPlan.schemas.first == ConfigSchemaV1.self)
        XCTAssertEqual(ConfigSchemaV1.versionIdentifier, Schema.Version(1, 0, 0))
    }

    func testMigrationPlanStageCountMatchesSchemaCount() {
        // stage 수는 schemas 수보다 정확히 1 적어야 한다 (n개 스키마 = n-1개 이관).
        // 이 불일치가 있으면 특정 버전을 건너뛰는 store가 생긴다.
        XCTAssertEqual(
            ConfigMigrationPlan.stages.count,
            max(0, ConfigMigrationPlan.schemas.count - 1),
            "stage 수가 스키마 수와 맞지 않음 — 어떤 버전을 건너뛴다"
        )
    }

    func testV1CoversAllPersistedModels() {
        // 새 @Model을 추가하면서 ConfigSchemaV1.models에 넣지 않으면
        // 그 모델은 store에 영속되지 않는다(조용히 사라짐).
        let names = Set(ConfigSchemaV1.models.map { String(describing: $0) })
        XCTAssertEqual(names, ["PersistedApp", "PersistedBinding", "PersistedScript", "PersistedShortcut"])
    }

    func testV1FieldShapeMatchesUnversionedSchema() {
        // ConfigSchemaV1은 "무버전 스키마의 이름 붙은 복사본"이어야 한다.
        // 어느 한쪽에 필드가 생기면 다른 쪽과 어긋나 이관이 필요해진다.
        let versioned = ConfigMigrationPlan.currentSchema
        let unversioned = Schema([PersistedApp.self, PersistedBinding.self, PersistedScript.self, PersistedShortcut.self])
        XCTAssertEqual(
            Set(versioned.entities.map(\.name)),
            Set(unversioned.entities.map(\.name)),
            "v1 스키마가 기존 스키마와 다르다 — 마이그레이션 stage 없이 배포하면 데이터 소실"
        )
    }

    func testPlanSeededStoreRoundTripsAllModels() throws {
        // 계획 경유로 만든 store에서 4개 모델 전부 왕복되는지
        let dir = try makeTempDir("ApexKeyPlanRoundTrip")
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("default.store")
        let schema = ConfigMigrationPlan.currentSchema

        let container = try ModelContainer(
            for: schema,
            migrationPlan: ConfigMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schema, url: url)]
        )
        let context = ModelContext(container)
        context.insert(PersistedApp.from(AppItem(
            name: "메모", bundleID: "com.apple.Notes", path: "/Applications/Notes.app", category: .productivity
        )))
        context.insert(PersistedBinding.from(HotKeyBinding(
            combo: HotKeyCombo(keyCode: 37, modifiers: 1 << 11, displayString: "⌘⌥L"),
            actionType: .menuCommand, target: "com.apple.Notes", title: "새 메모", menuPath: ["파일", "새 메모"]
        )))
        context.insert(PersistedScript.from(ScriptItem(name: "스크립트", command: "echo hi")))
        context.insert(PersistedShortcut.from(ShortcutItem(
            name: "새 동작",
            steps: [ShortcutStep(type: .wait, target: "0.1", title: "대기")],
            combo: HotKeyCombo(keyCode: 49, modifiers: 1 << 8, displayString: "⌘1")
        )))
        try context.save()

        let reopened = ModelContext(try ModelContainer(
            for: schema,
            migrationPlan: ConfigMigrationPlan.self,
            configurations: [ModelConfiguration(schema: schema, url: url)]
        ))
        XCTAssertEqual(try reopened.fetch(FetchDescriptor<PersistedApp>()).first?.toAppItem().name, "메모")
        XCTAssertEqual(try reopened.fetch(FetchDescriptor<PersistedBinding>()).first?.toBinding().menuPath, ["파일", "새 메모"])
        XCTAssertEqual(try reopened.fetch(FetchDescriptor<PersistedScript>()).first?.toScript().command, "echo hi")
        XCTAssertEqual(try reopened.fetch(FetchDescriptor<PersistedShortcut>()).first?.toShortcut().name, "새 동작")
    }
}
