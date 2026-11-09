import XCTest
@testable import ApexKey

/// T-217 자동화 트리거 4종 — 파일·외장 드라이브·디스플레이·앱 검증.
///
/// 실제 볼륨 연결·화면 분리·앱 실행 없이, 알림 이름 매핑과 화면 수 변화 판정 같은
/// 순수 로직을 검사한다. 감시자 등록 자체는 시스템 이벤트가 필요하므로 실기 확인 항목이다.
final class AutomationTriggersTests: XCTestCase {

    // MARK: - 지원 플래그

    func testT217TriggersAreWatcherSupported() {
        let supported: [AutomationTrigger] = [
            .file(FileTrigger(filePath: "/tmp/a.txt")),
            .externalDrive(ExternalDriveTrigger()),
            .display(DisplayTrigger()),
            .app(AppTrigger(bundleID: "com.apple.Safari")),
        ]
        for trigger in supported {
            XCTAssertTrue(trigger.isWatcherSupported, trigger.displayName)
            XCTAssertTrue(trigger.runsInBackground, trigger.displayName)
        }
    }

    func testStillUnsupportedTriggers() {
        let unsupported: [AutomationTrigger] = [
            .wifi(WiFiTrigger()),
            .bluetooth(BluetoothTrigger()),
            .focus(FocusTrigger()),
            .stageManager(StageManagerTrigger()),
        ]
        for trigger in unsupported {
            XCTAssertFalse(trigger.isWatcherSupported, trigger.displayName)
        }
    }

    // MARK: - 파일 경로

    func testParentDirectoryOfFile() {
        XCTAssertEqual(AutomationManager.parentDirectory(of: "/tmp/a.txt"), "/tmp")
        XCTAssertEqual(AutomationManager.parentDirectory(of: "/tmp/dir/a.txt"), "/tmp/dir")
        XCTAssertNil(AutomationManager.parentDirectory(of: "   "))
    }

    func testNormalizedPathExpandsTilde() {
        XCTAssertEqual(
            AutomationManager.normalizedPath("~/note.txt"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("note.txt").path
        )
        XCTAssertEqual(AutomationManager.normalizedPath("  /tmp//a/../b.txt "), "/tmp/b.txt")
        XCTAssertEqual(AutomationManager.normalizedPath(""), "")
    }

    // MARK: - 디스플레이

    func testDisplayEventTypesFromScreenCount() {
        XCTAssertEqual(
            AutomationManager.displayEventTypes(previousCount: 1, currentCount: 2),
            [.connected]
        )
        XCTAssertEqual(
            AutomationManager.displayEventTypes(previousCount: 2, currentCount: 1),
            [.disconnected]
        )
    }

    func testDisplayEventTypesIgnoreResolutionOnlyChange() {
        XCTAssertTrue(
            AutomationManager.displayEventTypes(previousCount: 2, currentCount: 2).isEmpty
        )
    }

    // MARK: - 외장 드라이브

    func testDriveEventNotificationMapping() {
        XCTAssertEqual(
            AutomationManager.driveEventType(forNotification: NSWorkspace.didMountNotification),
            .mounted
        )
        XCTAssertEqual(
            AutomationManager.driveEventType(forNotification: NSWorkspace.didUnmountNotification),
            .unmounted
        )
        XCTAssertNil(
            AutomationManager.driveEventType(forNotification: NSWorkspace.didLaunchApplicationNotification)
        )
    }

    func testDriveTriggerEventSummary() {
        let trigger = ExternalDriveTrigger(eventTypes: [.mounted, .unmounted])
        let parts = Set(trigger.eventTypes.displaySummary.components(separatedBy: ", "))
        XCTAssertEqual(
            parts,
            Set([DriveEventType.mounted.displayName, DriveEventType.unmounted.displayName])
        )
    }

    // MARK: - 앱

    func testAppEventNotificationMapping() {
        XCTAssertEqual(
            AutomationManager.appEventType(forNotification: NSWorkspace.didLaunchApplicationNotification),
            .launched
        )
        XCTAssertEqual(
            AutomationManager.appEventType(forNotification: NSWorkspace.didTerminateApplicationNotification),
            .terminated
        )
        XCTAssertEqual(
            AutomationManager.appEventType(forNotification: NSWorkspace.didActivateApplicationNotification),
            .activated
        )
        XCTAssertEqual(
            AutomationManager.appEventType(forNotification: NSWorkspace.didDeactivateApplicationNotification),
            .deactivated
        )
        XCTAssertNil(
            AutomationManager.appEventType(forNotification: NSWorkspace.didMountNotification)
        )
    }

    // MARK: - 이벤트 데이터

    func testFileEventPayload() {
        let id = UUID()
        let url = URL(fileURLWithPath: "/tmp/a.txt")
        let event = TriggerEventData.fileEvent(triggerID: id, fileURL: url)
        XCTAssertEqual(event.triggerType, "file")
        XCTAssertEqual(event.triggerID, id)
        XCTAssertEqual(event.data["file"], .file(url))
        XCTAssertEqual(event.data["filePath"], .text("/tmp/a.txt"))
    }

    func testDriveEventPayload() {
        let id = UUID()
        let event = TriggerEventData.driveEvent(
            triggerID: id,
            eventType: .mounted,
            driveName: "Backup",
            mountPoint: "/Volumes/Backup"
        )
        XCTAssertEqual(event.triggerType, "externalDrive")
        XCTAssertEqual(event.data["eventType"], .text("mounted"))
        XCTAssertEqual(event.data["driveName"], .text("Backup"))
        XCTAssertEqual(event.data["mountPoint"], .text("/Volumes/Backup"))
    }

    func testDisplayEventPayload() {
        let id = UUID()
        let event = TriggerEventData.displayEvent(
            triggerID: id,
            eventType: .connected,
            screenCount: 2
        )
        XCTAssertEqual(event.triggerType, "display")
        XCTAssertEqual(event.data["eventType"], .text("connected"))
        XCTAssertEqual(event.data["screenCount"], .number(2))
    }

    func testAppEventPayload() {
        let id = UUID()
        let event = TriggerEventData.appEvent(
            triggerID: id,
            eventType: .launched,
            bundleID: "com.apple.Safari"
        )
        XCTAssertEqual(event.triggerType, "app")
        XCTAssertEqual(event.data["eventType"], .text("launched"))
        XCTAssertEqual(event.data["bundleID"], .text("com.apple.Safari"))
    }
}
