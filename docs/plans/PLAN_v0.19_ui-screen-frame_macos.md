---
id: PLAN_v0.19
title: v0.19 — UI 고정프레임·다중모니터·undo
status: done
platform: macos
priority: P1
budget: S
created: 2026-09-22
branches: feat/macos-p0-critical-fixes
---

# PLAN v0.19 — UI 고정프레임·다중모니터·undo (macOS)

> S 경로: workflow(TODO) + quality 핵심만. 1커밋 1관심사. 시각 회귀 주의 — 묶음별 수정.

## Scope

1. **다중모니터** — `NSScreen.main` 5곳 (AppDelegate 270/559/739/873/897) → 창 기준 `screen(for:)` 유틸 (창 소속 화면 → main → screens.first)
2. **토스트 고정폭 340** — 한글 메시지 넘침 → 최소폭 유지 + `fixedSize`/flexible 폭
3. **StepSettings 시트 480×680 고정** — 소형 창 밀림 → min 크기 + flexible
4. **HotKeyRecorder 300×80 고정** — 긴 단축키 잘림 → min + flexible
5. **HUD 4열 고정** — 소형 화면 열 증발 → 화면 폭 기반 열 수 동적
6. **`© 2026` 하드코딩** (AboutView:86) → `Calendar` 연도
7. **`esc` 비로컬라이즈** (CommandPaletteView:300) → Localizable 키
8. **undo/redo** — Edit 메뉴 셀렉터만 존재 → 최소 `registerUndo` 경로 1개 연결 또는 미구현 시 메뉴 비활성 + 백로그 명시

## DoD

- [x] 빌드 통과: `./build_and_run.sh build macos`
- [x] 테스트 통과: `./build_and_run.sh test macos unit` (171건 0실패, 2 skip)
- [x] 로컬 게이트: `python3 scripts/check-localizable.py`
- [x] `git checkout -- Sources/ApexKey/Info.plist` 후 커밋
- [x] TODO/CHANGELOG 동기화

## 비대상 (시각 회귀·범위 커서 후속)

- 접근성 일괄(VoiceOver label·대비 4.5:1) — 별도 과제
- 포커스 스틸 전면 복구 — 별도 과제
- 대형 시트류 전수 고정프레임 교체 — Critical 4종만 이번
