import XCTest
@testable import ApexKey

/// Conflict palette 순수 로직 단위 테스트 — Carbon 등록은 건드리지 않음
final class HotKeyConflictTests: XCTestCase {
    private var comboA: HotKeyCombo {
        HotKeyCombo(keyCode: 40, modifiers: KeyboardUtil.cmdMask | KeyboardUtil.shiftMask, displayString: "⌘⇧K")
    }

    private func isolatedDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test.conflict.\(UUID().uuidString)")!
    }

    func testComboKeyFormat() {
        XCTAssertEqual(HotKeyConflict.comboKey(comboA), "\(comboA.keyCode):\(comboA.modifiers)")
    }

    func testTargetsCollectShortcutsAndBindings() {
        let s = ShortcutItem(name: "워크", combo: comboA)
        let other = ShortcutItem(name: "다른", combo: .empty)
        let b = HotKeyBinding(combo: comboA, actionType: .launchApp, target: "com.x", title: "앱")
        let out = HotKeyConflict.targets(matching: comboA, shortcuts: [s, other], bindings: [b])
        XCTAssertEqual(out.count, 2)
        XCTAssertTrue(out.contains(where: { $0.kind == .shortcut && $0.title == "워크" }))
        XCTAssertTrue(out.contains(where: { $0.kind == .binding && $0.title == "앱" }))
    }

    func testResolveNoneSingleChoose() {
        let d = isolatedDefaults()
        if case .none = HotKeyConflict.resolve(targets: [], preferredID: nil) {} else {
            XCTFail("빈 목록은 none")
        }
        let one = HotKeyConflict.Target.shortcut(ShortcutItem(name: "A", combo: comboA))
        if case .run(let t) = HotKeyConflict.resolve(targets: [one], preferredID: nil) {
            XCTAssertEqual(t.id, one.id)
        } else {
            XCTFail("1건은 run")
        }
        let two = HotKeyConflict.Target.binding(HotKeyBinding(combo: comboA, actionType: .url, target: "x://", title: "B"))
        if case .choose(let list) = HotKeyConflict.resolve(targets: [one, two], preferredID: nil) {
            XCTAssertEqual(list.count, 2)
        } else {
            XCTFail("2건은 choose")
        }
        // 고정된 항목은 목록 없이 바로 실행
        HotKeyConflict.setPreferred(two.id, for: comboA, defaults: d)
        let pid = HotKeyConflict.preferredID(for: comboA, defaults: d)
        XCTAssertEqual(pid, two.id)
        if case .run(let t) = HotKeyConflict.resolve(targets: [one, two], preferredID: pid) {
            XCTAssertEqual(t.id, two.id)
        } else {
            XCTFail("고정은 run")
        }
        // 없는 ID 고정은 무시하고 목록 표시
        if case .choose = HotKeyConflict.resolve(targets: [one, two], preferredID: UUID()) {} else {
            XCTFail("없는 고정은 choose")
        }
        HotKeyConflict.clearPreferred(for: comboA, defaults: d)
        XCTAssertNil(HotKeyConflict.preferredID(for: comboA, defaults: d))
    }
}
