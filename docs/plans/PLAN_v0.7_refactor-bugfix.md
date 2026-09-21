# PLAN v0.7 — 전체 리팩토링 + 버그·동작 연결 점검

> 작성일: 2026-09-21 · 플랫폼: macOS · 기준: 2방향 감사 (구조+연결)
> 원칙: 동작 보존 + 성공 둔갑·연결 끊김만 수정. P1 38종 미구현·B12·대형파일 분할은 백로그.

## 1차 — 전체 리팩토링 (저위험)

| ID | 내용 | 파일 |
|---|---|---|
| G-01 | `print` → `Logger.error(E-MAC-STORE-5001)` | ThemeConfigurationStore:97 |
| G-02 | `runScriptFileResult` 인라인 PATH → `ShellEnvironment` 재사용 | ActionExecutor:228-231 |
| G-03 | `decode/encodeLaunchConfig` 실패 로그 추가 | ActionExecutor:332-347 |

## 2차 — 버그·동작 연결 (P0/P1)

| ID | 내용 | 파일 |
|---|---|---|
| B-01 | AI 3종 Bool 반환 반영 (성공 둔갑 해소) | ExecutionEngine:78-88 |
| B-02 | RunShortcut 7006/7007 실패 반환 + 재귀 depth 10 가드 | ExecutionEngine:336-349, execute depth |
| B-03 | `execute` url/file 빈값 false (executeWithDetail와 일치) | ActionExecutor:33-45 |
| B-04 | If/Repeat/Choose 설정없음 실패 반환 (취소는 성공 유지) | ExecutionEngine:154-277 |
| B-05 | `removeShortcut` 자동화 unregister (고스트 제거) | ConfigStore+Shortcuts:58-70 |
| B-06 | 편집기 `duplicateStep` 새 UUID | ShortcutEditorView:419-424 |
| B-07 | `executeBinding` 결과 토스트 + lastID 갱신 | ConfigStore+HotKeys:123-131 |
| B-08 | 예약 핫키 3종 UserDefaults 영속화 + `isDuplicate` 예약 포함 | ConfigStore, PrefKeys, Bindings |
| B-09 | 편집기 `executeShortcut` 변수/권한 포함 | ShortcutEditorView:477-487 |

## 비범위 (백로그)

- StepSettingsView 1143줄 / CustomTheme 1600줄 파일 분할
- `menuPath` 편집 UI, `actionParameters` 세부, P1 38종 미구현
- B12 RepeatRule, blob 손상 가드 (별도 설계 필요)

## 게이트

`./build_and_run.sh build macos` + `./build_and_run.sh test macos unit` (MovistPro 1건 제외 전원 통과).
