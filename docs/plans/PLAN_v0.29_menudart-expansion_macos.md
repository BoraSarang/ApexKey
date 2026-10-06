# PLAN_v0.29 — MenuDart 확장 6종 (macOS)

> 근거: MenuDart 공개 README 분석 + 코드 대조 (2026-10-06).
> 순서 원칙: 작고 확실한 것(M-02·M-05) 먼저 → 중간(M-04·M-01) → 리서치 게이트(M-03) → 정책 결정 후(M-06).
> **상태 (2026-10-06): M-01~M-06 전부 완료 (M-03 그리드 UI 포함).**
> 전체 511건 0실패(3 skip), 가드 통과, 신규 파일 클린 빌드 경고 0.
> 공통: `check-localizable.py` + `check-version.py` 통과, 클린 빌드 경고 0, 단위 테스트 동반.

## 작업 순서와 의존성

| 순서 | 항목 | 규모 | 선행 조건 |
|---|---|---|---|
| 1 | M-02 Option 대체항목 중복 제거 | S | 스파이크(대체 마커 특정) |
| 2 | M-05 클릭 무반응 토스트 | S | 없음 |
| 3 | M-04 시스템 단축키 충돌 검사 | M | 스파이크( symbolic hotkeys 매핑) |
| 4 | M-01 포인터 옆 팝업 + breadcrumb | M | M-05 (실패 피드백이 있어야 팝업에서 실행해도 안심) |
| 5 | M-03 메뉴바 아이콘 그리드 | L | **적합성 게이트** — AX 열거 스파이크 통과 시에만 착수 |
| 6 | M-06 온보딩 개편 | M | 정책 확정됨(A안 변형: 기본값 유지 + 가이드 내 즉시 수정/그대로 시작) |

---

## M-02 — Option 대체항목 중복 제거 (S)

**목표**: "각 액션 1회만 표시". 열거 시 Option 대체항목(⌥ 누르면 바뀌는 메뉴)을 숨기고 기본 항목만 남긴다.

- 스파이크: 대체항목을 구분하는 AX 마커를 먼저 특정한다. Finder 등 대체항목이 확실한 앱에서 AX 트리를 덤프해 마커(속성/플래그)를 찾는다. 마커가 없으면 휴리스틱(동일 위치 + 修飾차이)으로 폴백하되, 오탐 시 기본 항목을 지우지 않는 방향(숨김은 대체 후보만)으로 가드한다.
- 손댈 곳: `Services/MenuEnumerator.swift` — `menuItems(from:parentPath:depth:)`(:285), `makeMenuItem` 계열. HUD(`flattenedWithDepth` :82), AppDetail 트리(`MenuTreeView`), 검색(`shortcutItems` :52)이 모두 같은 열거를 쓰므로 수정 1곳으로 전 표면 반영.
- 테스트: 가짜 AX 트리 대신 `MenuItem` 배열 수준 dedup 순수함수로 분리해 단위 테스트(대체/일반/구분불가 3종). 실기 확인 1건(Finder).
- i18n: 불필요(UI 문구 없음).
- DoD: Finder HUD에서 대체항목 미노출 + 기존 464건 유지.
- 리스크: 마커 부재 시 휴리스틱 오탐 → 기본값 "숨기지 않음"으로 안전 귀결.

## M-05 — 클릭 무반응 토스트 (S)

**목표**: 메뉴 실행이 실패하면 조용히 닫지 말고 이유를 토스트로 알린다.

- 손댈 곳: `AppDelegate+PaletteHUD.swift` `runMenuItem(_:in:)`(:252) — 현재 `performAction` 후 로그만 남기고 `hideMenuHUD()`한다. `MenuActionResult`(:402, 이미 `description` 로컬라이즈됨)를 `showToast(title:message:success:)`(`AppDelegate+Windows.swift:291`)로 연결. 성공은 기존 `showSuccessToast` 정책대로 무음 유지.
- 범위: HUD 2종(floating `MenuCheatSheetView`, overlay `MenuHUDOverlayView`)의 `onRun` 경로. 팔레트 `executeBinding`은 이미 `notifyToast`(`ConfigStore+HotKeys.swift:296`)를 쓰므로 제외.
- 테스트: `MenuActionResult` → 토스트 페이로드 매핑 단위 테스트(성공 무음/실패 4종 문구). AX 불필요.
- i18n: 신규 키 불필요 시 기존 `description` 재사용, 부족분만 `toast.reason.*` 추가(ko/en 동시).
- DoD: 권한 없음/앱 미실행/메뉴 없음/press 실패 각 상황에서 토스트 노출 + 성공 시 무음.
- 리스크: 낮음. `runMenuItem`이 `@discardableResult`라 시그니처 변경 없이 내부만 수정.

## M-04 — 시스템 단축키 충돌 검사 (M)

