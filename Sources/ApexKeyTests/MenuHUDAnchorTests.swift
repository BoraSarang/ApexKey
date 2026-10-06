import XCTest
import AppKit
@testable import ApexKey

/// 포인터 adjacent 배치 + breadcrumb 드릴인 테스트 (M-01)
final class MenuHUDAnchorTests: XCTestCase {

    // MARK: - anchoredFrame

    private let screen = NSRect(x: 0, y: 0, width: 1512, height: 982)
    private let size = NSSize(width: 460, height: 420)

    @MainActor
    func testOpensRightBelowCursor() {
        let f = AppDelegate.anchoredFrame(near: NSPoint(x: 500, y: 700), size: size, in: screen)
        XCTAssertEqual(f.origin.x, 516, accuracy: 0.5)
        XCTAssertEqual(f.origin.y, 700 - 420 - 16, accuracy: 0.5)
        XCTAssertTrue(screen.insetBy(dx: 12, dy: 12).contains(f))
    }

    @MainActor
    func testFlipsLeftNearRightEdge() {
        let f = AppDelegate.anchoredFrame(near: NSPoint(x: 1450, y: 700), size: size, in: screen)
        XCTAssertEqual(f.origin.x, 1450 - 460 - 16, accuracy: 0.5)
        XCTAssertTrue(screen.insetBy(dx: 12, dy: 12).contains(f))
    }

    @MainActor
    func testFlipsUpNearBottomEdge() {
        let f = AppDelegate.anchoredFrame(near: NSPoint(x: 500, y: 100), size: size, in: screen)
        XCTAssertGreaterThan(f.origin.y, 100)
        XCTAssertTrue(screen.insetBy(dx: 12, dy: 12).contains(f))
    }

    @MainActor
    func testClampsToTinyScreen() {
        // 패널보다 작은 화면에서도 화면 안에 머문다
        let tiny = NSRect(x: 0, y: 0, width: 400, height: 300)
        let f = AppDelegate.anchoredFrame(near: NSPoint(x: 200, y: 150), size: size, in: tiny)
        XCTAssertEqual(f.size, size) // 크기는 유지, 위치만 클램프
        XCTAssertGreaterThanOrEqual(f.origin.x, tiny.minX + 12 - 1)
        XCTAssertGreaterThanOrEqual(f.origin.y, tiny.minY + 12 - 1)
    }

    // MARK: - MenuBrowsePath

    private func leaf(_ t: String) -> MenuItem {
        MenuItem(title: t, menuPath: [t])
    }

    private func sub(_ t: String, _ children: [MenuItem]) -> MenuItem {
        MenuItem(title: t, isSubmenu: true, children: children, menuPath: [t])
    }

    func testDrillIgnoresLeaves() {
        var path = MenuBrowsePath()
        XCTAssertFalse(path.drill(into: leaf("Copy")))
        XCTAssertFalse(path.isBrowsing)
    }

    func testDrillAndBack() {
        var path = MenuBrowsePath()
        let kids = [leaf("A"), leaf("B")]
        XCTAssertTrue(path.drill(into: sub("File", kids)))
        XCTAssertTrue(path.isBrowsing)
        XCTAssertEqual(path.currentChildren?.map(\.title), ["A", "B"])
        path.back()
        XCTAssertFalse(path.isBrowsing)
        XCTAssertNil(path.currentChildren)
    }

    func testJumpTruncates() {
        var path = MenuBrowsePath()
        path.drill(into: sub("File", [sub("Open", [leaf("X")])]))
        path.drill(into: sub("Open", [leaf("X")]))
        XCTAssertEqual(path.stack.count, 2)
        path.jump(to: 0)
        XCTAssertEqual(path.stack.map(\.title), ["File"])
        // 범위 밖 점프는 무시
        path.jump(to: 9)
        XCTAssertEqual(path.stack.count, 1)
    }

    func testReset() {
        var path = MenuBrowsePath()
        path.drill(into: sub("File", [leaf("A")]))
        path.reset()
        XCTAssertFalse(path.isBrowsing)
    }
}
