import XCTest
import SwiftUI
@testable import ApexKey

/// PLAN_v0.31 — 워크플로우 3종 (T-187/188/189). AX·실클릭 없이 순수·실패 경로만.
final class WorkflowStepsTests: XCTestCase {
    // MARK: - T-187 메뉴 명령 선택 반영

    func testMenuCommandApplySetsTargetTitlePath() {
        var step = ShortcutStep(type: .menuCommand, target: "", title: "")
        let item = MenuItem(title: "반복", menuPath: ["재생", "반복"])
        MenuCommandSelection.apply(bundleID: "com.colliderli.iina", item: item, to: &step)
        XCTAssertEqual(step.target, "com.colliderli.iina")
        XCTAssertEqual(step.title, "반복")
        XCTAssertEqual(step.menuPath, ["재생", "반복"])
        XCTAssertEqual(step.toBinding().target, "com.colliderli.iina")
        XCTAssertEqual(step.toBinding().menuPath, ["재생", "반복"])
    }

    func testMenuCommandApplyAppOnlyKeepsMenu() {
        var step = ShortcutStep(type: .menuCommand, target: "", title: "구제목", menuPath: ["재생"])
        MenuCommandSelection.apply(bundleID: "com.apple.Safari", item: nil, to: &step)
        XCTAssertEqual(step.target, "com.apple.Safari")
        XCTAssertEqual(step.title, "구제목")
        XCTAssertEqual(step.menuPath, ["재생"])
    }

    // MARK: - T-188 특정 앱으로 열기 설정 코덱

    func testFileOpenConfigEmptyIsDefaultApp() {
        XCTAssertNil(FileOpenConfig.decode(from: nil).appBundleID)
        XCTAssertNil(FileOpenConfig.decode(from: Data()).appBundleID)
    }

    func testFileOpenConfigRoundTrip() {
        var cfg = FileOpenConfig()
        cfg.appBundleID = "com.colliderli.iina"
        let data = cfg.encode()
        XCTAssertNotNil(data)
        XCTAssertEqual(FileOpenConfig.decode(from: data).appBundleID, "com.colliderli.iina")
    }

    func testOpenFileMissingPathFails() {
        XCTAssertFalse(ActionExecutor.openFile(path: "/없는/경로/AA.mp4", withAppBundleID: nil))
        XCTAssertFalse(ActionExecutor.openFile(path: "", withAppBundleID: "com.colliderli.iina"))
    }

    func testExecuteFileMissingFailsWithoutSideEffect() {
        let step = ShortcutStep(type: .file, target: "/없는/경로/AA.mp4")
        let shortcut = ShortcutItem(name: "검증", steps: [step])
        var ctx = UseModelExecutor.ExecutionContext()
        XCTAssertFalse(ExecutionEngine.shared.execute(shortcut, context: &ctx).success)
    }

    // MARK: - T-190 순서 변경 계산

    func testMoveDownDestinationMovesOne() {
        XCTAssertEqual(StepReorder.moveDownDestination(from: 0, count: 3), 2)
        XCTAssertEqual(StepReorder.moveDownDestination(from: 1, count: 3), 3)
        XCTAssertNil(StepReorder.moveDownDestination(from: 2, count: 3))
    }

    func testDropDestinationDownAndUp() {
        // 아래로: [A,B,C] A를 C에 드롭 → ([0],2) → [B,A,C]... 최종 위치 onto와 일치
        XCTAssertEqual(StepReorder.dropDestination(from: 0, onto: 2)?.to, 3)
        // 위로: [A,B,C,D] D를 B에 드롭 → ([3],1)
        let up = StepReorder.dropDestination(from: 3, onto: 1)
        XCTAssertEqual(up?.from, IndexSet([3]))
        XCTAssertEqual(up?.to, 1)
        XCTAssertNil(StepReorder.dropDestination(from: 1, onto: 1))
    }

    func testDropDestinationMatchesRealMove() {
        // 드롭 계산이 실제 Array.move 결과와 최종 위치가 일치하는지 검증
        var steps = ["A", "B", "C", "D"]
        let dest = StepReorder.dropDestination(from: 0, onto: 2)!
        steps.move(fromOffsets: dest.from, toOffset: dest.to)
        XCTAssertEqual(steps, ["B", "C", "A", "D"])
        var steps2 = ["A", "B", "C", "D"]
        let dest2 = StepReorder.dropDestination(from: 3, onto: 1)!
        steps2.move(fromOffsets: dest2.from, toOffset: dest2.to)
        XCTAssertEqual(steps2, ["A", "D", "B", "C"])
    }

    // MARK: - T-189 최소화 프리셋 존재

    func testMinimizePresetHasNameAndIcon() {
        let type = SystemActionType.minimizeFrontWindow
        XCTAssertFalse(type.displayName.isEmpty)
        XCTAssertFalse(type.systemImage.isEmpty)
        XCTAssertTrue(SystemActionType.allCases.contains(type))
    }
}
