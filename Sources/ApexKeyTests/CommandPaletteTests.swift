import XCTest
@testable import ApexKey

/// 명령 팔레트 필터 (CommandPaletteFilter) 단위 테스트
final class CommandPaletteTests: XCTestCase {

    private func shortcut(name: String, lastRunAt: Date? = nil) -> ShortcutItem {
        ShortcutItem(name: name, lastRunAt: lastRunAt)
    }

    private func binding(title: String, actionType: ActionType = .launchApp) -> HotKeyBinding {
        HotKeyBinding(
            combo: HotKeyCombo(keyCode: 0, modifiers: 0, displayString: ""),
            actionType: actionType,
            target: "com.example.App",
            title: title
        )
    }

    func testRecentsSortedByLastRunDesc() {
        let now = Date()
        let a = shortcut(name: "A", lastRunAt: now.addingTimeInterval(-100))
        let b = shortcut(name: "B", lastRunAt: now)
        let c = shortcut(name: "C") // 실행 기록 없음 → 제외
        let recents = CommandPaletteFilter.recents(from: [a, b, c])
        XCTAssertEqual(recents.map(\.name), ["B", "A"])
    }

    func testRecentsCappedAtFive() {
        let now = Date()
        let items = (0..<8).map { i in shortcut(name: "S\(i)", lastRunAt: now.addingTimeInterval(Double(-i))) }
        XCTAssertEqual(CommandPaletteFilter.recents(from: items).count, 5)
    }

    func testFilterShortcutsEmptyQueryReturnsEmpty() {
        XCTAssertTrue(CommandPaletteFilter.filterShortcuts([shortcut(name: "작업 시작")], query: "  ").isEmpty)
    }

    func testFilterShortcutsSubstringAndChosung() {
        let items = [shortcut(name: "작업 시작"), shortcut(name: "볼륨 처리")]
        XCTAssertEqual(CommandPaletteFilter.filterShortcuts(items, query: "작업").map(\.name), ["작업 시작"])
        // ㅈㅇ → 작업 시작 초성 매칭
        XCTAssertEqual(CommandPaletteFilter.filterShortcuts(items, query: "ㅈㅇ").map(\.name), ["작업 시작"])
    }

    func testFilterBindingsMatchesTitle() {
        let items = [binding(title: "Safari 열기", actionType: .wait), binding(title: "음소거", actionType: .system)]
        XCTAssertEqual(CommandPaletteFilter.filterBindings(items, query: "safari").map(\.title), ["Safari 열기"])
        XCTAssertEqual(CommandPaletteFilter.filterBindings(items, query: "ㅇㅅㄱ").map(\.title), ["음소거"])
    }

    func testPaletteRowIDsUnique() {
        let s = shortcut(name: "X")
        let b = binding(title: "Y")
        let ids = [PaletteRow.shortcut(s).id, PaletteRow.binding(b).id]
        XCTAssertEqual(Set(ids).count, 2)
    }

    func testFilterAppsByNameAndBundleID() {
        let apps = [
            AppItem(name: "Safari", bundleID: "com.apple.Safari", path: "/Applications/Safari.app"),
            AppItem(name: "Finder", bundleID: "com.apple.finder", path: "/System/Library/CoreServices/Finder.app"),
            AppItem(name: "사파리", bundleID: "com.example.safari-ko", path: "/Applications/Safari-ko.app"),
        ]
        XCTAssertEqual(CommandPaletteFilter.filterApps(apps, query: "saf").map(\.name), ["Safari", "사파리"])
        XCTAssertEqual(CommandPaletteFilter.filterApps(apps, query: "finder").map(\.name), ["Finder"])
        XCTAssertEqual(CommandPaletteFilter.filterApps(apps, query: "사파리").map(\.name), ["사파리"])
        XCTAssertEqual(CommandPaletteFilter.filterApps(apps, query: "ㅅㅍㄹ").map(\.name), ["사파리"])
        XCTAssertTrue(CommandPaletteFilter.filterApps(apps, query: "  ").isEmpty)
    }

    func testFilterCommandsEmptyQueryReturnsEmpty() {
        let cmds = [PaletteCommand(id: "a", title: "설정 열기", hint: "")]
        XCTAssertTrue(CommandPaletteFilter.filterCommands(cmds, query: "").isEmpty)
        XCTAssertEqual(CommandPaletteFilter.filterCommands(cmds, query: "설정").map(\.id), ["a"])
    }

    func testFallbackShowsAllCommandsWhenNoRecents() {
        let cmds = [
            PaletteCommand(id: "a", title: "설정 열기", hint: ""),
            PaletteCommand(id: "b", title: "새 동작 만들기", hint: ""),
        ]
        // 실행 기록 없음 → 6종(전체) 표시
        XCTAssertEqual(CommandPaletteFilter.fallbackCommands(all: cmds, recents: []).map(\.id), ["a", "b"])
        // 기록 있음 → 폴백 숨김
        let run = shortcut(name: "X", lastRunAt: Date())
        XCTAssertTrue(CommandPaletteFilter.fallbackCommands(all: cmds, recents: [run]).isEmpty)
    }

    func testFilterStepsRequiresTwoCharsAndCapsHits() {
        let steps = [
            ShortcutStep(type: .script, target: "rm -rf ~/Library/Caches", title: "캐시 정리"),
            ShortcutStep(type: .wait, target: "2.0", title: "대기"),
        ]
        let shortcut = ShortcutItem(name: "정리 시작", steps: steps)
        XCTAssertTrue(CommandPaletteFilter.filterSteps([shortcut], query: "ㅋ").isEmpty)
        let hits = CommandPaletteFilter.filterSteps([shortcut], query: "캐시")
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.stepTitle, "캐시 정리")
        XCTAssertTrue(hits.first?.preview.contains("캐시") ?? false)
        // 최대 8건
        let many = (0..<20).map { i in ShortcutStep(type: .text, target: "공통검색어 \(i)", title: "항목 \(i)") }
        let big = ShortcutItem(name: "대량", steps: many)
        XCTAssertEqual(CommandPaletteFilter.filterSteps([big], query: "공통검색어").count, 8)
    }
}
