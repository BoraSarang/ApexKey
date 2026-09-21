# PLAN v0.8 — 시스템 탭 → 프리셋 통합 + 자동화 탭

> 작성일: 2026-09-22 · 플랫폼: macOS · 기준: 사용자 설계 결정 (질문 6건 확정)
> 롤백: 태그 `pre-system-integration`

## 배경

"시스템" 탭의 9종은 결국 "스크립트 실행 단계 1개짜리 동작"의 고정 완성본이다.
동작(단축어) 편집기에서 `.system` 단계 추가로 동일 기능을 수행할 수 있으므로,
시스템 탭을 제거하고 시스템 9종을 **프리셋**으로 워크플로우 탭에서 추가할 수 있게 통합한다.

함께 확정된 사항:
- 탭 명칭: "동작" → **워크플로우** (ko/en)
- 도구 섹션: **워크플로우 + 자동화** 2개 탭 (자동화 허브 신규)
- 앱 설치 시 워크플로우 빈 상태 (seed 샘플 제거)
- 기존 시스템 바인딩 전부 해제
- 시스템 스크립트 편집(보기/테스트/수정/저장)을 동작 단계 설정(StepSettingsView)에 이관

## 구현 항목

| ID | 내용 | 파일 |
|---|---|---|
| S-01 | 명칭 변경 — `ui.shortcut` "동작"→"워크플로우" / "Shortcut"→"Workflow", 소스 내 동작·새 동작 직접 문자열 정리 | Localizable.strings(ko/en), Views |
| S-02 | 시스템 탭 제거 — SidebarView 행, MainWindowView `.tool(.system)`, SystemActionsView.swift 삭제 | SidebarView, MainWindowView |
| S-03 | 프리셋 추가 UX — "프리셋 추가" 버튼 + 시트(시스템 9종 체크박스) → 1단계 워크플로우 생성 | ShortcutStationView, ConfigStore(+addPresetShortcuts) |
| S-04 | 시스템 스크립트 편집 이관 — `SystemScriptEditorView` 공개 분리 + StepSettingsView `case .system` 임베드 | SystemScriptEditorView.swift(신규), StepSettingsView |
| S-05 | seedSampleShortcuts 제거 — 설치 시 워크플로우 0개 | ConfigStore, ConfigStore+Shortcuts |
| S-06 | 기존 `.system` 바인딩 전부 해제 + `systemBindings`/`setSystemBinding` 제거 | ConfigStore(+Bindings) |
| S-07 | 자동화 탭 — `ToolSelection.automation`, SidebarView 행, `AutomationBrowserView`(트리거 허브) + AutomationSettingsView 시트 재사용 | MainWindowView, SidebarView, AutomationBrowserView(신규) |
| S-08 | 검증 — 테스트 조정(시스템 탭 의존, seed 의존), unit + build | Test, ActionExecutor 등 |

## 명칭 결정

- 탭 이름: **워크플로우** (Workflow)
- 시스템 동작 9종: **시스템 프리셋** (System Presets)
- 시스템 스크립트: 동작 단계 `.system` 설정에서 보기/테스트/수정/저장

## 비범위 (백로그 유지)

- 대형 파일 분할, menuPath 편집 UI, blob 가드, P1 38종 미구현

## 게이트

`./build_and_run.sh test macos unit` + `./build_and_run.sh build macos`
(139건 기존 + 신규, 현지화 가드 포함)