---
id: PLAN_v0.18
title: v0.18 — UI/UX 9건 수정
status: done
platform: macos
priority: P1
budget: S
created: 2026-09-21
branches: feat/macos-p0-critical-fixes
---

# PLAN v0.18 — UI/UX P1 수정 (macOS)

> S 경로: workflow(TODO) + quality 핵심만. 1커밋 1관심사.

## Scope (9)

1. `ConfigStore` alwaysOnTop init 리셋 → 저장값 복원
2. `VariableResolver`/`UseModelExecutor`/`AIModels` 한글·비ASCII 변수명 regex → `[^{}:]+`
3. `ExecutionEngine.executeStopShortcut` → `actionParameters`에서 `StopShortcutAction` decode → outputVariable 반영; `ShortcutEditorView` encode 경로 신설
4. `MenuEnumerator.runOSAScript` stderr → 권한거부(-1743)/앱미실행(-600)/메뉴없음 분류
5. 하드코딩 `"Apple"`/`"서비스"` → `excludedMenuBarTitles` 상수 집합
6. 빈 AXMenu 성공+0건 → warn 승격 (`E-MAC-MENU-7006`)
7. `ReleaseChecker` SemVer 프리릴리스 정확 비교 (기존 `testSuffixStripped` 유지) + HTTP 403/429 분기 (`rateLimited`)
8. `AppleLanguages`는 `LanguageManager.setLanguage` 단일 출처화 (`ConfigStore.swift:67,70` 제거)
9. `ThemeManager` 하드코드 pref 키 → `ConfigStore.PrefKeys` 상수 (rawValue 동일 → 마이그레이션 불필요)

## DoD

- [x] 빌드 통과: `./build_and_run.sh build macos`
- [x] 테스트 통과: `./build_and_run.sh test macos unit` (166+건, 0실패)
- [x] 로컬 게이트: `python3 scripts/check-localizable.py`
- [x] `git checkout -- Sources/ApexKey/Info.plist` 후 커밋
- [x] TODO/CHANGELOG 동기화
