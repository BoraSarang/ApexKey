---
id: PLAN_v0.20
title: v0.20 — 대형 파일 분할 + CI pipefail
status: done
platform: macos
priority: P2
budget: S
created: 2026-09-22
branches: feat/macos-p0-critical-fixes
---

# PLAN v0.20 — 대형 파일 분할 + CI pipefail (macOS)

> S 경로: workflow(TODO) + quality 핵심만. 1커MIT 1관심사. 리팩터는 동작 불변 — 빌드/테스트 게이트 필수.

## Scope

1. **CustomTheme.swift 1600줄 분할** — 관심사별 파일 분리 (동작 불변, public 타입 유지)
   - ThemeMetadata / ThemeColors / ThemeBackground / ThemeGlass / ThemeStyleTokens / CustomTheme(+Presets) / Color+ThemeHex
2. **AppDelegate.swift 950줄 분할** — extension 분할 (stored property는 본체 유지, 접근제어 cross-file용 정리)
   - AppDelegate 본체(라이프사이클+상태) / +StatusItem / +Menus / +Windows / +URLScheme / +PaletteHUD / 상단 클래스 분리
3. **CI pipefail** — `.github/workflows/{ci,release}.yml` 모든 `run: |` 블록에 `set -euo pipefail`
   (xcodebuild `| tail`가 실패 종료코드를 삼키는 문제 — E-MAC-CI-9201)

## DoD

- [x] 빌드 통과: `./build_and_run.sh build macos`
- [x] 테스트 통과: `./build_and_run.sh test macos unit` (171/0, 2 skip)
- [x] 로컬 게이트: `python3 scripts/check-localizable.py`
- [x] `git checkout -- Sources/ApexKey/Info.plist` 후 커밋
- [x] TODO/CHANGELOG 동기화

## 커밋

1. `f011357` fix(ci): 워크플로우 run 블록에 pipefail 추가
2. `8ea19af` refactor(macos): CustomTheme.swift 1600줄 8파일 분할
3. `b7dcf50` refactor(macos): AppDelegate.swift 950줄 extension 7파일 분할

## 비대상

- 접근성/포커스/대형 시트 전수 — 별도 과제 (v0.19와 동일)
