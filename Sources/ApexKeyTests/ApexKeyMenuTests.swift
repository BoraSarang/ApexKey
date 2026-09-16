import XCTest
import AppKit
@testable import ApexKey

/// 메인 메뉴 편집 항목 회귀 테스트 (T-133)
/// 편집 메뉴가 없으면 TextEditor/TextField에서 Cmd+C/V/X/A/Z가 동작하지 않음.
final class ApexKeyMenuTests: XCTestCase {

    @MainActor
    func testMainMenuHasEditMenuWithStandardActions() throws {
        let menu = AppDelegate.makeMainMenu(actionTarget: nil)
        let edit = try XCTUnwrap(
            menu.items.first(where: { $0.submenu?.title == "ui.edit".localized })?.submenu,
            "편집 메뉴가 없습니다 — Cmd+C/V가 동작하지 않습니다"
        )
        func item(for action: Selector) -> NSMenuItem? {
            edit.items.first(where: { $0.action == action })
        }
        XCTAssertEqual(item(for: #selector(NSText.copy(_:)))?.keyEquivalent, "c")
        XCTAssertEqual(item(for: #selector(NSText.paste(_:)))?.keyEquivalent, "v")
        XCTAssertEqual(item(for: #selector(NSText.cut(_:)))?.keyEquivalent, "x")
        XCTAssertEqual(item(for: #selector(NSText.selectAll(_:)))?.keyEquivalent, "a")
        XCTAssertEqual(item(for: Selector("undo:"))?.keyEquivalent, "z")
        // 편집 항목은 responder chain을 타야 하므로 target이 nil이어야 함
        for action in [#selector(NSText.copy(_:)), #selector(NSText.paste(_:)),
                       #selector(NSText.cut(_:)), #selector(NSText.selectAll(_:))] {
            XCTAssertNil(item(for: action)?.target, "\(action) target은 nil(responder chain)이어야 함")
        }
    }
}
