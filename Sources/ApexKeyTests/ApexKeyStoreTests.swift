import XCTest
import SwiftData
import AppKit
@testable import ApexKey

/// SwiftData 저장소 관련 테스트 — 전용 경로에 컨테이너가 생성·영속 되는지 확인
/// (기본 경로 default.store는 다른 앱과 충돌하므로 전용 URL 사용을 강제한다)
final class ApexKeyStoreTests: XCTestCase {

    func testContainerCreatableAtDedicatedURL() throws {
        let schema = Schema([PersistedApp.self, PersistedBinding.self, PersistedScript.self])
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
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari")
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.path.hasSuffix("Safari.app"))
        let movist = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.movist.MovistPro")
        XCTAssertNotNil(movist)
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
}