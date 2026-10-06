import XCTest
import ApplicationServices
@testable import ApexKey

/// 메뉴바 아이콘 열거 테스트 (M-03)
/// AX 실측 기반: 시스템 아이콘은 MenuBarAgent AXGroup 아래, 서드파티는 각 앱 extras 직속.
final class MenuBarIconEnumeratorTests: XCTestCase {

    private func stub(title: String, bundleID: String?, x: CGFloat?) -> MenuBarIconEnumerator.IconItem {
        MenuBarIconEnumerator.IconItem(
            title: title, bundleID: bundleID, pid: getpid(),
            element: AXUIElementCreateApplication(getpid()),
            positionX: x, hasShowMenu: false
        )
    }

    func testSystemIconsComeFirst() {
        let items = [
            stub(title: "Third", bundleID: "com.example.app", x: 100),
            stub(title: "Wi-Fi", bundleID: MenuBarIconEnumerator.menuBarAgentBundleID, x: 1400),
        ]
        let sorted = MenuBarIconEnumerator.sortIcons(items)
        XCTAssertEqual(sorted.map(\.title), ["Wi-Fi", "Third"])
    }

    func testThirdPartySortedByPosition() {
        let items = [
            stub(title: "B", bundleID: "com.example.b", x: 1300),
            stub(title: "A", bundleID: "com.example.a", x: 1200),
            stub(title: "NoPos", bundleID: "com.example.c", x: nil),
        ]
        let sorted = MenuBarIconEnumerator.sortIcons(items)
        XCTAssertEqual(sorted.map(\.title), ["A", "B", "NoPos"])
    }

    func testIsSystemIcon() {
        XCTAssertTrue(stub(title: "S", bundleID: MenuBarIconEnumerator.menuBarAgentBundleID, x: nil).isSystemIcon)
        XCTAssertFalse(stub(title: "T", bundleID: "com.example.app", x: nil).isSystemIcon)
    }

    func testLiveEnumerationFindsSystemIcons() throws {
        // 권한 없는 호스트(CI)에서는 건너뛴다 (T-184 패턴 — 러너 상태 측정 금지)
        try XCTSkipUnless(PermissionHelper.isAccessibilityTrusted, "Accessibility 권한 없이 메뉴바 열거 불가 — 로컬에서만 실행")
        let items = MenuBarIconEnumerator.shared.enumerate()
        XCTAssertFalse(items.isEmpty, "권한이 있는데 아이콘 0건이면 열거 경로 파손")
        XCTAssertTrue(items.contains { $0.isSystemIcon }, "MenuBarAgent 시스템 아이콘이 보여야 함")
        XCTAssertTrue(items.allSatisfy { !$0.title.isEmpty })
    }

    func testAsyncEnumerationMatchesSyncAndCaches() async throws {
        try XCTSkipUnless(PermissionHelper.isAccessibilityTrusted, "Accessibility 권한 없이 메뉴바 열거 불가 — 로컬에서만 실행")
        MenuBarIconEnumerator.shared.invalidateCache()
        XCTAssertNil(MenuBarIconEnumerator.shared.cachedIcons())
        XCTAssertNil(MenuBarIconEnumerator.shared.staleIcons())
        XCTAssertTrue(MenuBarIconEnumerator.shared.isCacheStale())
        let asyncItems = await MenuBarIconEnumerator.shared.enumerateAsync()
        let syncItems = MenuBarIconEnumerator.shared.enumerate()
        XCTAssertFalse(asyncItems.isEmpty)
        // 같은 집합 (순서 보장: 시스템 먼저)
        XCTAssertEqual(asyncItems.map(\.title).sorted(), syncItems.map(\.title).sorted())
        XCTAssertTrue(asyncItems.first?.isSystemIcon ?? false)
        // 캐시 적재 확인 — 다음 열기는 즉시
        XCTAssertEqual(MenuBarIconEnumerator.shared.cachedIcons()?.count, asyncItems.count)
        XCTAssertEqual(MenuBarIconEnumerator.shared.staleIcons()?.count, asyncItems.count)
        XCTAssertFalse(MenuBarIconEnumerator.shared.isCacheStale())
    }
}
