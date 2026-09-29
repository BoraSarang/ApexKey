import XCTest
@testable import ApexKey

/// 모델/유틸리티 단위 테스트 (네트워크·AX 불필요)
final class ApexKeyModelTests: XCTestCase {

    func testHotKeyComboEmpty() {
        XCTAssertTrue(HotKeyCombo.empty.isEmpty)
        let combo = HotKeyCombo(keyCode: 4, modifiers: 0)
        XCTAssertFalse(combo.isEmpty)
    }

    func testActionTypeRawStrings() {
        XCTAssertEqual(ActionType.launchApp.rawValue, "launchApp")
        XCTAssertEqual(ActionType.menuCommand.rawValue, "menuCommand")
    }

    func testMenuItemKeyEquivalentDisplay() {
        // AX Carbon flags: Cmd = 1<<8 (cmdKey)
        let item = MenuItem(title: "새 창", commandChar: "n", commandModifiers: KeyboardUtil.cmdMask)
        XCTAssertTrue(item.hasKeyEquivalent)
        XCTAssertTrue(item.keyEquivalentDisplay.contains("⌘"))
        XCTAssertTrue(item.keyEquivalentDisplay.contains("N"))
    }

    func testMenuTitleFallbackParsing() {
        // AX가 cmdChar를 안 주는 경우 title "열기 ⌘O"에서 fallback 파싱
        let (char, mods) = MenuEnumerator.parseKeyEquivalent(in: "열기 ⌘O")
        XCTAssertEqual(char, "O")
        XCTAssertNotEqual(mods & KeyboardUtil.cmdMask, 0)
    }

    func testMenuItemSeparator() {
        let sep = MenuItem(title: "─", isSeparator: true)
        XCTAssertTrue(sep.isSeparator)
        XCTAssertFalse(sep.hasKeyEquivalent)
    }

    func testAppCategoryDisplayName() {
        XCTAssertEqual(AppCategory.utilities.displayName, "category.app.utilities".localized)
        XCTAssertEqual(AppCategory.productivity.displayName, "category.app.productivity".localized)
        XCTAssertEqual(AppCategory.photoVideo.displayName, "category.app.photo_video".localized)
        XCTAssertEqual(AppCategory.socialNetworking.displayName, "category.app.social_networking".localized)
    }

    func testAppCategoryMigration() {
        // 기존 6개 카테고리 → 신규 표준 체계 자동 이관
        XCTAssertEqual(AppCategory.migrate("browser"), .utilities)
        XCTAssertEqual(AppCategory.migrate("developer"), .uncategorized)
        XCTAssertEqual(AppCategory.migrate("communication"), .socialNetworking)
        XCTAssertEqual(AppCategory.migrate("media"), .photoVideo)
        XCTAssertEqual(AppCategory.migrate("productivity"), .productivity)
        XCTAssertEqual(AppCategory.migrate("uncategorized"), .uncategorized)
    }

    func testKeyboardUtilDisplayString() {
        // Cmd(1<<8) + Shift(1<<9) + H(4) = "⌘⇧H"
        let display = KeyboardUtil.displayString(keyCode: 4, modifiers: 1 << 8 | 1 << 9)
        XCTAssertTrue(display.contains("⌘"))
        XCTAssertTrue(display.contains("⇧"))
        XCTAssertTrue(display.hasSuffix("H"))
    }

