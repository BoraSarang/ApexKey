# PLAN_v0.31_workflow-steps_macos — 워크플로우 3종 (메뉴 피커 + 특정앱 열기 + 최소화)

> status: done (2026-10-15 — 544건 0실패 · i18n 1007키 · 신규 경고 0)
> 전제: `docs/STATUS.md` 2026-10-14 (537건·v1.5.0) · T-036 `[ ]` 미구현
> 사용자 시나리오: ① IINA 실행 ② A/AA 열기 ③ 메뉴 반복 클릭 ④ 창 최소화

## 1. 목표

- T-187 (T-036 실구현): 워크플로우 단계에서 앱+메뉴 선택 UI. `target=""` 구조적 실패 해소.
- T-188: 특정 앱으로 파일 열기. `.file`이 기본앱으로만 열리는 한계 해소.
- T-189: 전면 창 최소화. `SystemActionType` 8종에 없음 해소.

## 2. 설계 (마이그레이션 회피 우선)

- T-187: 신규 `Views/StepSettings/MenuCommandSettingsView.swift`. 앱 피커(`LaunchAppSettingsView` 패턴 차용, bundleID만) + 메뉴 트리(`MenuChoiceNode` 재사용하되 단계 생성에 배선). 저장: `target=bundleID`, `title=item.title`, `menuPath=item.menuPath`. 순수 로직 `MenuCommandSelection.apply` 분리 → 단위테스트. 실행은 기존 `ExecutionEngine default → ActionExecutor.menuCommand` 그대로 (`Services/ActionExecutor.swift:86`).
- T-188: `ShortcutStep` 필드 추가 안 함 (blob 키 누락 내성 E-MAC-STORE-5008 회피). `actionParameters` JSON에 `FileOpenConfig{appBundleID}` (TextActionConfig 패턴). `ExecutionEngine.executeFile` 신설 → `ActionExecutor.openFile(path:withApp:)` (`NSWorkspace.open URLs withApplicationAt`, 앱 미지정시 기존 동작). UI는 `DefaultSettingsView` `.file` 분기 확장 (경로 + 앱 선택 옵션).
- T-189: `SystemActionType.minimizeFrontWindow` 1종 추가 (8→9). `SystemActionExecutor`에 AppleScript `keystroke "m" using command down` (전면 앱 표준 최소화). 테스트 `testVerifySystemActionCatalogComplete` 카운트 8→9 갱신.

## 3. i18n (en+ko 동시, 게이트 `check-localizable.py`)

- `menucommand.*` (앱 선택·메뉴 선택·미실행 안내), `file.open_with.*` (앱 선택·기본앱), `system.action.minimize` 1키. 원문 노출 방지 직접 확인.

## 4. 검증

- 신규 테스트: `MenuCommandSelectionTests` (apply 4건), `FileOpenConfigTests` (decode/encode 3건), 시스템 카운트 갱신.
- `check-localizable.py` 통과 → `xcodegen generate` → `xcodebuild clean build` 경고 0 → `test macos unit` (기본) + IINA 실동작은 사용자 확인 (§8 신규 4건은 OPEN_ITEMS로 이관하지 않고 본 PLAN DoD에 사용자 확인으로 남김).
- 비결정성 주의: `StoreCoding`만 사용, 비교 금지. AX 의존 테스트는 실측 probe + XCTSkip (T-184 패턴).

## 5. 범위 밖

- `error_message_ko.json` (OPEN_ITEMS #4 유지), 서명 (TODO #1), macOS 14 실기.
- 파일 열기 실행 인자 일반화 (`LaunchConfig.args` 확장 안 함).
