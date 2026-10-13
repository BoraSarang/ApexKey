# PLAN_v0.30 — 단축키 키캡 표시 방법 (macOS)

> status: done (2026-10-13)
> 근거: `Mac-Keycap-Studio.html` 6종 분석 + 전수 조사 13곳 통일

## 1. 목표

붙여쓰기 `⌘⇧N` boundaries 없음 + 화면마다 다른 캡슐(회색/accent/배경없음/caption) 해소.
PNG 없이 코드 렌더로 6종 선택 + 미리보기 제공. 라이트/다크·fontScale·커스텀테마 대응.

## 2. 변경

* 생성: `KeyboardUtil.modifierTokens/keyToken/normalizedSearchText` (`Utils/KeyboardUtil.swift`),
  `MenuItem.keycapModifiers/keycapKey/normalizedSearchText` (`Models/MenuItem.swift`).
  기존 `displayString/keyEquivalentDisplay` joined 유지 (로그·폴백).
* 공통: `Views/Common/KeycapView.swift` 신규 (6종 분기, theme 토큰 색, S22/M28/L40 대신 행 높이 맞춤).
* 저장: `KeycapStyle` (`Models/KeycapStyle.swift`, rawValue 고정) + `PrefKeys.keycapStyle`
  + `ConfigStore.keycapStyle` + `setKeycapStyle` (`ConfigStore.swift`, `ConfigStore+Preferences.swift`).
* 설정: `SettingsView` 일반탭 `settings.keycap` 그룹 — Picker 6종 + 샘플 `⌘⇧N/⌥⌘]/⌃⌥D` 미리보기.
* 통일 13곳: Settings, Onboarding, AppDetail(4), Station(2), Automation, Editor, Recorder(large),
  Palette(2), Conflict, CheatSheet, HUD, KeyPress 설정.
  검색 5곳 정규화: Palette, AppDetail, CheatSheet, HUD, Bindings.
* i18n: `settings.keycap.*` 9키 ko/en 추가 (967키 일치).
* 테스트: `KeycapStyleTests` 10건 신규.

## 3. 검증

* `test macos unit` 525건 0실패 (5 skip — 호스트 권한·미설치 앱, 기존 환경성).
* `check-localizable.py` 통과.
* 클린 빌드 SUCCEEDED — 신규 파일 경고 0. 기존 경고(AppIcon 41, Combine, NSEvent Sendable)는
  Xcode 버전由来 기존분, 이번 변경과 무관.
* 라이트/다크: theme 토큰 사용이라 `LightTheme/DarkTheme` + 커스텀테마 자동 대응.
  고정색(`#111/#FFF`) 미사용. 실기 육안은 사용자 확인 대기(OPEN_ITEMS §8에 편입).

## 4. 남은 것

* 사용자 실동작: 설정에서 6종 전환 → 13곳 반영 육안 + 라이트/다크 전환 확인.
* 기본값은 `symbolUpper`(Studio 추천). 기존 `symbol` 유지 원하면 설정에서 1번 선택.

## 5. T-186 지정됨 강조 (2026-10-13, v1.5.0에 포함)

* `KeycapView.highlighted` — 본래 단일 캡슐 붙여쓰기 + 엑센트색(`accent 0.16` 배경 + `accent 0.35` 테두리).
  분리형 중립 렌더는 그대로. `false`가 기본이라 미지정·메뉴고유·팔레트·HUD·레코더는 무영향.
* 적용: 앱상세 실행/지정행 · 설정 칩 · 온보딩 칩 · 워크플로우 콤보 · 자동화 콤보 · 에디터 헤더 +
  목록 `⌘N` 뱃지 강화(초록 semibold + 테두리).
* 기능 추가 아님 — "설정됐는지 안 보여서 못 쓰는" 마찰 수정. 새 설정·새 문자열 없음.
* 설치 주의: `cp -R` 전 `rm -rf` 필수 — 중첩 시 옛 바이너리 실행됨.
