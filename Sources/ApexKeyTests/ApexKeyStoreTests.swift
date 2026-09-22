import XCTest
import SwiftData
import AppKit
@testable import ApexKey

/// SwiftData 저장소 관련 테스트 — 전용 경로에 컨테이너가 생성·영속 되는지 확인
/// (기본 경로 default.store는 다른 앱과 충돌하므로 전용 URL 사용을 강제한다)
final class ApexKeyStoreTests: XCTestCase {

    func testContainerCreatableAtDedicatedURL() throws {
        let schema = Schema([PersistedApp.self, PersistedBinding.self, PersistedScript.self, PersistedShortcut.self])
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ApexKeyStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let url = dir.appendingPathComponent("default.store")
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, url: url)]
        )
        let context = ModelContext(container)

        let binding = HotKeyBinding(
            combo: HotKeyCombo(keyCode: 4, modifiers: 1 << 8, displayString: "⌘H"),
            actionType: .system,
            target: "lock",
            title: "",
            onlyWhenAppActive: false
        )
        context.insert(PersistedBinding.from(binding))
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<PersistedBinding>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.toBinding().combo.keyCode, 4)
    }

    func testTwoContainersDoNotShareDefaultStore() throws {
        // 별도 디렉토리의 두 컨테이너는 서로 다른 저장소를 사용해야 한다 (무충돌)
        let schema = Schema([PersistedBinding.self])
        let dirA = FileManager.default.temporaryDirectory.appendingPathComponent("ApexKeyStoreA-\(UUID().uuidString)", isDirectory: true)
        let dirB = FileManager.default.temporaryDirectory.appendingPathComponent("ApexKeyStoreB-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dirA, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dirB, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: dirA)
            try? FileManager.default.removeItem(at: dirB)
        }

        let urlA = dirA.appendingPathComponent("default.store")
        let urlB = dirB.appendingPathComponent("default.store")
        _ = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: urlA)])
        _ = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: urlB)])
        XCTAssertTrue(FileManager.default.fileExists(atPath: urlA.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: urlB.path))
    }

    func testRegisteredAppURLResolvedByBundleID() throws {
        // 실행/토글 단축키가 미실행 앱을 LaunchServices 등록 정보로 열 수 있어야 한다
        // (macOS 기본 내장 앱만 사용 — 타사 앱 의존 금지)
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari")
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.path.hasSuffix("Safari.app"))
        let textEdit = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.TextEdit")
        XCTAssertNotNil(textEdit)
    }

    func testBindingMenuPathPersistsRoundTrip() throws {
        // 메뉴 경로가 PersistedBinding 영속 왕복에서 보존되어야 한다
        let schema = Schema([PersistedBinding.self])
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ApexKeyMenuPath-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("default.store")

        var container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
        var context = ModelContext(container)
        let path = ["파일", "새 창"]
        context.insert(PersistedBinding(
            combo: HotKeyCombo(keyCode: 4, modifiers: 1 << 8, displayString: "⌘N"),
            actionType: .menuCommand,
            target: "com.example",
            title: "새 창",
            menuPath: path,
            onlyWhenAppActive: false
        ))
        try context.save()

        // 두 번째 컨테이너로 다시 읽어 영속 왕복 확인
        container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
        context = ModelContext(container)
        let fetched = try context.fetch(FetchDescriptor<PersistedBinding>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.toBinding().menuPath, path)
    }

    func testMenuItemPathDefaultsToTitle() {
        // menuPath를 명시하지 않으면 실행 시 title 단일 경로로 fallback (old binding 호환)
        let fallback = MenuItem(title: "전체 화면").menuPath
        XCTAssertTrue(fallback.isEmpty)
    }

    func testShortcutPersistsRoundTrip() throws {
        // 동작(단축어)의 단계들과 단축키가 영속 왕복에서 보존되어야 한다
        let schema = Schema([PersistedShortcut.self])
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ApexKeyShortcut-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("default.store")

        let shortcut = ShortcutItem(
            name: "작업 시작",
            steps: [
                ShortcutStep(type: .launchApp, target: "com.apple.Safari", title: "Safari"),
                ShortcutStep(type: .wait, target: "1.0", title: "대기 1초"),
                ShortcutStep(type: .system, target: SystemActionType.mute.rawValue, title: "음소거"),
            ],
            combo: HotKeyCombo(keyCode: 4, modifiers: 1 << 8, displayString: "⌘H")
        )
        var context = ModelContext(try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)]))
        context.insert(PersistedShortcut.from(shortcut))
        try context.save()

        // 두 번째 컨테이너로 다시 읽어 영속 왕복 확인
        context = ModelContext(try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)]))
        let fetched = try context.fetch(FetchDescriptor<PersistedShortcut>())
        XCTAssertEqual(fetched.count, 1)
        let restored = fetched.first?.toShortcut()
        XCTAssertEqual(restored?.name, "작업 시작")
        XCTAssertEqual(restored?.steps.count, 3)
        XCTAssertEqual(restored?.steps[0].type, .launchApp)
        XCTAssertEqual(restored?.steps[0].target, "com.apple.Safari")
        XCTAssertEqual(restored?.combo.displayString, "⌘H")
    }

    // MARK: - v0.16 P0 데이터 소실 방어

    private struct UnencodableValue: Encodable {
        func encode(to encoder: Encoder) throws {
            throw EncodingError.invalidValue(self, EncodingError.Context(codingPath: [], debugDescription: "test"))
        }
    }

    func testEncodeKeepingReturnsPreviousOnFailure() {
        // P0-3: 인코딩 실패 시 빈 Data 대신 기존 blob 유지
        let previous = Data([0x5B, 0x5D]) // "[]"
        let result = StoreCoding.encodeKeeping(UnencodableValue(), previous: previous, label: "테스트")
        XCTAssertEqual(result, previous)
        XCTAssertFalse(result.isEmpty)
    }

    func testEncodeKeepingReturnsEncodedOnSuccess() {
        let previous = Data([0x00])
        let result = StoreCoding.encodeKeeping([1, 2], previous: previous, label: "테스트")
        XCTAssertNotEqual(result, previous)
        XCTAssertEqual(try? JSONDecoder().decode([Int].self, from: result), [1, 2])
    }

    func testUndecodableBlobColumnsDetectsCorruptSteps() {
        // P0-3: 손상된 stepsData는 컬럼 가드 대상, 나머지 컬럼은 정상
        let p = PersistedShortcut(name: "손상", steps: [])
        p.stepsData = Data([0xFF, 0xFE, 0x00])
        let cols = p.undecodableBlobColumns()
        XCTAssertTrue(cols.contains(.steps))
        XCTAssertFalse(cols.contains(.triggers))
        XCTAssertFalse(cols.contains(.variables))
        XCTAssertFalse(cols.contains(.permissions))
    }

    func testUndecodableBlobColumnsEmptyForValidShortcut() {
        let p = PersistedShortcut(
            name: "정상",
            steps: [ShortcutStep(type: .launchApp, target: "com.apple.Safari", title: "Safari")]
        )
        XCTAssertTrue(p.undecodableBlobColumns().isEmpty)
    }

    func testLegacyStoreMigrationMovesFileAndSidecars() throws {
        // P0-1: 구 경로 store + sidecar를 전용 디렉터리로 1회 이관
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ApexKeyMigrate-\(UUID().uuidString)", isDirectory: true)
        let appSupport = root.appendingPathComponent("Application Support", isDirectory: true)
        let storeDirectory = appSupport.appendingPathComponent("com.borasarang.ApexKey", isDirectory: true)
        try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let legacyURL = appSupport.appendingPathComponent("default.store")
        let storeURL = storeDirectory.appendingPathComponent("default.store")
        try Data([0x01]).write(to: legacyURL)
        try Data([0x02]).write(to: URL(fileURLWithPath: legacyURL.path + "-wal"))

        let suiteName = "ApexKeyMigrateTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        ConfigStore.migrateLegacyStoreIfNeeded(
            appSupport: appSupport,
            storeDirectory: storeDirectory,
            storeURL: storeURL,
            defaults: defaults
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path + "-wal"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyURL.path + "-wal"))

        // 2회 호출 시 이관 플래그로 무시 (파일 복원하지 않음)
        try Data([0x03]).write(to: legacyURL)
        ConfigStore.migrateLegacyStoreIfNeeded(
            appSupport: appSupport,
            storeDirectory: storeDirectory,
            storeURL: storeURL,
            defaults: defaults
        )
        XCTAssertEqual(try Data(contentsOf: storeURL), Data([0x01]))
    }

    func testQuarantineStoreMovesCorruptFile() throws {
        // P0-2: 손상 store를 .corrupt-{stamp}로 이동하고 백업 경로 반환
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ApexKeyQuarantine-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let storeURL = dir.appendingPathComponent("default.store")
        try Data([0x0A]).write(to: storeURL)
        try Data([0x0B]).write(to: URL(fileURLWithPath: storeURL.path + "-wal"))

        let backupPath = ConfigStore.quarantineStore(at: storeURL)
        XCTAssertNotNil(backupPath)
        XCTAssertFalse(FileManager.default.fileExists(atPath: storeURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: storeURL.path + "-wal"))
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: backupPath!)), Data([0x0A]))
        XCTAssertTrue(backupPath!.contains(".corrupt-"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupPath! + "-wal"))
    }
}