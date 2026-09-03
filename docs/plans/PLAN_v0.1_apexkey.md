# PLAN v0.1 — ApexKey (macOS 글로벌 핫키 매니저)

> **작성일**: 2026-09-01
> **플랫폼**: macOS (SwiftUI + AppKit, xcodegen)
> **상태**: 초기 개발 계획
> **제작자**: BoRaSaRang

---

## 1. 개요

**ApexKey(애펙스키)** 는 macOS 메뉴바 전용 글로벌 핫키 매니저입니다.
글로벌 핫키(`⌃⌥⌘H`)로 패널을 열어, 카테고리별 앱 리스트에서 앱을 선택하고,
**해당 앱에 설정된 메뉴 단축키를 AXUIElement로 직접 열거**하여 그 중 원하는 것을
글로벌 키로 매핑해 실행합니다.

> "나만 있으면 다 돼" — 최상위(정점, Apex)에 오른 단축키라는 컨셉.

---

## 2. 목표 (v1.0)

1. 메뉴바 전용 앱 (Dock 미표시) — `NSStatusItem` + `MenuBarExtra`
2. 글로벌 핫키로 패널 토글 (기본 `⌃⌥⌘H`)
3. 카테고리별 앱 리스트 + 각 앱의 글로벌 단축키 설정 여부/개수 표시
4. 앱 실행/포커스/토글 (`NSWorkspace.open` + AXUIElement `raise`)
5. **타 앱 메뉴 명령 동적 열거** (AXUIElement 재귀) + 글로벌 키 매핑
6. 단축키 중복 감지 (시스템/타 등록 키와 충돌 표시)
7. 키 입력 레코더
8. 수동 앱 추가(경로 지정) + 앱 숨김/표시
9. SwiftData로 설정 영속 저장
10. Accessibility 권한 체크 + 로그인 시 시작
11. 앱 이름 현지화 (영문 출력: 애펙스키)

---

## 3. 비기능 요구 (AGENTS.md 컴플라이언스)

- **네이티브 필수**: SwiftUI만 (다른 플랫폼 금지), AppKit은 필요 시에만
- **번들ID**: `com.borasarang.ApexKey`
- **빌드·테스트**: `xcodebuild` 필수 (`swift build/test` 금지)
- **결과물**: `~/Applications/ApexKey.app`
- **로거**: DebugLogger 경유, `[ERROR] E-MAC-...` 에러코드
- **언어**: 응답·추론·문서 모두 한국어
- **문서 우선**: PLAN + TODO + DESIGN 순서

---

## 4. 기술 스택

| 영역 | 기술 |
|------|------|
| 언어 | Swift 5.9 |
| UI | SwiftUI + AppKit(NSStatusItem) |
| 글로벌 핫키 | Carbon `RegisterEventHotKey` |
| 메뉴 열거/실행 | ApplicationServices `AXUIElement` |
| 설정 저장 | SwiftData |
| 프로젝트 | xcodegen (`project.yml`) |
| 타깃 | macOS 14.0+ |

---

## 5. UI 구조

### 5.1 메인 패널
- 좌측 사이드바: 기능 탭 (앱 단축키 / 시스템 / 스크립트)
- 콘텐츠: 카테고리별 앱 리스트
  - 각 행: 앱 아이콘 + 이름 + 글로벌 단축키 설정 여부(🟢/⚪) + 등록 수 + [설정] 버튼
  - 카테고리: 브라우저 / 개발 / 생산성 / 기타 / 숨김
  - 하단: [+ 앱 추가] [숨김 앱 보기]

### 5.2 앱 단축키 뷰 (앱 클릭 시)
- 상단: 이미 설정된 글로벌 단축키 목록 (추가/편집/삭제)
- 하단: **AXUIElement로 열거한 해당 앱의 메뉴 단축키** 목록
  - 중복 ⚠️ 표시, 항목 클릭 → 키 레코더로 이동

### 5.3 키 레코더
- 키 입력을 받아 글로벌 키 매핑
- "해당 앱이 활성화된 때만 실행" 옵션

---

## 6. 흐름

```
핫키(⌃⌥⌘H) → 메인 패널
  ↓ 앱 클릭
앱 단축키 뷰
  ├─ 상단: 설정된 글로벌 단축키 (편집/삭제)
  └─ 하단: 해당 앱 메뉴 단축키 (AX 열거, 중복 표시)
        ↓ 항목 클릭
키 레코더 → 글로벌 키 매핑 → 저장
```

---

## 7. 에러코드 (E-MAC)

| 코드 | 설명 |
|------|------|
| E-MAC-HTKEY-1001 | 글로벌 핫키 등록 실패 |
| E-MAC-HTSVC-2001 | HotKeyService 초기화 실패 |
| E-MAC-MENU-3001 | AX 메뉴 열거 실패 (권한/앱 비노출) |
| E-MAC-MENU-3002 | AX 메뉴 항목 실행 실패 |
| E-MAC-APP-4001 | 앱 실행 실패 (경로 없음) |
| E-MAC-STORE-5001 | SwiftData 저장 실패 |

---

## 8. 파일 구조

```
ApexKey/
├── project.yml
├── build_and_run.sh
├── .gitignore
├── AGENTS.local.md
├── Sources/ApexKey/
│   ├── ApexKeyApp.swift
│   ├── AppDelegate.swift
│   ├── Info.plist
│   ├── en.lproj/InfoPlist.strings
│   ├── ko.lproj/InfoPlist.strings
│   ├── Views/  (MainPanel, Sidebar, AppList, AppDetail, MenuCommandList, HotKeyRecorder, SettingsView)
│   ├── Models/ (AppItem, HotKeyBinding, MenuItem, ActionType)
│   ├── Services/ (HotKeyService, MenuEnumerator, ActionExecutor, AppSwitcher, ConfigStore)
│   └── Utils/ (PermissionHelper, AppFinder)
├── Sources/ApexKeyTests/
├── Resources/Assets.xcassets/
└── docs/ (PLAN / TODO / DESIGN)
```

---

## 9. 구현 순서

1. 문서 (본 PLAN + TODO + DESIGN)
2. project.yml → xcodegen → build_and_run.sh → .gitignore → AGENTS.local.md
3. 코어: HotKeyService → AppSwitcher → MenuEnumerator → ActionExecutor → ConfigStore
4. UI: MainPanel/Sidebar/AppList → AppDetail/MenuCommandList → HotKeyRecorder → SettingsView
5. 아이콘 + 현지화
6. 빌드 검증 + 테스트

---

## 10. DoD 체크리스트

- [ ] 플랫폼 명시 (macOS)
- [ ] 문서 우선 (PLAN + TODO + DESIGN)
- [ ] 코드 + DebugLogger + error_code
- [ ] 언어 한국어
- [ ] xcodebuild 빌드 성공
- [ ] `~/Applications/ApexKey.app` 설치
- [ ] 한글/영문 현지화 검증
- [ ] DoD 체크 + session 로그
