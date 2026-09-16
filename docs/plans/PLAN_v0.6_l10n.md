# PLAN_v0.6_l10n — 잔여 문자열 다국어화 (2계층)

> 날짜: 2026-09-16 · 플랫폼: macOS · 유형: 대규모(i18n 후속)

## 배경

T-140~142(1계층: 뷰/AppDelegate/ActionType/AutomationModels/AIModels) 완료 후,
모델 displayName/displayString/summary와 일부 서비스 에러, 뷰 잔여에 한국어 리터럴이 남아 있음.
조사 결과 UI 노출 ~75건 + 사용자 노출 에러 5건 식별.

## 스코프

### 수정 (① UI-VISIBLE + ② USER-FACING ERROR)
- Models: Shortcut(색상 13 + summary · runCount/lastRun 포맷), VariableModels, FlowControlModels, AppItem
- Services: SystemActionExecutor, ExecutionEngine(에러 3), ActionExecutor(에러 1), AIAvailabilityManager(에러 1)
- ConfigStore: +Preferences(MenuHUDStyle), +Macro, +Bindings
- Views: Common/SidebarNavigation, Common/ThemeSettingsView, StepSettingsView, MenuHUDOverlayView, HotKeyRecorderView
- AppDelegate: 창 타이틀 3건

### 미수정 (④/로그/시드)
- 로그 문자열, 마법변수 토큰, 불리언 파싱(참/예/거짓), Spotlight 매칭, 초성 검색
- 시드 데이터(프리셋/예시 단축어 — 영속 데이터, 사용자 결정 "그대로 둠")

## 키 스키마

| 그룹 | 키 | 대상 |
|---|---|---|
| variable.* | type.magic/special/user · special.*(10) · value.*(10) | VariableModels |
| condition.op.* | equal/not_equal/greater/…/regex (13) | FlowControlModels |
| flow.* | true/false/repeat.count/repeat.each/repeat.while/menu_fmt | FlowControlModels |
| category.app.* | productivity/utilities/photoVideo/games/business/education/music/socialNetworking/other (9) | AppItem |
| system.action.* | lock/mute/darkMode/sleep/displayOff/screensaver/dock/finder (8) | SystemActionExecutor |
| color.name.* | red…gray (13) | ShortcutColor |
| step.* | clipboard/wait_fmt/keys_fmt/repeat_count_fmt/menu_options_fmt/run_shortcut_fmt/stop/end_repeat/number_fmt/shell_fmt/automation/find_automation/automation_run/trigger/app_intent/app_action/find_app/executed_never/executed_once/executed_fmt/last_run_none | Shortcut.summary |
| error.user.* | action_failed_fmt/script_failed/empty_script/foundation_models_unavailable | 에러 5건 |
| appearance.* | system/light/dark/mode/preset/loading/text_size/reset_help | ThemeSettingsView |

### 재사용 (신규 키 아님)
- ui.cancel(EE:280) · ui.select_option(F:380) · ui.search · settings.menu_hud.style.floating/fullscreen
- ui.editor.step_pause/set_var/output_var/use_model/writing_tool/image/comment/choose_menu/repeat
- action.repeatEach · action.variableDetail · ui.step.duplicate · settings.title · ui.menu.about · ui.menu.debug_log

## 포맷 규칙
- `%lld` = Int, `%@` = String (localizedFormat 규약 준수)

## 테스트 안전장치
`String.localized`는 Bundle.main(preferredLocalizations) 기반 → 테스트(호스티드)에서 언어 무관하게 동작하지 않음.
**ApexKeyModelTests.swift** `testAppCategoryDisplayName`(40-43)·`testShortcutStepSummary`(83-90)를
키 기반 비교(예: `XCTAssertEqual(category.displayName, "category.app.utilities".localized)`)로 재작성.

## 검증
1. strings 문법(한글 키 0 · 중복 0) → 2. `./build_and_run.sh test macos smoke` → 3. DebugPanel ERROR 0 → 4. CHANGELOG