    /// 등록된 조합 조회 — 실제 Carbon 등록에 의존하지 않아야 한다.
    ///
    /// 이전 구현은 `HotKeyService.shared`에 ⌘H를 **실제로 등록하고 해제하지 않았다.**
    /// 그 결과 ① 테스트 런타임 내내 ⌘H를 점유해 이후 테스트에 영향 주고
    /// ② `comboByID`는 등록 **성공 시에만** 채워지므로 다른 앱이 ⌘H를 잡고 있으면
    /// 이 테스트가 환경에 따라 실패했다.
    /// 조합 충돌 가능성이 낮은 F12를 쓰고, 등록 여부와 무관하게 동작하도록 바꾸고
    /// 테스트 종료 시 반드시 해제한다.
    func testRegisteredCombosExcludesSelf() {
        let service = HotKeyService.shared
        let bindingID = UUID()
        let combo = HotKeyCombo(keyCode: 96, modifiers: KeyboardUtil.shiftMask, displayString: "⇧F12")
        let registered = service.register(bindingID, combo: combo)
        defer { service.unregister(bindingID) }

        // 제외 대상이 아닌 항목은 조회에 포함되어야 한다
        let excluding = UUID()
        let combos = service.registeredCombos(excluding: excluding)
        if registered {
            XCTAssertTrue(
                combos.contains { $0.matches(combo) },
                "등록에 성공했다면 조회에 포함되어야 함"
            )
            // 자기 자신은 제외되어야 한다
            let selfExcluded = service.registeredCombos(excluding: bindingID)
            XCTAssertFalse(
                selfExcluded.contains { $0.matches(combo) },
                "excluding에 준 ID는 조회에서 빠져야 함"
            )
        } else {
            // OS 선점 등으로 등록에 실패해도 테스트는 통과해야 한다 (환경 의존 제거)
            XCTAssertTrue(
                combos.contains { $0.matches(combo) } == false,
                "등록 실패 시 comboByID에 없어야 함"
            )
        }
    }

    /// unregister가 Carbon 핸들과 내부 사전을 모두 정리해야 한다 (E-MAC-HTKEY-1005)
    /// — 핫키 계층 상태 전이 테스트. TEST_HOST가 실제 앱이라 인프로세스로 검증된다.
    func testUnregisterClearsInternalDictionaries() {
        let service = HotKeyService.shared
        let bindingID = UUID()
        let combo = HotKeyCombo(keyCode: 97, modifiers: KeyboardUtil.controlMask, displayString: "⌃F13")
        _ = service.register(bindingID, combo: combo)

        service.unregister(bindingID)

        XCTAssertTrue(
            service.registeredCombos(excluding: UUID()).contains { $0.matches(combo) } == false,
            "unregister 후 comboByID에 남으면 안 됨"
        )
        // 같은 ID로 재등록이 가능해야 한다 (이전 핸들 잔존 검사의 대리 지표)
        XCTAssertTrue(
            service.register(bindingID, combo: combo),
            "unregister 후 같은 ID로 재등록되어야 함"
        )
        service.unregister(bindingID)
    }

    // MARK: - 동작(단축어)

    func testShortcutStepToBinding() {
        let step = ShortcutStep(type: .wait, target: "2.0", title: "대기 2초")
        let binding = step.toBinding()
        XCTAssertEqual(binding.actionType, .wait)
        XCTAssertEqual(binding.target, "2.0")
        XCTAssertTrue(binding.combo.isEmpty)
    }

    func testShortcutStepSummary() {
        XCTAssertEqual(ShortcutStep(type: .paste, target: "clipboard").summary, "ui.editor.step_clipboard".localized)
        XCTAssertEqual(ShortcutStep(type: .paste, target: "안녕").summary, "안녕")
        XCTAssertEqual(ShortcutStep(type: .wait, target: "3").summary, "step.wait_fmt".localizedFormat("3"))
        XCTAssertEqual(ShortcutStep(type: .macro, target: "36,36").summary, "step.keys_fmt".localizedFormat(2))
        XCTAssertEqual(
            ShortcutStep(type: .system, target: SystemActionType.mute.rawValue).summary,
            "system.action.mute".localized
        )
    }

    func testShortcutStepsCodableRoundTrip() {
        let steps = [
            ShortcutStep(type: .launchApp, target: "com.apple.Safari", title: "Safari"),
            ShortcutStep(type: .wait, target: "1.0", title: "대기"),
            ShortcutStep(type: .system, target: SystemActionType.mute.rawValue, title: "음소거"),
        ]
        let data = try! JSONEncoder().encode(steps)
        let decoded = try! JSONDecoder().decode([ShortcutStep].self, from: data)
        XCTAssertEqual(decoded.count, 3)
        XCTAssertEqual(decoded[0].type, .launchApp)
        XCTAssertEqual(decoded[0].target, "com.apple.Safari")
        XCTAssertEqual(decoded[2].type, .system)
        XCTAssertEqual(decoded[2].target, SystemActionType.mute.rawValue)
    }
}
