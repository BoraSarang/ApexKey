# ApexKey — 기능 검증 체크리스트 (FUNCTIONAL CHECKLIST)

> **플랫폼**: macOS · **기준 문서**: `docs/plans/PLAN_v0.1_apexkey.md` · `docs/DESIGN.md`
> **작성일**: 2026-09-01 · **상태**: 수리 완료 → 사용자 실동작 검증 대기

---

## 1. PLAN v0.1 목표 11개 대조

| # | 목표 | 상태 | 비고 |
|---|------|------|------|
| 1 | 메뉴바 전용 앱 (Dock 미표시) | 완료 | `LSUIElement=true`, 기본 `.accessory`, 설정에서 Dock 표시 가능 |
| 2 | 글로벌 핫키 패널 토글 (⌃⌥⌘H) | 완료 | **버그 수정**: 기존엔 저장만 되고 `HotKeyService.register` 미등록 → `panelToggleID` 등록 + `.togglePanel` 알림 전파. 이제 설정 창에서 단축키 변경 가능 |
| 3 | 카테고리별 앱 리스트 + 단축키 설정 여부/개수 | 완료 | Sidebar 카테고리 배지 + 행 배지 |
| 4 | 앱 실행/포커스/토글 | 완료 | **UI 신설**: AppDetailView '앱 실행/토글' 섹션(추가/변경/삭제) — 이전엔 생성 경로 없었음 |
| 5 | 타 앱 메뉴 명령 동적 열거 + 매핑 | ⚠️ 검증 필요 | 열거 코드 수정(캐스팅/Carbon flags/title fallback/로그) — **실제 표시는 사용자 확인 필수** |
| 6 | 단축키 중복 감지 | 완료 | `ConfigStore.isDuplicate` + 레코더 경고 표시 |
| 7 | 키 입력 레코더 | 완료 | `HotKeyRecorderView` 제네릭(앱메뉴/시스템/스크립트/패널 공용) |
| 8 | 수동 앱 추가(경로) + 숨김/표시 | 완료 | NSOpenPanel + 목록 토글 |
| 9 | SwiftData 설정 영속 | 완료 | PersistedApp/Binding/Script |
| 10 | Accessibility 권한 체크 + 로그인 시 시작 | 완료 | PermissionHelper + SMAppService |
| 11 | 앱 이름 현지화 (애펙스키) | 완료 | ko/en InfoPlist.strings |

## 2. v0.2 추가 기능

| 기능 | 상태 |
|------|------|
| 시스템 액션 (잠금/음소거/다크모드) | 완료 |
| 스크립트 실행 탭 | 완료 |
| 로그인 시 시작 | 완료 |
| 메뉴 명령 검색 | 완료 |

## 3. 이번 세션 수리 내역

| 항목 | 수정 내용 |
|------|-----------|
| Cmd+, 빈 설정 창 | 원인 = SwiftUI `Settings { EmptyView() }` scene이 Cmd+, 가로챔 → **제거**, AppKit mainMenu(⌘,)가 처리. macOS15 API(`defaultLaunchBehavior`) 미사용 대신 실행 시 SwiftUI 빈 윈도우를 AppDelegate가 숨김 |
| 우클릭 메뉴 위치 이상 | 버튼 로컬 좌표 `(0, height+4)`가 위쪽을 가리켜 메뉴가 뒤집힘 → **화면 좌표로 변환**해 버튼 하단 아래에 `popUp` |
| 패널 토글 핫키 미동작 | `panelToggleID`(예약 UUID)로 `register` + 감지 시 `.togglePanel` post → AppDelegate `togglePanel()` |
| 글로벌 단축키 설정 UI 부재 | `launchApp` 단축키 = AppDetailView 새 '앱 실행/토글' 섹션. 패널 단축키 = 설정 창에서 변경/복원 |
| 메뉴 단축키 미획득(추정 원인 3건) | ① `cmdModifiers as? UInt32` NSNumber 캐스팅 실패 → `(as? NSNumber)?.uint32Value` ② `MenuItem` carbon 상수 `1<<0` ≠ AX Carbon flags `1<<8` → `KeyboardUtil` 상수와 일치 ③ AX cmdChar 비노출 시 title(`⌘O`) fallback 파싱 |
| 강제/불필요 다운캐스트 | `as! AXUIElement?` 제거, `as?`→성공 status에서 `as!`, CFTypeRef 브리징 정리 |
| 디버그 패널 부재 | **신설**: `Logger` 링버퍼(2000줄)+`DebugLogView`(필터/자동스크롤/복사/지우기)+우클릭 메뉴 '디버그 로그' 항목 |
| 디버그 메시지 부족 | 진입점 로그 대대적 추가: 앱 시작/종료, 메뉴바 아이템, 클릭 분기, 패널 토글, 핫키 등록/감지/실행, 메뉴 열거 시작/완료, ActionExecutor/AppSwitcher/시스템/스크립트 |
| E-MAC 에러코드 | 기존 코드 사용, 신규: `E-MAC-MENU-3003`(잘못된 URL) |

## 4. 검증 항목 (사용자 직접 확인)

- [ ] **Cmd+,**: SwiftUI 빈 설정 창 대신 우리 설정 창이 뜨는지
- [ ] **우클릭 메뉴**: 버튼 바로 아래 정상 위치에 원하는 방향(아래 화살표)으로 팝업되는지
- [ ] **메뉴 단축키 목록**: 앱 상세에서 단축키(⌘N 등)가 채워져 표시되는지 (디버그 로그 `[MENU] 열거 완료: ... → 메뉴바 N개 메뉴`)
- [ ] **⌃⌥⌘H**: 패널 열기/닫기 (디버그 로그 `[HOTKEY] 패널 토글 핫키 감지` → `[PANEL] 열기/닫기`)
- [ ] **앱 실행/토글**: AppDetailView에서 단축키 추가 후 전역 동작
- [ ] **설정 창**: 패널 단축키 변경 → 즉시 반영되는지
- [ ] **디버그 로그 창**: 우클릭 메뉴 → '디버그 로그'로 실시간 로그 확인 (필터/복사)
- [ ] **Accessibility**: 설정에서 권한 상태 '✅ 허용됨' 확인 후 메뉴 열거

## 5. 알려진 한계/리마인더

- macOS 14 미만(Runtime)의 `WindowGroup` 빈 윈도우 숨김은 이전 방식대로인데 현재 실행 환경(macOS 26) 검증 범위 외. (배포 타깃 14.0 컴파일만 보장)
- AX 메뉴 `performAction`은 실행 대상 앱이 현재 능동 접근성 권한 하에서 동작해야 함. 일부 앱(Electron 등)은 cmdChar 비노출 → 그 경우에도 title fallback으로 대체.
- 레코더의 중복 감지는 `bindings` 배열 기준 — 패널 토글 핫키(예약 ID)와의 충돌은 미감지.

## 6. 빌드/테스트

- [x] `xcodegen generate` 통과
- [x] `xcodebuild build` — **BUILD SUCCEEDED** (경고 2건: activateIgnoringOtherApps deprecated / let 권장 — 러닝타임 영향 없음)
- [x] `xcodebuild test` — **TEST SUCCEEDED (8개 통과)**
- [x] `~/Applications/ApexKey.app` 재설치 완료