**목표**: MenuDart식 "시스템 단축키와 겹치면 경고 + 이동/강행/취소". ApexKey의 `HotKeyConflict`(:1-60)는 내부 충돌만 다루므로 신규 축이다.

- 스파이크: `~/Library/Preferences/com.apple.symbolichotkeys.plist`를 읽어 시스템 단축키 집합을 뽑고, Carbon keyCode+flags와 비교 가능한 형태로 매핑한다. 매핑표가 불완전한 조합은 "알 수 없음"으로 표시하고 차단하지 않는다(오탐이 과차단보다 나쁨).
- 손댈 곳: 신규 `Services/SystemHotkeyInspector.swift`(읽기+매핑 순수 로직) + `Views/HotKeyRecorderView.swift`(확정 플로우에 3지선다 연결) + `ConfigStore+HotKeys.swift`의 `set*Hotkey` 5종(:48-124) 및 `setPanelToggleHotkey` — 반환형이 이미 `errorMessage` 계열이므로 충돌 경고를 같은 채널로 전달.
- 테스트: fixture plist로 매핑 단위 테스트(알려진 조합 5종 + 미지정 조합은 차단 안 함). 실기는 로컬에서만.
- i18n: `hotkey.conflict.system_*` 키 추가(ko/en 동시) — 경고문 + 3버튼(이동/그래도 등록/취소).
- DoD: 시스템 예약 조합 등록 시 경고 + 3지선다 동작 + 기존 내부 중복 검사와 공존.
- 리스크: symbolic hotkeys 포맷이 macOS 버전 따라 변동 → 파싱 실패 시 기능만 비활성(빌드 실패 아님)으로 폴백.

## M-01 — 포인터 옆 팝업 + breadcrumb (M)

**목표**: "메뉴가 포인터에게 온다". HUD를 화면 상단 고정(`placeMenuHUD` :265, 460×420 고정)에서 포인터(`NSEvent.mouseLocation`) adjacent 배치로 바꾸고, 서브메뉴를 제자리 전개 + breadcrumb(앱 › 메뉴 › 하위)으로 점프백한다.

- 손댈 곳:
  - `AppDelegate+PaletteHUD.swift` — `placeMenuHUD(_:)`(:265)를 앵커 기반으로 교체(포인터 위치 + 화면 경계 클램프, `screen(for:)` 유틸 사용 — T-183 계열의 NSScreen 교훈). `toggleMenuHUD`(:130) 열거 흐름은 그대로.
  - `Views/MenuCheatSheetView.swift`(:~306) + `Views/MenuHUDOverlayView.swift`(:~355) — 경로 스택 상태 + breadcrumb 바 + 레벨 점프. 기존 `currentItem/moveSelection` 키보드 내비와 공존해야 한다.
  - AppDetail의 `MenuTreeNode`(`Views/AppDetailView.swift:525-609`)는 DisclosureGroup 재귀라 건드리지 않는다(팝업 전용 breadcrumb).
- 선행 확인: HUD 패널(`KeyCapablePanel`)이 비활성화 상태로 키를 받는 현재 구조를 유지할 것 — 포커스를 빼앗으면 "작업 앱 메뉴바 유지"가 깨진다(MenuDart가 지키는 바로 그 속성).
- 테스트: 배치 순수함수(앵커+화면 경계 클램프) 단위 테스트 + breadcrumb 점프 상태 테스트. 패널 실기는 수동.
- i18n: breadcrumb 구분자 정도, 신규 키 최소.
- DoD: 포인터 옆 표시 + 서브메뉴 제자리 전개 + breadcrumb 복귀 + 포커스 탈취 없음 + 화면 밖 넘침 없음(다중모니터 포함).
- 리스크: 중간. 패널 배치+상태 변경이라 HUD 회귀 테스트(수동 체크리스트 필요).

## M-03 — 메뉴바 아이콘 그리드 (L, 게이트 있음)

**목표**: 신규 표면. 우측 메뉴바 아이콘(Control Center 포함, 노치 뒤 숨은 것까지)을 그리드에 모아 실제 아이콘을 대신 클릭한다.

