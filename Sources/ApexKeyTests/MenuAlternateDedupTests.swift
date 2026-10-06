import XCTest
@testable import ApexKey

/// Option 대체항목 중복 제거 테스트 (M-02)
/// AX 실측(Finder): 진짜 대체와 일반 Option 단축키는 속성 집합이 동일하므로
/// "직전 형제 + 같은 키 + Option만 추가" 휴리스틱으로 판정한다.
final class MenuAlternateDedupTests: XCTestCase {

    private var cmd: UInt32 { KeyboardUtil.cmdMask }
    private var opt: UInt32 { KeyboardUtil.optionMask }
    private var shift: UInt32 { KeyboardUtil.shiftMask }

    private func item(_ title: String, char: String = "", mods: UInt32 = 0,
                      children: [MenuItem] = []) -> MenuItem {
        MenuItem(title: title, commandChar: char, commandModifiers: mods,
                 isSubmenu: !children.isEmpty, children: children, menuPath: [title])
    }

    func testAlternatePairHidesOptionSide() {
        let items = [
            item("Close Window", char: "W", mods: cmd),
            item("Close All", char: "W", mods: cmd | opt),
        ]
        let result = MenuEnumerator.shared.removingAlternateDuplicates(in: items)
        XCTAssertEqual(result.map(\.title), ["Close Window"])
    }

    func testNormalOptionShortcutWithoutPairIsKept() {
        // 직전 형제와 키가 다르면 일반 Option 단축키로 보고 유지
        let items = [
            item("New Window", char: "N", mods: cmd),
            item("Hide Others", char: "H", mods: cmd | opt),
        ]
        let result = MenuEnumerator.shared.removingAlternateDuplicates(in: items)
        XCTAssertEqual(result.count, 2)
    }

    func testHidePairDocumentsTradeoff() {
        // Hide Finder → Hide Others 쌍은 AX로 진짜 대체와 구분 불가 → 함께 숨겨진다 (의도된 절충).
        // 이 테스트가 그 동작을 고정한다. 정책 변경 시 여기부터 고칠 것.
        let items = [
            item("Hide Finder", char: "H", mods: cmd),
            item("Hide Others", char: "H", mods: cmd | opt),
        ]
        let result = MenuEnumerator.shared.removingAlternateDuplicates(in: items)
        XCTAssertEqual(result.map(\.title), ["Hide Finder"])
    }

    func testNonAdjacentSameCharIsKept() {
        // 바로 인접하지 않으면 대체 쌍이 아니다
        let items = [
            item("Close Window", char: "W", mods: cmd),
            item("Something", char: "X", mods: cmd),
            item("Close All", char: "W", mods: cmd | opt),
        ]
        let result = MenuEnumerator.shared.removingAlternateDuplicates(in: items)
        XCTAssertEqual(result.count, 3)
    }

    func testExtraModifierBeyondOptionIsKept() {
        // Option 외 수식키가 더 붙으면 다른 명령으로 보고 유지
        let items = [
            item("Close Window", char: "W", mods: cmd),
            item("Close All Tabs", char: "W", mods: cmd | opt | shift),
        ]
        let result = MenuEnumerator.shared.removingAlternateDuplicates(in: items)
        XCTAssertEqual(result.count, 2)
    }

    func testChainKeepsThird() {
        // A, A+⌥, A+⌥⇧ — 첫 쌍만 제거, 세 번째는 유지 (과삭제 방지)
        let items = [
            item("A", char: "W", mods: cmd),
            item("B", char: "W", mods: cmd | opt),
            item("C", char: "W", mods: cmd | opt | shift),
        ]
        let result = MenuEnumerator.shared.removingAlternateDuplicates(in: items)
        XCTAssertEqual(result.map(\.title), ["A", "C"])
    }

    func testSeparatorsAndShortcutlessAreNeverDropped() {
        let items = [
            item("Close Window", char: "W", mods: cmd),
            MenuItem(title: "─", isSeparator: true, menuPath: []),
            item("Plain", mods: cmd | opt),
        ]
        let result = MenuEnumerator.shared.removingAlternateDuplicates(in: items)
        XCTAssertEqual(result.count, 3)
    }

    func testRecursesIntoSubmenus() {
        let sub = [
            item("Get Info", char: "I", mods: cmd),
            item("Show Inspector", char: "I", mods: cmd | opt),
        ]
        let items = [item("File", children: sub)]
        let result = MenuEnumerator.shared.removingAlternateDuplicates(in: items)
        XCTAssertEqual(result.first?.children.map(\.title), ["Get Info"])
    }

    func testCaseInsensitiveCharMatch() {
        let items = [
            item("Close Window", char: "w", mods: cmd),
            item("Close All", char: "W", mods: cmd | opt),
        ]
        let result = MenuEnumerator.shared.removingAlternateDuplicates(in: items)
        XCTAssertEqual(result.count, 1)
    }
}