- **게이트 스파이크 (착수 조건)**: 다른 앱의 상태 아이템을 AX로 안정 열거할 수 있는지 프로브로 먼저 확인한다(T-184의 실측 probe 패턴). 현재 코드베이스에 타 앱 상태 아이템 열거는 전무(`AppDelegate+StatusItem.swift`는 자사 아이템만 생성/제거). 불안정 판정이면 문서화된 wont-do로 종결하고 본 작업에 착수하지 않는다.
- **게이트 결과 (2026-10-06): 조건부 PASS.** `MenuBarAgent.AXExtrasMenuBar → AXGroup → AXMenuBarItem`(Wi-Fi·배터리·제어센터·시계, `AXDescription`+`AXPress`) + 앱별 extras 직속(서드파티). ControlCenter 프로세스 자체는 값 없음(MenuBarAgent 경로로 커버). 구현됨: `Services/MenuBarIconEnumerator.swift`(열거/정렬/AXPress·AXShowMenu·CG 우클릭 폴백/포인터 워프). 미구현(후속): 그리드 UI + 진입점 + 설정.
- **그리드 UI 완료 (2026-10-06).** `Views/MenuBarIconsGridView.swift`(LazyVGrid, 방향키/Space·Return/Esc, 탭 활성화) + `⌥⌘]` 예약 핫키(ConfigStore 배선·Settings 변경/복원·온보딩 6행) + 메뉴바 우클릭 메뉴 진입점 + 설정(행당 1-16, Space/Return 뒤바꿈). 썸네일=앱 아이콘, 시스템=SF Symbol. `MenuBarIconsGridTests` 10건. 전체 511건 0실패.
- 본 작업(게이트 통과 시): 열거 서비스 신규 + 그리드 뷰 신규(HUD와 별도 패널) + AX 클릭(좌/우 선택) + 클릭 후 원래 위치에 열리는 메뉴로 포인터 이동 + 무반응 토스트(M-05 재사용). 썸네일은 Screen Recording 권한이 있으면 실제 아이콘, 없으면 앱 아이콘 폴백(MenuDart와 동일 정책) — 권한 플로우는 `Utils/PermissionHelper.swift` 재사용, `NSAppleEventsUsageDescription`급 신규 usage description 필요 여부 확인.
- 설정: 행당 아이콘 수(1-16), 팝업 열릴 때 포인터 착지(첫 항목/중앙)는 MenuDart 설정을 그대로 차용.
- 테스트: 게이트 통과 구조에 맞춰 열거 실패 시 빈 그리드 + 안내(크래시 금지) 테스트. 실기는 수동 + 권한 상태별 매트릭스.
- i18n: `menubar.*` 키 묶음 신규(ko/en 동시).
- DoD: 게이트 판정 문서 + (통과 시) 숨은 아이콘 포함 표시 + 좌/우 클릭 동작 + 포인터 이동 + 권한별 폴백.
- 리스크: 높음. 비공개 영역 의존이라 OS 업데이트에 깨질 수 있음 — 격리된 서비스로 유지하고 코어와 얽지 않는다.

## M-06 — 온보딩 개편 (M, 정책 결정 후)

**목표**: 첫 실행 2분 가이드(권한 + 단축키). MenuDart의 "처음엔 단축키 없음 + 원클릭 기본값"을 차용할지가 핵심 결정이다.

- 결정 (2026-10-06 확정): **A안 변형**. 기본값 6종(`ConfigStore+HotKeyDefaults.swift`)은 그대로 두되, 가이드 안에서 바로 수정 가능 + 수정 안 하면 "그대로 시작"으로 통과.
- 가이드 구성(2분): ① 권한(Accessibility 필수, Screen Recording 해당 없음 — M-03와 무관) ② 단축키 확인/수정 — 6종 현재값을 행으로 나열하고 각 행에 Settings와 동일한 변경/복원(`SettingsView.swift:82-197` 행 재사용, 시트는 `HotKeyRecorderView` 그대로) + 하단 "그대로 시작" 버튼. 설정 앱에서도 전부 수정 가능하므로 가이드는 지름길일 뿐 단일 출처(`ConfigStore+HotKeys.swift` set* 계열)는 그대로.
- 손댈 곳: 첫 실행 가이드 윈도우 신규(권한 단계는 `Utils/PermissionHelper.swift` 재사용, 단축키 단계는 Settings 행 뷰 재사용으로 중복 UI 금지) + 첫 실행 판정 시 1회 표시.
- 테스트: 신규 설치/기존 설치 분기 테스트(판정 로직 순수 분리). 실기는 수동.
- i18n: `onboarding.*` 키 묶음 신규(ko/en 동시).
- DoD: 새 설치에서 2분 내 권한+단축키 완료 가능 + 기존 설치에 영향 없음.
- 리스크: B안은 기본 동작 변경이라 반발 가능 — A가 안전, B는 릴리스 노트 고지 필요.

---

## 공통 검증

1. `python3 scripts/check-localizable.py` — 신규 UI 문구는 전부 `.localized` 키(ko/en 동시 추가).
2. `python3 scripts/check-version.py` — 본 PLAN은 버전 변경 없음.
3. `./build_and_run.sh test macos unit` + 클린 빌드 경고 0.
4. `docs/TODO.md`에 M-01~M-06 등록, `docs/STATUS.md` 수치 갱신, M-03 게이트 판정은 `docs/OPEN_ITEMS.md`에도 링크.
