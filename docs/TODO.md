# ApexKey — TODO

> `T-번호` 기반 작업 추적. 완료 시 [x] 체크.
> 작성일: 2026-09-01 · 마지막 갱신: 2026-09-29

## 이 문서 읽는 법

- **[x] 는 여기서 끝난 기록**이다. 읽지 말고 넘어가도 된다
- **[ ] 가 실제로 남은 일**이다. 현재 **9건** — 목록은 아래
- **[~] 는 무효화**다. 실행할 작업이 아니라 **폐기된 요구사항**이다. 구현하지 않는 것이
  의도이며, 누군가 "왜 안 하지?" 하고 되살리면 안 된다
- **에이전트가 대신할 수 없는 것**(사용자 실동작 52건·PR·서명)은
  [`OPEN_ITEMS.md`](OPEN_ITEMS.md)에 있다. 이 문서(TODO)에는 없다
- 진행 현황 전체는 [`STATUS.md`](STATUS.md), 문서 색인은 [`README.md`](README.md)

## 현재 미해결 9건 (2026-09-29)

| # | 분류 | 항목 | 상태 |
|:-:|---|---|:-:|
| 1 | **배포** | T-166 후속 — Developer ID 서명 + notarization | 🔴 **Program 가입이 선행.** 코드만으로 불가 |
| 2 | **저장** | `saveContext` → `Bool` 반환 | 🟡 **검증 수단 없음** (`PLAN_v0.24`에 근거) |
| 3 | **기능** | T-036 — 동작의 메뉴 명령 단계 실행 불가 + 앱/메뉴 선택 UI | 🟡 규모 큼 |
| 4 | **기능** | 단축키 프로필 / 빠른 전환 | 🟢 착수 가능 |
| 5 | **기능** | Choose from Menu / Use Model 단계 설정값 UI 다듬기 | 🟢 착수 가능 |
| 6 | **기능** | AI 3종 실제 FoundationModels 연동 | 🟡 **리서치 필요.** 현재는 정직한 실패 |
| 7 | **검증** | macOS 14 런타임 실기 검증 (macOS 26에서만 확인됨) | 🟡 환경 부족 |
| 8 | **품질** | 클린 빌드 경고 7종 정리 | 🟢 **이번에 발견.** "경고 0" 기록이 계속 거짓말 |
| 9 | **조사** | `StoreBlobRecoveryTests` 격리 기전 특정 | 🟢 픽스처 격리로 우회함 — 원인은 미특정 |

**에이전트가 대신할 수 없는 것**(사용자 실동작 52건·PR·macOS 14 실기)은
[`OPEN_ITEMS.md`](OPEN_ITEMS.md)에 있다. 이 문서에는 없다 — 두 목록의 경계를
섞지 않는 것이 이 구조의 목적이다.

### 무효화된 항목 `[~]` 3건 (2026-09-29 정리)

`[x]`도 `[ ]`도 아니다. **구현하지 않는 게 의도**이며 되살리면 안 된다.
- **T-132** `ADB Wi-Fi` 샘플 동작 자동 생성 → Android 미러가 `SystemActionType`으로
  이관돼 `ensureADBWifiSample()`는 삭제만 한다 (`ConfigStore.swift:384-385`)
- **T-135** 동작 고정 프리셋 → `BuiltInShortcutPresets.all = []`이 "호환용 스텁"으로
  남아 있다 (`ConfigStore.swift:509-511`)
- **L-09** "키 N 전수 존재" 주장 → **`check-localizable.py`에 키 존재 검사 로직이 없다.**
  2026-09-29에 재확인했다. 누락 키는 게이트를 통과하고 UI에 원문 키로 노출된다.
  키 수는 계속 늘므로 문서에 고정하지 않고 결함으로만 기록한다

### 미구현 액션 100종의 성격

Apple 앱 연동이 대부분이라 순수 로직으로 처리할 수 없다.
`Photos`·`Music`·`Mail`·`Calendar`·`Reminders`·`Podcasts`는 ScriptingBridge 또는
앱별 URL scheme이 필요하다 — **각 앱의 API를 먼저 조사해야** 착수 가능하다.

남은 것 중 그래도 순수 로직으로 가능한 후보:
`detectLanguage`(휴리스틱) · `recognizeText`(Vision — 프레임워크 내장이라 조사 부담 낮음) ·
`measurement`/`listActions`/`getDictionary`(Apple framework API)

---

## v0.1 — 초기 개발

- [x] T-001: 프로젝트 구조 생성 (project.yml + xcodegen + build_and_run.sh + .gitignore + AGENTS.local.md)
- [x] T-002: HotKeyService 구현 (Carbon RegisterEventHotKey) — **버그 수정: signature 저장/조회 키 불일치**
- [x] T-003: AppSwitcher 구현 (실행/포커스/토글)
- [x] T-004: MenuEnumerator 구현 (AXUIElement 메뉴 열거)
- [x] T-005: ActionExecutor 구현 (메뉴 실행/앱 실행) + 시스템 액션 실행 추가
- [x] T-006: ConfigStore 구현 (SwiftData) + scripts 영속
- [x] T-007: Models 정의 (AppItem/HotKeyBinding/MenuItem/ActionType) + ScriptItem/PersistedScript
- [x] T-008: MainPanel + Sidebar + AppList UI → MainWindowView + Sidebar + AppsContent 리디자인
- [x] T-009: AppDetail + MenuCommandList UI → AppDetailView + **메뉴 명령 검색**
- [x] T-010: HotKeyRecorder UI → 제네릭 리팩터(앱메뉴/시스템/스크립트 공용)
- [x] T-011: SettingsView (로그인 시 시작 포함)
- [x] T-012: 아이콘 자산 + 한글/영문 현지화
- [x] T-013: 빌드 검증 + unit 테스트

## v0.2 — 백로그 (2026-09-01 완료분)

- [x] 시스템 액션 (잠금/음소거/다크모드) — SystemActionExecutor + 시스템 탭 UI
- [x] 스크립트 실행 탭 — ScriptsStationView (추가/목록/삭제/단축키 할당)
- [x] 로그인 시 시작 — SettingsView (SMAppService)
- [x] 메뉴 명령 검색 — AppDetailView 검색 필터

## v0.2.1 — 사용자 불만 수리 (2026-09-01)

- [x] T-014: Cmd+, 빈 설정 창 — `Settings { EmptyView() }` scene 제거(근본 원인), AppKit 메뉴(⌘,)가 처리
- [x] T-015: 우클릭 메뉴 위치 — 버튼 로컬 좌표 → 화면 좌표 변환 `popUp`
- [x] T-016: 패널 토글 핫키 미등록 — `panelToggleID` 등록 + `.togglePanel` 알림
- [x] T-017: 글로벌 단축키 설정 UI — AppDetailView '앱 실행/토글' 섹션 + 설정 창 패널 단축키 변경/복원
- [x] T-018: 메뉴 단축키 미획득 — NSNumber 캐스팅 + Carbon flags 일치 + title fallback 파싱
- [x] T-019: 디버그 패널 — Logger 링버퍼 + DebugLogView + 우클릭 '디버그 로그' 항목
- [x] T-020: 진입점 로그 대대적 추가 (핫키/패널/실행/열거/스위처/시스템/스크립트)
- [x] T-021: 빌드/테스트/재설치 + `docs/FUNCTIONAL_CHECKLIST.md` (PLAN 목표 11개 대조)

## v0.2.2 — 단축키 저장 검증 (2026-09-02)

- [x] T-022: HotKeyRecorderView 저장 플로 — 중복/사용불가 검사 + 적용 메시지(3초 후 자동 닫힘) + 테스트 버튼
- [x] T-023: HotKeyService — `isComboAvailable`(OS 임시 등록 probe) + `beginTest`/`endTest`(테스트 등록)

## v0.2.3 — "단축키가 안 먹는" 근본 원인 + 테스트 실동작 (2026-09-02)

- [x] T-024: SwiftData **전용 저장소 경로** — 기본 `~/Library/Application Support/default.store`가 다른 SwiftData 앱(채팅 앱)과 공유되어 컨테이너 생성 실패 → 단축키 저장·등록 자체가 안 됐던 근본 원인 수정 (`com.borasarang.ApexKey/default.store`) + 저장소 회귀 테스트 2건
- [x] T-025: 테스트 버튼 실제 액션 실행 — `onTest` 프리뷰로 키 감지 시 `ActionExecutor`/앱·시스템·스크립트 액션 실제 수행, 실패 시 안내 (호출부 5곳: 앱메뉴/실행·토글/시스템/스크립트/새액션/패널토글)
- [x] T-026: 메뉴 명령이 전면 여부와 무관하게 동작 — `onlyWhenAppActive=false` + 실행 전 대상 앱 활성화 + AX leaf(최하위 `AXMenuItemRole`) 우선 매칭 (상단 메뉴 이름 충돌 방지)
- [x] T-027: 실행/토글 단축키가 미실행 앱도 실행 — `AppSwitcher.activate`가 경로 없으면 `urlForApplication(withBundleIdentifier:)`로 LaunchServices에서 앱 URL 해석 (기존: 미실행 앱은 경로가 없어 실행 불가 → 테스트·단축키 모두 실패)
- [x] T-028: 메뉴 명령 실행 경로화 — 열지 않은 채 하위 항목을 직접 press하면 실패하는 문제 해결. 메뉴 경로(`menuPath`)를 저장·영속하고, 실행 시 최상위 메뉴를 `kAXShowMenuAction`으로 순차 펼친 뒤 최종 항목 `kAXPressAction`. 실행 결과를 `MenuActionResult` enum으로 분리해 실패 원인(앱 없음/권한/미발견/press 실패) 식별. (`MenuItem.menuPath`, `HotKeyBinding.menuPath`, `PersistedBinding.menuPathRaw` 스키마 추가 — 자동 마이그레이션)
- [x] T-029: 접근성 권한이 리빌드마다 초기화되던 문제 — ad-hoc 서명(`CODE_SIGN_IDENTITY=-`)이 리빌드마다 다른 코드 identity를 만들어 TCC 권한이 유지 안 됨. 무료 Apple 개발자 인증서의 `DEVELOPMENT_TEAM`(6GPJQ7BQC9) 고정 자동 서명으로 전환 → 리빌드 후에도 동일 CDHash 유지 → 접근성 권한 1회 허용 후 유지. (`project.yml` 앱+테스트 타깃, `build_and_run.sh` ad-hoc 제거)
- [x] T-031: 앱 상세 "메뉴 단축키" 목록을 전체 메뉴 트리(펼침/접기)로 표시 — 검색어 없으면 `MenuTreeView`가 최상위 메뉴바 그룹을 기본 펼침으로 계층 표시, 하위 서브메뉴는 개별 DisclosureGroup. 검색어 입력 시 단축키 항목 평면 검색 결과로 전환. (AppDetailView + 재귀 MenuTreeNode 뷰) — 수식: 그룹 label 전체를 Button으로 감싸 **이름이 있는 열(레이블) 클릭 시 토글**되도록 개선, 우측 펼침/접힘 화살표(chevron.up/down) 표시
- [x] T-030: "메뉴 단축키를 찾을 수 없습니다" — 메뉴 구조가 `MenuBarBarItem > AXMenu(제목없음) > 메뉴항목` 3단계인 앱(AIModelTalk, IINA 등)에서 `AXMenu` 컨테이너(title="")가 `makeMenuItem`에서 separator로 오인되어 **자식 전체(단축키 항목)가 유실**. separator 판정에 `children.isEmpty` 조건 추가 → 제목 없어도 자식 있는 요소는 submenu로 유지. AIModelTalk 30개/IINA 81개 단축키 항목 추출 검증 (임시 AX 재현 스크립트)
- [x] T-032: 메뉴 단축키 **테스트(및 실행)가 항상 실패** — `MenuEnumerator.performAction`이 `menuPath.filter { !$0.isEmpty }`로 **빈 문자열(AXMenu 컨테이너, title="") 단계를 제거**해 실제 AX 계층(메뉴바 > 파일 > AXMenu("") > 항목)과 경로 레벨이 어긋나 `.menuNotFound` 실패. 실제 menuPath는 `["파일", "", "새 대화"]`로 확인 — filter 제거로 빈 컨테이너 단계 보존 → 정상 탐색. (MenuEnumerator.swift)
- [x] T-033: **앱 간 빈 AXMenu 구조 차이로 인한 메뉴 실행 실패** — T-032의 "빈 단계 무조건 보존"이 빈 AXMenu 레벨이 **없는** 앱(MovistPro 등)에서는 경로의 `""` 단계를 못 찾아 실패 (`메뉴 실행 경로: 파일 >  > 파일 열기…` → `E-MAC-MENU-3002`). 수정: ① `makeMenuItem`이 빈 title 컨테이너를 menuPath에서 제거(자식 경로로 흡수)해 menuPath를 앱 무관하게 `["파일", "항목"]`로 정규화 ② `child(named:of:)`가 빈 title+submenu AXMenu를 재귀로 파고들어 찾도록 개선 → 빈 레벨 유/무 어느 구조에서도 동일 경로로 동작. 메모리 트리 시뮬레이션 검증 (MenuEnumerator.swift)
- [x] T-033-2: **IINA 등 메뉴 트리에 "(하위 메뉴)" 노드로 항목이 숨던 문제** — 열거 시 빈 title인 `AXMenu("")` 컨테이너가 MenuItem 노드로 만들어져 실질 항목들을 한 단계 더 감쌌다. `menuItems(from:parentPath:)` 리팩터로 빈 title 서브메뉴 컨테이너는 **노드 없이 자식만 상위로 평탄화(flatten)** → 각 최상위 메뉴에 실질 항목이 직접 표시. menuPath는 `["파일","열기…"]` 유지, 실행 `child(named:)` 우회와 호환. 라이브 IINA 확인(파일 14개 등) (MenuEnumerator.swift)

## v0.2.6 — 동작 메뉴 명령 단계 (2026-09-03)

> ⚠️ **2026-09-27 감사에서 [x] → [ ] 정정.** 아래 T-036은 **미구현**이다.
> 근거: `menuCommandPicker` 소스 0건 · `MenuChoiceNode`(`ShortcutStationView.swift:377`)는 자기 자신 재귀만 참조하는 dead code · `ShortcutEditorView.swift:357`은 여전히 `target: ""`로 생성 → `performAction(in: "")` 구조적 실패.
> 상세: `docs/plans/ACTION_AUDIT_v3_macos.md` §5 / 착수 계획: PLAN_v0.21 D-05

- [ ] T-036: **동작(단축어)의 메뉴 명령 단계 실행 불가 해결 + 앱/메뉴 선택 UI** — 기존 `buildStep`의 `.menuCommand`가 `target=""`·`menuPath=[]`로 만들어 실행(`performAction(in: "")`)이 구조적으로 실패. 단계 편집에서 메뉴 명령 선택 시 ① 앱 피커 → ② 선택 앱의 메뉴 트리에서 실행 항목 선택하도록 개선. `ShortcutStep.target=앱번들ID`, `menuPath=항목경로` 저장 → `execute`의 `.menuCommand`가 정상 호출. (`ShortcutStationView.swift` `menuCommandPicker`/`MenuChoiceNode` 재귀 선택 트리) — **[ ] 미구현](plans/PLAN_v0.21_audit-fix_macos.md) (2026-09-27 감사에서 [x]→[ ] 정정, 코드 부재 확인)**

## 다음 백로그


## v0.2.4 — 메뉴 실행 AppleScript 전환 (2026-09-03)

- [x] T-034: **IINA 등 메뉴 단축키 실행이 프로세스 내에서만 실패** — 독립 스크립트(메인/백그라운드 스레드, activation 포함)로 정확히 재현됐지만 앱 프로세스에서만 `경로 단계 미발견: URL 열기… (단계 2/2)` (E-MAC-MENU-3002). 앱 활성화 직후 닫힌 트리에서 AX `child(named:)` 쿼리가 일시적으로 nil 반환하는 transient 실패로 판정. 접근 로직·스레드·권한·샌드박스는 이상 없음. **해결: `performAction`의 AX 직접 press를 AppleScript(`System Events` 메뉴 클릭) 기반으로 교체** — AppleScript 계층(`menu item of menu 1 of menu bar item of menu bar 1 of process`)은 빈 AXMenu 레벨을 수동 우회할 필요 없어 구조 차이·transient nil이 구조적으로 소멸. 라이브 IINA에서 `exists menu item "URL 열기…"` true 검증. (MenuEnumerator.swift `performAction`)

## v0.2.5 — Menu HUD (전면 앱 단축키 표시) (2026-09-03)

- [x] T-035: **현재 전면 앱의 모든 메뉴 단축키를 플로팅 HUD로 표시** — KeyCue 스타일. 호출 `⌃⌥S`(Control+Option+S, 표준 비충돌) 글로벌 핫키. 전면 앱 감지(`NSWorkspace.frontmostApplication`) → `MenuEnumerator.enumerateMenuItems` → 메뉴별 그룹 배치. 닫힘: ESC/토글/외부 클릭. 설정에서 HUD 표시 방식(플로팅/전체 보기)+핫키 변경. (ConfigStore 예약ID, AppDelegate NSPanel, MenuCheatSheetView/MenuHUDOverlayView, SettingsView 섹션) — 후속: 4열 고정 그리드(`i % 4`) + 단축키 없는 메뉴 포함(`allItems` 잎 평탄화) + 모디파이어/제목 폴백 수정 + HUD 헤더 범례/토글 (아래 T-035-2/-3/-4 반영)

## v0.2.6 — 시트 상단 정렬 + 동작 메뉴 명령 단계 (2026-09-03)

- [x] 시트 내용 상단 정렬 — '새 동작' 이름 입력 시트와 단계 편집 시트가 수직 중앙 정렬 → `.frame`에 `alignment: .topLeading` 추가 (`ShortcutStationView.swift`)
- [x] T-036 (원본 기록, 2026-09-03): **동작(단축어) 메뉴 명령 단계 실행 불가 해결 + 앱/메뉴 선택 UI** — ~~기존 `buildStep`의 `.menuCommand`가 `target=""`로 만들어 실행이 구조적으로 실패. 단계 편집에서 앱 피커 → 메뉴 트리 선택~~ → **구현 안 됨. 위 v0.2.6의 [ ] 항목 참조 (2026-09-27 감사)**

## v0.3 — 동작을 iPhone 단축어(Shortcuts) 방식으로 전환 (2026-09-03, 8 Phase)

- [x] T-101: 도메인 모델 확장 — `ActionType` 12카테고리(앱/문서/웹/메시지/스크립트/파일/시스템/효율/개발/AI/흐름제어/기타) + `Variable`/`FlowControl`/`AutomationTrigger`/`ShortcutPermissions` + `ShortcutItem.combo/automations/variables` + `PersistedShortcut` JSON 데이터 컬럼(steps/triggers/variables/permissions)
- [x] T-102: 편집 UI — `ActionCatalogView`(액션 카탈로그)+`VariablePanelView`(변수 패널)+`StepRowView`/`BlockStepRow`/`StepListView`(계층 단계)+`ShortcutEditorView` 3열 편집기(카탈로그 | 단계 | 순서), `ShortcutStationView` 갱신
- [x] T-103: AI 통합 — `AIAvailabilityManager`(macOS 26 Gate)+`UseModelExecutor`/`WritingToolExecutor`/`ImagePlaygroundExecutor` (FoundationModels `#if canImport`+`#available` 폴백), 커스텀 Logger 전환, 배터리(IOKit)/Wi-Fi(CoreWLAN) 조회
- [x] T-104: 흐름 제어 엔진 — `ExecutionEngine` (If/Otherwise, Repeat/Repeat Each, Choose from Menu, Stop Shortcut, Set/Output Variable, Run Shortcut stub)
- [x] T-105: 자동화 트리거 — `AutomationManager` (시간/폴더(파일 변경 FSEvents+3s debounce)/배터리/충전기), 등록/해제/재등록, `runAutomation` 콜백
- [x] T-106: 변수 해석기 — `VariableResolver` (`{매직변수}`, `{특수변수:name}` 치환, 배터리/Wi-Fi, 변수 사전/단계 출력/마지막 출력 컨텍스트)
- [x] T-107: 단계/자동화/변수 설정 UI — `StepSettingsView`(유형별 설정 시트: If/Repeat/Choose/UseModel/WritingTool/ImagePlayground/SetVariable/Comment 등)+`AutomationSettingsView`(트리거 추가/삭제)+`createDefaultStep`/`saveAutomations`/`saveVariables` 연동
- [x] T-108: **Phase 8 실행/영속화 통합** — ① 단축키(combo)→단축어 실행 경로 확인(`handleHotKey`/`repeatLastBinding`) + 실행 통계(`lastRunAt`/`runCount`) 갱신 ② RunShortcut 완성(`ExecutionEngine.shortcutProvider` = ConfigStore에서 주입하여 실제 단축어 조회·실행) ③ `syncShortcut`이 automations/variables/permissions 등 전 필드 영속화 + 에디터 확장 메서드(`updateShortcutSteps/_Name/_Description/_Automations/_Variables`)가 `syncShortcut` 호출 ④ `executeSetVariable`에 VariableResolver 변수 치환 + 값 타입 추론(숫자/불리언)

- [x] 이번 v0.3 작업으로 'iPhone 단축어 방식 재검토' 백로그 항목 구현 완료(아래 백로그에서 제거)

## v0.3.1 — 흐름·자동화·AI 실행 심층 감사 버그 수정 (2026-09-03, P1)

- [x] T-110: B13 반복 인덱스/항목 특수변수 해석 — `ExecutionContext.repeatIndex/repeatItem` 추가 + `executeRepeatCountEach` 설정 + `makeResolveContext` 전달
- [x] T-111: B14 `notEquals` rightOperand 없을 때 항상 true 수정 + B15 If 조건 특수변수(`ResolveContext` 기반 평가 전환)
- [x] T-112: B8 whileLoop 0회 조용한 실패→1회 폴백 + E-MAC-FLOW-7008, B9 Choose from Menu `NSAlert` 메인 스레드 강제
- [x] T-113: B16 `runPauseUntilInput` no-op→실제 블로킹, B17 `runWait` 메인 스레드 블로킹→백그라운드 분기
- [x] T-114: B10 충전기 트리거 연결/해제 독립 평가, B11 폴더 이벤트 타입 FSEvent 플래그 파생+필터
- [x] T-115: B19 실행 통계 실패 시 미증가, B18 자동화 재등록 커버 확인
- [x] T-116: `VariableResolver.stringValue` 정수 포맷("2.0"→"2") + `build_and_run.sh test` 서브커맨드 추가
- [x] T-117: 단위 테스트 19건 추가(`ApexKeyFlowTests`) + 전체 통과 검증

## v0.3.2 — 빈 창 제거 + 패널 토글 + 전체화면 HUD 정렬 (2026-09-03)

- [x] T-118: A — SwiftUI `WindowGroup{EmptyView()}` 빈 창 근본 제거 — `ApexKeyApp.swift` 삭제 + `main.swift`(AppKit `@main`) 전환 + `applicationShouldHandleReopen` 재실행 시 빈 창 방지
- [x] T-119: B — `togglePanel` '뒤로 숨은 패널'을 앞으로 가져오기(`isKeyWindow` 기반 분기 + `orderFrontRegardless`)
- [x] T-120: C — 전체화면 HUD 단일 메뉴 그리드 좌측 정렬(4열 틀 유지, `.frame(maxWidth:.infinity, alignment:.leading)`)
- [x] T-121: D — 전체화면 HUD 단축키 없는 항목 keycap 자리 유지(`shortcutSlot` 빈 자리 추가)
- [x] T-122: 검증 — 빌드 SUCCEEDED + `open` 첫 실행/재실행 창 0 + `[PANEL] 열기/닫기` 분기 + 전체화면 HUD 표시/닫기 + unit 테스트 36/37(기존 1건 환경 의존 무관)
- [x] T-123: E — 전 앱에서 시스템 '서비스' 메뉴(Services/submenu, 제목 '서비스') 통째 제외 — 전 앱 일관 제거
- [x] T-124: F — HUD macOS 표준 레이아웃 '메뉴명 … 단축키(오른쪽)' 전환 + 서브메뉴 indent(부모 ▸ + 자식 depth 들여쓰기) — 전체화면+플로팅, `MenuItem.depth`+`flattenedWithDepth`
- [x] T-125: G — HUD 서브메뉴 부모 클릭 크래시(SIGTRAP, `path[1..<0]`) 수정 — 최상위 depth 0 노드 생략 + `path.count>1` 가드 + `!isSubmenu` 실행 차단
- [x] T-126: 검증 — 빌드 SUCCEEDED + HUD macOS 표준 배치·indent·서비스 제거 정상 + 크래시 없음 + unit 테스트 36/37(기존 1건 환경 의존 무관)

## v0.3.3 — 스크립트 동작 쉽게 만들기 (2026-09-16)

- [x] T-130: 셸 실행 강화 — `ActionExecutor.runShellScript`가 Homebrew/Android SDK PATH 자동 포함 + 출력/종료코드 로그 + 성공 여부 반환. `.runScriptInShell` 미구현(E-MAC-ACT-3005) 해소. `ExecutionEngine`에 `.script`/`.runScriptInShell` 명시 분기(변수 토큰 치환 후 실행)
- [x] T-131: 스크립트 전용 설정 UI — `ScriptSettingsView`(제목+여러 줄 명령+테스트 실행 버튼). `ShortcutEditorView.selectStep`이 스크립트 단계도 설정 창 열도록 연결 (기존엔 설정 창이 안 열려 target 비어있는 채로 방치됨)
- [~] T-132 **(무효화 — 2026-09-29 확인)**: `ADB Wi-Fi 연결` 샘플 동작 자동 제공 — ~~첫 실행이 아닌 기존 사용자도 이름 기준 1회 생성~~ → **실제 코드는 생성이 아니라 삭제** (`ConfigStore.swift:301-304` `ensureADBWifiSample()` → `removeLegacyAndroidShortcutsIfNeeded()`). v0.8 S-05가 무효화했으나 `[x]` 잔존 → **[~] 무효화](plans/ACTION_AUDIT_v3_macos.md)**. 2026-09-29에 코드 재확인: `ConfigStore.swift:384-385`에서 `ensureADBWifiSample()`가 `removeLegacyAndroidShortcutsIfNeeded()`만 부른다. Android 미러는 `SystemActionType.androidMirror`로 이관됐으므로 **샘플 동작을 만들지 않는 게 의도된 설계**다
- [x] T-133: 스크립트 테스트 결과 표시 — `runShellScriptResult`가 출력/종료코드 반환, `ScriptSettingsView`에 성공·실패 배지 + 결과 텍스트 표시. `ApexKeyScriptTests` 7건(ADB 실기 end-to-end 포함)
- [x] T-134: Cmd+C/V/X/A/Z 미동작 — 메인 메뉴에 앱 메뉴만 있고 편집 메뉴가 없어 first responder로 전달 불가. `AppDelegate.makeMainMenu`에 편집 메뉴(실행 취소/다시 실행/잘라내기/복사/붙여넣기/지우기/모두 선택, target nil=responder chain) 추가. `ApexKeyMenuTests` 회귀 테스트
- [~] T-135 **(무효화 — 2026-09-29 확인)**: 동작 고정 프리셋 — ~~시스템 탭(SystemActionType)과 동급 취급. `BuiltInShortcutPresets`(Android Untether/Mirror 2개…)에 코드 고정 + `ensureBuiltInShortcuts`가 이름 기준 자동 보충~~ → **실제 코드는 빈 배열 + 삭제** (`ConfigStore.swift:428-430` `BuiltInShortcutPresets.all = []` "호환용 스텁", `ensureBuiltInShortcuts()`는 `removeLegacyAndroidShortcutsIfNeeded()` 호출). v0.8 S-05가 무효화 → **[~] 무효화](plans/ACTION_AUDIT_v3_macos.md)**. 2026-09-29에 코드 재확인: `ConfigStore.swift:384-385`에서 `ensureADBWifiSample()`가 `removeLegacyAndroidShortcutsIfNeeded()`만 부른다. Android 미러는 `SystemActionType.androidMirror`로 이관됐으므로 **샘플 동작을 만들지 않는 게 의도된 설계**다. 미러 scrcpy 옵션(`--show-touches --stay-awake --legacy-paste --max-size=1024 --video-bit-rate=2M --max-fps=30`) 반영은 유효
- [x] T-136: 편집기 빨간 X 저장 유실 — 단계 설정 수정 후 윈도우 닫기(빨간 X)로 닫으면 저장 없이 유실 (헤더 X만 저장). `ShortcutEditorView`에 `.onDisappear` 저장(단계/이름/설명/자동화/변수) 추가. `build_and_run.sh debug`에 기존 앱 종료+재시작(5/5) 추가

## v0.4 — 깊은 리팩터 R1 (2026-09-16, PLAN_v0.4_refactor)

- [x] R-01: 엔진 default 실패 전파 + 변수 치환 (단계 실패가 전체 success에 반영되도록 루프에 ok 추적 추가)
- [x] R-02: wait 순서 버그 (호출 스레드 동기 sleep + 메인 경고 E-MAC-ACT-3006)
- [x] R-03: pauseUntilInput 메인 교착 가드 (메인 호출 시 백그라운드 전환)
- [x] R-04: MenuEnumerator 타입ID 비교 + unsafeDowncast (as! 제거, E-MAC-MENU-3004)
- [x] R-05: saveContext/fetchContext/StoreCoding 헬퍼 (try? 저장·조회·JSON 30여 곳 묵살 해소, E-MAC-STORE-5001/5002/5003/5004)
- [x] R-06: 죽은 코드 삭제 (runScript 래퍼, debugInfo, toModelContext, value(forName:)) — executeFollowUp는 Follow-Up 토글 UI용이라 유지
- [x] R-07: PATH 상수 단일화 (ShellEnvironment)
- [x] R-08: 카테고리 매핑 정합 (5종 .variables 귀속 + automationRun/trigger 목록 완성)
- [x] R-09: ActionType 메타데이터 테이블화 (ActionMetadata.swift 152항목) + 정합성 테스트
- [x] R-10: ConfigStore 영역별 분할 (동일 클래스 extension 9파일, API 동결, private→internal)
- [x] R-11: summary 반복 nil "0회"→"반복"

## v0.5 — 다국어 지원 (i18n, PLAN_v0.5_i18n)

- [x] T-140: Localizable.strings(ko/en) 생성 + LanguageManager 싱글턴 + ConfigStore appLanguage 저장
- [x] T-141: SettingsView 언어 선택 섹션(Picker: 시스템/한국어/영어) + 재시작 필요 안내 — **파이프 교착 제거 (4곳 → ProcessRunner, 동시 드레인 + 타임아웃) — 9건 테스트**
- [x] T-142: 전체 UI 문자열 키 추출·ko/en 번역 + Text(LocalizedStringKey) 치환 + ActionMetadata 연계 — **`String(Int(v))` 크래시 가드 (2^53 미만 + 유한) — 8건 테스트**

## v0.6 — 잔여 문자열 다국어화 (PLAN_v0.6_l10n)

- [x] L-01: 키 "variable.*" 추가 + VariableModels displayName 로컬라이즈
- [x] L-02: 키 "condition.op.*"·"flow.*" 추가 + FlowControlModels 로컬라이즈
- [x] L-03: 키 "category.app.*" 추가 + AppItem AppCategory 로컬라이즈
- [x] L-04: 키 "system.action.*"·"color.name.*" 추가 + SystemActionType/ShortcutColor 로컬라이즈
- [x] L-05: 키 "step.*" 추가 + Shortcut.summary/runCount/lastRun 로컬라이즈
- [x] L-06: 키 "error.user.*" 추가 + ExecutionEngine/ActionExecutor/AIAvailability 사용자 에러 로컬라이즈
- [x] L-07: ConfigStore(+Preferences/+Macro/+Bindings) + Views(ThemeSettings/SidebarNavigation/StepSettings/MenuHUD/HotKeyRecorder) + AppDelegate 창 타이틀 로컬라이즈
- [x] L-08: ApexKeyModelTests를 키 기반 비교로 재작성 (언어 무관)
- [~] L-09 **(기록 정정 — 결함 아님)**: 검증 — ~~strings 문법(plutil OK) + 코드 참조 키 526 전수 존재~~ + build_and_run test smoke 통과(compile) + 현지화 가드 0건 통과 → **"키 526 전수 존재"는 거짓 주장**이었다. `scripts/check-localizable.py`는 한글 리터럴 검사만 하고 **키 존재 검사 로직 0건** — 2026-09-29에 `missing|exists|not in` 검색으로 재확인했다. 누락 키는 게이트를 통과하고 **UI에 원문 키로 노출된다**. 키 수는 계속 늘어나므로 문서에 고정하지 않고 `docs/README.md`에 결함으로만 기록한다
- [x] L-10: 서비스 출력 로컬라이즈 — WritingToolExecutor(8) / ImagePlaygroundExecutor(2) / VariableResolver(3) / MenuEnumerator 상태(4)
- [x] L-11: LLM 프롬프트 로컬라이즈 — UseModelExecutor FollowUp 대화 헤더·역할 (3키)
- [x] L-12: 가드 스크립트 `scripts/check-localizable.py` 추가 + `build_and_run.sh` 게이트 연결

## v0.7 — 전체 리팩토링 + 버그·동작 연결 점검 (2026-09-21, PLAN_v0.7_refactor-bugfix)

- [x] G-01: `print` → Logger (ThemeConfigurationStore)
- [x] G-02: PATH 단일화 (`ShellEnvironment.extraPaths`)
- [x] G-03: LaunchConfig 코덱 실패 로그
- [x] B-01: AI 3종 Bool 반영
- [x] B-02: RunShortcut 실패 반환 + depth 10 가드
- [x] B-03: url/file 빈값 false + `toast.reason.file_missing`
- [x] B-04: If/Repeat/Choose 설정없음 실패 반환
- [x] B-05: `removeShortcut` 자동화 unregister
- [x] B-06: 편집기 복제 새 UUID
- [x] B-07: `executeBinding` 토스트 + lastID
- [x] B-08: 예약 핫키 영속화 + 중복 검사
- [x] B-09: 편집기 실행 변수/권한 포함
- [x] 테스트 8건 + 전체 139건 0실패 + 빌드 성공

## v0.8 — 시스템 탭 → 프리셋 통합 + 워크플로우/자동화 (2026-09-22, PLAN_v0.8_system-integration)

- [x] S-01: 명칭 변경 — "동작"→"워크플로우" (ko/en: ui.shortcut·station.empty·menu.edit_shortcut·sidebar.binding_counts·recorder.test_success·palette.*)
- [x] S-02: 시스템 탭 제거 — SidebarView 행 제거, MainWindowView `.tool(.system)` 제거, SystemActionsView.swift 삭제
- [x] S-03: 프리셋 추가 UX — ShortcutStationView "프리셋 추가" 버튼 + 체크박스 시트, `ConfigStore.addPresetShortcuts`(1단계 워크플로우 생성, 동명 중복 방지)
- [x] S-04: 시스템 스크립트 편집 이관 — `SystemScriptEditorView` 공개 분리 + StepSettingsView `.system` 케이스 임베드
- [x] S-05: seedSampleShortcuts 제거 — 설치 시 워크플로우 빈 상태
- [x] S-06: 기존 `.system` 바인딩 전부 해제(load 시 정리) + `systemBindings`/`setSystemBinding` 제거
- [x] S-07: 자동화 탭 신규 — `ToolSelection.automation`, SidebarView 행(트리거 수 배지), `AutomationBrowserView`(워크플로우 카드 + 트리거 목록 + 새 자동화 워크플로우 선택)
- [x] S-08: 검증 — 테스트 139건 0실패(2 skip) + 빌드 성공 + 현지화 가드 통과

## v0.9 — 업데이트 확인 (2026-09-22)

- [x] U-01: ReleaseChecker 신규 (조회+버전비교+404 구분)
- [x] U-02: ConfigStore+Update (상태·주기 weekly·확인시각 영속)
- [x] U-03: ReleaseNotesView + UpdateAvailableSheet (DMG 단일 안내)
- [x] U-04: 3 진입점 (설정·정보·메뉴바) + 수동 확인 자동 팝업
- [x] U-05: 현지화 update.* 19키 (ko/en 778→797)
- [x] U-06: release.yml (v*.*.*·버전검증·DMG 단일·release-notes)
- [x] U-07: ReleaseCheckerTests 12건 + 실기 재실행 검증

## v0.10 — P0 크리티컬 수정 (2026-09-22, PLAN_v0.10_p0-fixes)

- [x] F-01: AutomationManager NSLock 교착 (unregister 락 해제 후 rebuild)
- [x] F-02: 반복 count 0·음수 크래시 가드 (1...count 트랩 방지)
- [x] F-03: AppDetail URL Scheme 강제 언랩 2곳 제거
- [x] F-04: Localizable 중복키 `ui.app_detail.select_system` 제거 (ko/en)
- [x] F-05: 메뉴 실행 메인 블로킹 경고 로그 (performAction 메인 경고, 전체 비동기화는 후속 과제)

## v0.11 — P1 엔진·핫키 정합화 (2026-09-22, PLAN_v0.11_p1-engine-hotkey)

- [x] G-01: breakLoop 성공 둔갑 + Break 무시 (execute가 breakLoop를 삼켜 반복이 끝까지 실행되던 문제, ok 누적·상위 전파)
- [x] G-02: RunShortcut depth off-by-one (`> 10` → `>=`, 실제 11단계 허용)
- [x] G-03: 반복 인덱스 쓰레기 출력 (repeatIndexVariable nil이면 매번 랜덤 UUID 기록)
- [x] G-04: registerAllBindings 실패 묵살 (반환값 무시 → 실패 수 로그)

## v0.12 — UI 저장·실행통합 (2026-09-22, PLAN_v0.12_ui-save-exec)

- [x] U-01: 편집기 빨간X 이름·설명 유실 (onDisappear는 자동화만 저장)
- [x] U-02: SystemScriptEditor 미저장 침묵 유실 (isDirty인데 닫으면 소실)
- [x] U-03: execute(binding) 80줄 복제 (executeWithDetail와 전 분기 중복)

## v0.13 — 코덱·PATH 단일화 (2026-09-22, PLAN_v0.13_codec-path)

- [x] C-01: PATH 폴백 리터럴 2벌식 (ShellEnvironment 단일 출처 위반 잔재)
- [x] C-02: LaunchConfig 코덱 분산 (ActionExecutor·Shortcut·StepSettingsView 3처)

## v0.14 — 대형 파일 분할 1 (2026-09-22, PLAN_v0.14_split-stepsettings)

- [x] D-01: StepSettingsView 1150줄 → StepSettings/ 6파일 (이동만, sectionCard internal 전환)

## v0.15 — 대형 파일 분할 2 (2026-09-22, PLAN_v0.15_split-theme)

- [x] D-02: Theme.swift 888줄 → Theme/ 4파일 (이동만, public 유지)

## v0.16 — 저장소 P0 데이터 소실 방어 (2026-09-22, PLAN_v0.16_store-p0)

- [x] S-01: blob 쓰기 가드 — StoreCoding.encodeKeeping + undecodableBlobColumns + syncShortcut 손상 컬럼 원본 유지 (P0-3)
- [x] S-02: 레거시 저장소 1회 이관 — Application Support/default.store → com.borasarang.ApexKey/ (store+wal+shm) (P0-1)
- [x] S-03: 컨테이너 실패 격리 — .corrupt-{stamp} 이동 후 재시도 + storeRecoveryBackupPath 게시 (P0-2)

## v0.17 — 자동화·핫키 P0/P1 (2026-09-22, PLAN_v0.17_automation-p0)

- [x] A-01: activeTimers 날짜 키(yyyy-MM-dd-HH:mm) + unregister 정리 + .none UserDefaults 1회 영속 (P0-4)
- [x] A-02: ⌘⇧↩ 사이보그 교착 — resumePauseUntilInput Carbon 경로 + 대기 중 반복 실행 금지 (P0-5)
- [x] A-03: RepeatRule weekly/monthly/custom 실구현 + TimeOfDayTrigger 기준 필드 + 설정 UI
- [x] A-04: 미구현 트리거 8종·file — isWatcherSupported 가드 + E-MAC-AUTO-6001 + UI 비활성
- [x] A-05: ignorePatterns glob 적용
- [x] A-06: FSEvent 복합 flags 전 타입 산출·교집합 발동
- [x] A-07: 핫키 프로브 일회성 signature + beginTest 선행 endTest + 죽은 코드 제거

## v0.18 — UI/UX P1 수정 (2026-09-22, PLAN_v0.18_uiux-p1)

- [x] U-01: alwaysOnTop init 강제 리셋 → 저장값 복원 (E-MAC-UX-9001)
- [x] U-02: 한글·비ASCII 변수명 regex → `[^{}:]+` 3곳 (VariableResolver/UseModelExecutor/AIModels) (E-MAC-UX-9002)
- [x] U-03: StopShortcut actionParameters decode → outputVariable 반영 + 편집기 encode (E-MAC-UX-9003)
- [x] U-04: osascript stderr 분류 — -1743 권한/-600 앱미실행/메뉴없음 (E-MAC-UX-9004)
- [x] U-05: 하드코딩 Apple/서비스 → excludedMenuBarTitles 상수 (E-MAC-UX-9005)
- [x] U-06: 빈 메뉴바 조회 실패 warn 승격 (E-MAC-MENU-7006)
- [x] U-07: ReleaseChecker 403/429 rateLimited + isNewerStrict 프리릴리스 비교 (E-MAC-UX-9007)
- [x] U-08: AppleLanguages → LanguageManager.setLanguage 단일 출처 (E-MAC-UX-9008)
- [x] U-09: ThemeManager 하드코드 pref 키 → PrefKeys 상수 (E-MAC-UX-9009)

## v0.19 — UI 고정프레임·다중모니터·undo (2026-09-22, PLAN_v0.19_ui-screen-frame)

- [x] U-10: NSScreen.main 5곳 → screen(for:) 유틸 (창 소속→마우스→main→screens.first)
- [x] U-11: Toast 340 고정폭 → minWidth 340/maxWidth 440 + fixedSize
- [x] U-12: StepSettings 시트 480×680 → min+ideal 크기
- [x] U-13: HotKeyRecorder 300×80 → min+ideal 크기
- [x] U-14: HUD 4열 고정 → 화면 폭 기반 preferredColumnCount 동적
- [x] U-15: © 2026 하드코딩 → Calendar 연도 (AboutView)
- [x] U-16: `esc` 비로컬라이즈 → palette.esc_key 키 (ko/en)
- [x] U-17: Edit 메뉴 undo/redo → responder chain 위임. **정정**: `AppDelegate+Menus.swift:53-54`는 `Selector("undo:")` + responder chain으로 등록하고 `AppDelegate.undo/redo`(`:161-171`)는 `#selector` 연결 없이 **미사용 상태**. responder chain이 처리하므로 기능 자체는 동작하나, CHANGELOG의 "위임 연결" 기술은 과장. `E-MAC-UI-9108` 코드 부재

## v0.20 — 대형 파일 분할 + CI pipefail (2026-09-22, PLAN_v0.20_refactor-split-ci)

- [x] R-01: CI `run: |` 블록 `set -euo pipefail` (ci.yml 2 + release.yml 7) — E-MAC-CI-9201
- [x] R-02: CustomTheme.swift 1600줄 → Theme/ 8파일 분할 (Metadata/Colors/Background/Glass/StyleTokens/CustomTheme/Presets/Color+ThemeHex)
- [x] R-03: AppDelegate.swift 950줄 → 본체 + extension 6 + Windowing (cross-file `private` 제거)
- [x] R-04: androidMirrorScriptPath 하드코 절대경로 — **T-161 `1d82cb6`에서 이미 수정됨**(2026-09-29 확인). `SystemActionExecutor.ensurePortableMirrorScriptPath()`는 Application Support만 사용하고 번들/소스 리소스에서 시드한다. 소스의 `/Users/lee/`는 **과거를 설명하는 주석**뿐이고 코드는 아니다 — TODO가 낡아 있었다

## v0.21 — 감사 결함 수정 (2026-09-27, PLAN_v0.21)

> 근거: 5개 계층 정밀 감사(실행 엔진 / 저장소 / AX·액션 / 핫키·자동화 / 문서 정합) + 153종 카탈로그 현실 매핑.
> 기준선: 빌드 경고 0 · 테스트 171건 0실패 · i18n ko/en 801키 일치 · `as!`/`fatalError` 0건.
> 상세: `docs/plans/PLAN_v0.21_audit-fix_macos.md` · `docs/plans/ACTION_AUDIT_v3_macos.md`

### Phase A — P0

- [x] T-141: **파이프 교착 제거 (앱 영구 정지)** — `waitUntilExit()` 후 `readDataToEndOfFile()` 4곳을 동시 드레인으로. 64KiB 초과 출력 시 메인스레드 교착 → 핫키·패널·메뉴바 전체 정지 (강제종료 외 복구 불가)
- [x] T-142: **`String(Int(v))` 크래시 가드** — `inf`/`NaN` fatalError (`VariableResolver.swift:30`)
- [x] T-143: **AI 3종 스텁 거짓 성공 제거** — `UseModel`/`WritingTool`/`ImagePlayground`가 FoundationModels 미연동 상태에서 `return true`. 실패 반환 + 카탈로그/README/웹 문구 정정 — **AI 3종 스텁 → 실패 반환 + 가용성 판정 정직화 + README/웹 문구 정정 — 10건 테스트**
- [x] T-144: **`setLaunchBinding` 파괴-후-검증 제거** — 삭제 전 중복 사전 검증, `addBinding` → `Bool` 반환. 핫키 무음 소실 — **`setLaunchBinding` 파괴-후-검증 → 사전 검증 + `HotKeyApplyResult` 반환**
- [x] T-145: **셸 인젝션 방어** — `ShellEnvironment.quoted(_:)` 도입. AppleScript 경로만 이스케이프가 있는 비대칭 — **셸 인젝션 방어 — `ShellEnvironment.literal` + `resolveText(escaping:)` — 11건 테스트**
- [x] T-146: **Info.plist 버전 단일 출처화** — `project.yml` `MARKETING_VERSION`으로 이전. 현재 1.0 고정이라 `release.yml` 태그 대조에서 **다음 릴리스가 반드시 실패** — **Info.plist 버전 단일 출처화 — project.yml `MARKETING_VERSION` + `check-version.py` 게이트**
- [x] T-147: **테스트 격리** — 싱글론 오염 테스트(`HotKeyService.shared`에 ⌘H 실제 등록·미해제) 제거 — **테스트 격리 — ⌘H 싱글론 오염 제거 + 핫키 상태 전이 테스트**

### Phase B — P1

- [x] T-148: **반복 내부 실패 전파** — `executeRepeatCount`/`Each`가 내부 `success:false`를 버리고 성공 반환 — **반복 내부 실패 전파 (`executeRepeatCount`/`Each`) — 10건 테스트**
- [x] T-149: **에러 메시지 보존** — `execute(steps:)`가 `error` 문자열을 버림 → 토스트에 실제 원인 미노출 — **에러 메시지 보존 — 최초 실패 사유를 Result로 전파**
- [x] T-150: **스크립트 출력이 소스코드로 기록** — `runShellScript`가 stdout을 버림 — **셸 단계 출력이 소스코드가 아닌 실제 stdout**
- [x] T-151: **일반 액션 `setOutput` 누락** — `default:` 분기가 출력을 남기지 않아 `{lastResult}`가 과거 잔여값 — **일반 액션 `default:` 분기의 `setOutput` 누락**
- [x] T-152: **핫키 저장 실패 전달** — `onRecord` → `Bool` 반환. 현재 "적용되었습니다"가 거짓말 — **핫키 저장 실패 전달 — `onRecord` → `String?` 반환**
- [x] T-153: **`removeApp` 연관 바인딩 정리** — `pruneRemovedApps()`가 매 실행 호출 → **외장드라이브 뽑으면 고아 핫키가 매번 재등록** — **`removeApp` 연관 바인딩 + Carbon 핫키 정리 (E-MAC-STORE-5007)**
- [x] T-154: **`showHiddenApps` 영속화** — 설정 토글이 매 실행 리셋 — **`showHiddenApps` 영속화 (E-MAC-STORE-5008)**
- [x] T-155: **테마 활성 ID 키 이중 정의 해소** — `ApexKeyActiveThemeId` vs `activeThemeId` 연결 코드 0건 — **테마 활성 ID 키 단일 출처화 (E-MAC-UX-9011) — 6건 테스트**
- [x] T-156: **FSEventStream 해제 전 콜백 큐 동기화** — use-after-free 창 — **FSEventStream 해제 전 콜백 큐 barrier 동기화 (E-MAC-AUTO-8002)**
- [x] T-157: **osascript 오류 분류 정정** — 미실행 앱·없는 메뉴가 전부 `-1728`. `-1743`은 Automation TCC (현재 "손쉬운 사용 권한"으로 오표기) — **osascript 오류 분류 정정 — `-600` 제거, `-1728` 경로 오류, `-1743` Automation (E-MAC-MENU-7007)**
- [x] T-158: **`menuPath` 단일 세그먼트 처리** — `count==1`이면 구조적으로 100% 실패. `ApexKeyStoreTests:99-103`이 이를 green 고정 중 → 테스트 갱신 필요 — **`menuPath` 단일 세그먼트 처리 — 최상위 메뉴 클릭으로 분기 (E-MAC-MENU-7008) — 12건 테스트**

### Phase C — 카탈로그 정합

- [x] T-159: **미구현 125종 카탈로그 정리 + 컴파일 타임 정합성 검사** — `ActionType` ↔ 핸들러 — **미구현 125종 카탈로그 정합 + **컴파일 타임 전수 검사** — 10건 테스트**
- [x] T-160: **자동화 트리거 8종 숨김 + 배지 정합** — `automationTriggerCount`가 실제 등록 수가 아님. README 광고 4종(display·wifi·bluetooth·app) 비작동 — **자동화 트리거 배지 정합 + README 정정 (E-MAC-AUTO-8003)**
- [x] T-161: **하드코 절대경로 제거** — `SystemActionExecutor.swift:70-71` — **하드코 절대경로 제거 (E-MAC-SYS-8006)**
- [x] T-162: **죽은 코드 정리** — `resolveToken`/`ControlFlow.breakLoop`·`continueLoop`/`RunShortcutAction`/`Variable.tokenString`/`runsInBackground`/`isUsableKeyCode`/`moveBinding` — **죽은 코드 정리 — isUsableKeyCode/moveBinding/moveStep·MoveDirection/stopAll/Result.stopped**
- [x] T-163: **죽은 자산 정리** — 미사용 스크립트 6개, 죽은 i18n 키 23개 — **죽은 자산 정리 — 미사용 스크립트 6개, ui.system.* 키 9건**
- [x] T-164: **`build_and_run.sh test` smoke/unit/full 실제 분리** — 현재 3분기 완전 동일 — **`build_and_run.sh test` smoke/unit/full 실제 분리 + **실패 exit code 전파****
- [x] T-165: **`release.yml`에 현지화 가드 추가** — `check-localizable.py`가 ci·build에만 존재 — **`release.yml`에 현지화 가드 + 버전 가드 스텝 추가**

## v0.26 — 저장 계층 복구·debounce + 키 입력·HTML 3종 + Run Shortcut UI (2026-09-29)

> "바로 착수 가능 6건"을 전부 처리. 테스트 381 → **451건 0실패**(2 skip),
> 액션 구현 55 → 59종, i18n 891키. 상세는
> [`plans/PLAN_v0.26_store-and-input_macos.md`](plans/PLAN_v0.26_store-and-input_macos.md)

- [x] T-175: **blob 손상 컬럼 영구 쓰기 잠금에 복구 경로** (E-MAC-STORE-5010).
  `tryRecoverBlob`이 "손상 시점 fallback과 달라졌을 때만" 해제한다.
  **왕복 검증만으로는 fallback(`[]`)과 정상값을 구별할 수 없다** — fallback도 왕복에
  성공하므로 원본 보호 가드가 자기 목적을 무력화한다. 값의 **출처**를 추적해야 한다.
  컬럼은 독립적 — 안 건드린 컬럼의 잠금은 유지된다. 테스트 9건
- [x] T-177: **`JSONEncoder` 키 순서 결정성** (E-MAC-STORE-5012). ★ 가장 중요한 발견.
  기본 `outputFormatting`은 **프로세스마다 키 순서가 달라진다** (Swift `Hasher` 시드가
  무작위). 실측: 같은 `ShortcutPermissions`를 두 번 인코딩해 165바이트로 길이는 같은데
  내용이 달랐다. `StoreCoding`을 `.sortedKeys`로 고정 — 안 고쳐졌으면 T-175의 가드가
  **간헐적으로 열려 사용자 원본을 덮어썼을 것.** 5회 연속 전체 스위트로 확인
- [x] T-176: **저장 debounce** (E-MAC-STORE-5011). `updateShortcutSteps`만 합치고
  명시적 뮤테이션은 합치지 않는다("추제한 게 안 보인다"는 불안 방지). 종료 시
  `flushPendingSaves()`. `queue.sync` 데드락 회피. 테스트 12건(배선 포함)
- [x] T-179: **`typeText`·`typeNumber`·`htmlToMarkdown`** (E-MAC-TEXT-6003).
  게시와 계획을 분리해 권한 없이 테스트. 한글을 Character 경계에서만 잘라 결합음자
  보호. HTML은 자체 파서 — **태그가 없으면 원문을 돌려주지 않고 실패**시킨다.
  테스트가 실제 버그 3건 잡음(엔티티 `;` 잔존 · `Optional()` 보간 · 닫는 태그 오판)
- [x] T-181: **Run Shortcut 전용 설정 UI** (E-MAC-FLOW-7011). 엔진은 정상이고 UI가
  없었다. `ThemedRoot`가 store를 주입하지 않아 `@EnvironmentObject` 크래시가 날
  뻔한 것을 함께 막았다. 테스트 5건
- [x] T-182: **T-132/T-135/L-09 무효화 정리 + 문서 정합**. `[~]` 표기 도입.
  세 항목의 코드 주장을 2026-09-29에 재검증. 문서 수치 전부 재계산
- [ ] **클린 빌드 경고 7종 정리** — 이번에 발견. `onChange(of:perform:)`·
  `activateIgnoringOtherApps` deprecation, `hideToast()` actor 격리 위반,
  미사용 `hotKeyID`, `weak` 캡처 불일치, AppIcon unassigned child.
  이번 변경분이 아니라 기존 결함이지만 **"경고 0" 기록이 계속 거짓말**이므로 착수 가능
- [ ] **`StoreBlobRecoveryTests` 격리 기전 특정** — 픽스처 격리로 해결했지만
  저장소 공유 시에만 깨지는 **정확한 원인은 특정하지 못했다.** 남겨 둔다

## v0.25 — 수치·날짜·목록 액션 12종 + 문서 구조 정비 + 미완료 장부 (2026-09-29)

- [x] T-172: **수치·날짜·목록 액션 12종 구현** — `changeCase`·`sort`·`surroundText`·
  `wordCount`·`calculate`·`math`·`number`·`outputDifference`·`base64Encode`·`hash`·
  `uuid`·`dateFormatter`. `DataActions`(순수 함수) + `ExecutionEngine.executeDataAction` +
  기존 `TextActionSettingsView` 확장. 테스트 46건 + 엔진 배선 테스트.
  - **계산기는 `eval`을 쓰지 않는다.** 재귀 하강 파서를 직접 구현했다.
    우선순위·오른쪽 결합 거듭제곱·괄호·단항 마이너스 지원, 재귀 깊이 64 제한
  - **0으로 나누기는 명시적 실패.** IEEE 754의 `inf`는 오류가 아니라 조용히 이상한 값이다
  - **정렬에서 숫자가 아닌 항목은 뒤로 보낸다.** 0으로 취급하면 순서가 거짓말이 된다
  - **MD5를 넣지 않았다.** 충돌이 실제로 만들어지는 해시를 제공하지 않는다
  - **테스트가 실제 버그 2건을 잡았다** — ① 괄호 중첩 깊이 제한이 `parsePrimary`에서
    `parse()`를 depth 0으로 호출해 리셋됐다(`((((...))))` 500중첩이 통과) ② 제 테스트의
    기대값 오류
- [x] T-173: **문서 구조 정비** — `docs/README.md`(색인)와 `docs/STATUS.md`(현황 단일 출처)
  신규. `TODO.md` 최상단에 미해결 요약 인덱스 추가 (수는 고정하지 않음). `FUNCTIONAL_CHECKLIST.md` §6에
  "감사 스냅샷이라 낡아진다 — 착수 전 코드와 대조할 것" 경고 추가.
  §8-8 신설(텍스트/데이터 액션 23종 UI 확인 14항목)
- [x] T-174: **미완료 항목 장부 분리** — "안 한 것"이 `STATUS.md`·`FUNCTIONAL_CHECKLIST.md`·
  `TODO.md`에 흩어져 있어 나중에 확인하려면 어디를 봐야 하는지 알 수 없었다.
  `docs/OPEN_ITEMS.md` 신규 — 6개 항목이 **완료 기준과 함께** 체크박스로 남는다.
  세부는 옮기지 않고 링크만 걸었다(체크박스를 두 곳에 만들면 어느 쪽이 밀린
  항목이 되는지 알 수 없다 — `FUNCTIONAL_CHECKLIST.md` §6이 낡아진 것과 같은 종류의 문제).
  **집계 정정**: 이전 보고에서 실동작을 "8건 + 23종 UI"로 적었으나 실제로는
  **§8 전체 52건**이었다(새로 추가한 것만 세고 있었음)

## v0.24 — 텍스트 액션 11종 구현 (2026-09-29)

- [x] T-171: **P1 순수 로직 11종 구현** — `text`·`combineText`·`splitText`·
  `trimWhitespace`·`replaceText`·`regex`·`matchText`·`count`·`formatNumber`·
  `getClipboard`·`setClipboard`. 전부 `ActionType`에는 있었으나 구현 0이었다.
  카탈로그에는 노출되고 실행하면 "미구현" 토스트가 떴다 — T-159가 고친 상태가
  백로그에 남아 있었다.
  - `TextActions`(순수 함수) + `TextActionConfig`(`actionParameters` JSON) +
    `TextActionSettingsView`(전용 UI). **실패를 빈 문자열로 뭉개지 않는다** —
    패턴 오류·빈 입력·비숫자 입력을 구분해 돌려준다
  - **전용 설정 UI가 필수였다.** `implemented`인 액션은 카탈로그에서 선택되는데
    `DefaultSettingsView`로 두면 "정규식"을 골라도 패턴을 입력할 곳이 없다
  - `TextActionsTests` 38건(순수 로직) + 엔진 경유 배선 테스트 2건.
    변환 테스트로 `executeStep`의 case를 지우면 배선 테스트가 실패함을 실측
  - i18n 31키 추가 (ko/en 833키 일치). `check-localizable.py`는 **키 존재를
    검사하지 않는다** — 없는 키는 게이트를 통과하고 UI에 원문으로 노출된다
  - 카탈로그 가드가 정확히 작동: `testKnownUnimplementedRemainPlanned`가
    11종 때문에 실패했다. 목록에서 빼고 역방향 가드를 추가했다
  - 부수: `executeStopShortcut`의 죽은 `?? .null` 제거, `runAutomation`의
    `@Sendable` 클로저 `var` 캡처 제거(Swift 6 오류)

## v0.23 — 저장 계층 안전 + 실행 엔진 백그라운드화 (2026-09-29)

> 인계 문서 `SESSION_2026-09-27_handoff.md` §3의 2·3·4순위를 한 번에 착수.
> 테스트 247 → **294건 0실패** (2 skip). 새 테스트 38건.

- [x] T-167: **스키마 버전 관리 도입** — `ConfigSchemaV1`(`VersionedSchema`) +
  `ConfigMigrationPlan`(`SchemaMigrationPlan`) 추가, `ConfigStore`가 `currentSchema` 사용.
  마이그레이션 stage는 비어 있다 — 무버전 → v1 경량 이관만 수행한다는 뜻이지 이관이
  불필요하다는 뜻이 아니다. `ConfigSchemaMigrationTests` 8건.
  **위험 제거가 목표였다**: 무버전 store를 새 계획으로 못 열면 `quarantineStore`가 발동해
  전 사용자 설정이 격리된다. 그 경로를 테스트로 고정했다.
  함정: `Schema(ConfigMigrationPlan.schemas)`는 컴파일되지 않고(`Schema.init`은
  `[any PersistentModel.Type]`을 받음), `Schema(models)`만 쓰면 `version`이 기본값
  `1.0.0`으로 들어가 버전을 명시하지 않은 새 스키마가 과거와 구분되지 않는다 →
  둘을 `currentSchema`에 묶었다
- [x] T-168: **저장 blob의 키 누락 내성** — T-167만으로는 실제 데이터 소실 경로가
  안 막힌다. blob은 불투명한 `Data`라 SwiftData 마이그레이션이 건드리지 않고, Swift의
  합성 `Decodable`은 **프로퍼티 기본값을 무시한다**(`= false`여도 키가 없으면
  `keyNotFound`). 인계 문서가 지목한 "필드 추가 = 데이터 소실"의 실체가 이것.
  `ShortcutStep`·`ShortcutPermissions`·`Variable`에 관대 `init(from:)` 적용
  (전 필드 `decodeIfPresent ?? 기본값`, 새 필드 추가는 컴파일 에러로 감지).
  `StoreBlobToleranceTests` 9건 — "키 하나씩 제거 → 여전히 디코딩" 스윕이 필드가
  늘어날 때마다 같이 늘어 회귀를 자동 잡는다
- [x] T-169: **`ConfigStore()` 인스턴스 테스트 0건 보강** — `init()`이 `storeURL`을
  하드코딩해서 인스턴스화가 불가능했고, 그 결과 바인딩·앱·동작·스크립트의 모든
  뮤테이션 경로가 검증되지 않았다. `init`를 주입 가능하게 변경
  (storeDirectory·defaults·seedInstalledApps·registerSystemIntegrations, 기본값은 기존 동작).
  `UserDefaults.standard` 하드코딩 17곳을 주입된 `defaults`로 교체.
  `ConfigStoreMutationTests` 23건
- [x] T-170: **실행 엔진 백그라운드화** — 핫키 콜백이 메인 스레드에서 동기 실행해
  `wait 60초` 단계면 UI가 60초 정지. `ExecutionEngine.executionQueue`(직렬) +
  `ConfigStore.runOffMainThread`로 실행만 백그라운드, MainActor 상태 접근은 메인 유지.
  `ExecutionBackgroundTests` 7건 — 동기 실행으로 되돌리면 3건이 실패함을 실측 확인

### 이번 세션에서 배운 함정 (반복하지 말 것)

- **회귀 테스트는 "무엇을 측정하는지"뿐 아니라 "언제 측정하는지"를 검증해야 한다.**
  백그라운드화 테스트의 첫 판은 실행이 **끝난 뒤**에 하트비트를 셌다. 실행이 끝나면
  메인은 다시 자유로워서 동기/비동기 어느 쪽이든 통과했다. 실행 구간 *안*을 봐야 한다
- **호출부 실행 시간 임계값 테스트는 신뢰도가 높다.** 1.5초 단계를 던지고 0.4초 안에
  반환되는지 보는 게 가장 단순하고 확실히 잡는다 (실측 1.505초 vs 임계 0.4)
- **`RunLoop.main.run` 수동 펌프는 XCTest에서 위험하다.** 단독 실행에서는 됐지만 전체
  스위트에서 테스트 루프와 충돌해 불안정했다. 메인 응답성은 `await MainActor.run` 왕복
  지연으로 재는 편이 낫다 (XCTest 루프에 개입하지 않음)
- **단일 경로를 가리키는 테스트는 통과해도 무의미할 수 있다.** `setLaunchBinding`
  회귀 테스트를 "다른 앱과 겹치는 조합 추가"로 썼더니 구버그 구현에서 통과했다.
  실제 버그 조건은 "자기 바인딩을 겹치는 조합으로 교체"였다
- **테스트 픽스처가 호스트 환경에 의존하지 말 것.** `/Applications/Notes.app`을 경로로
  썼다가 이 기기에 없어 두 앱이 모두 prune되어 실패했다. `pruneRemovedApps()`는
  `fileExists`만 보므로 임시 파일이면 충분하다
- **`VersionedSchema`는 컬럼만 보호한다.** blob 스키마 변경은 손대지 못한다 →
  T-168이 별개로 필요하다

## v0.22 — 무서명 릴리스 고지 정직화 (2026-09-29)

> 인계 문서 `SESSION_2026-09-27_handoff.md` §3의 1순위. 2026-09-29 사용자 결정 **(b) 문구 정직화** —
> Developer ID 서명·공증(a)은 Apple Developer Program 가입이 선행이라 **보류**, 남는 것은
> "무서명이라는 사실을 사용자에게 정직하게 알린다"였다.

- [x] T-166: **무서명 릴리스 사실 고지** — 릴리스 노트 템플릿에 Gatekeeper 안내만 있고
  **"업데이트마다 접근성 권한 재승인"이 빠져 있었다.** 사용자가 버전업 후 메뉴가 동작하지 않는
  원인을 알 수 없는 상태였다. README(ko/en)·릴리스 노트 템플릿·랜딩(ko/en) 4곳에
  증상·대응·기술적 원인(CDHash)을 명시.
  — `README.md` / `README.ko.md` 설치 절 · `release-notes/_template.md` "알려진 제약" 신규 절
  (릴리스마다 복사하도록 명시) · `website/index.html`·`website/ko/index.html` 다운로드 절
- [ ] **T-166 후속 — Developer ID 서명 + notarization** — (b) 결정으로 **보류**.
  Apple Developer Program(연 $99) 가입이 선행 조건. T-029의 "고정 TeamID → CDHash 유지 →
  접근성 권한 유지" 수정이 **배포본에서 무효인 이유가 이것**이므로, 가입 시 착수하면
  `release.yml`의 `CODE_SIGNING_ALLOWED=NO` 해제 → `CODE_SIGN_IDENTITY=Developer ID Application` +
  `notarytool` + T-166의 고지 4곳 정리. `FUNCTIONAL_CHECKLIST.md` §6 "CI 서명 경로"도 함께 해결.

## 다음 백로그

- [x] 대형 파일 분할 (CustomTheme 1600줄·AppDelegate 950줄) — v0.20
- [x] blob 손상 덮어씀 가드 (P0-8) — **v0.16 S-01 `encodeKeeping`으로 이미 구현됨**. 잔류 백로그가 아님 (2026-09-27 감사 확인)
- [~] ~~`menuPath` 편집 UI + `system` 선택 UI (P1-5 잔류)~~ — T-036으로 이관됨. 별개 작업이 아니다.
  **`runShortcut` 선택 UI는 T-181로 완료** (2026-09-29) — 전용 동작 피커 추가
- [x] **blob 손상 컬럼 영구 쓰기 잠금 해제 경로** — **T-175로 완료**(2026-09-29).
  `tryRecoverBlob`이 "손상 시점 fallback과 달라졌을 때만" 해제한다. 왕복 검증만으로는
  fallback(`[]`)과 정상값을 구별할 수 없다는 걸 테스트가 잡아내 출처 추적을 추가했다.
  같은 조사에서 `JSONEncoder` 키 순서의 **비결정성**을 발견해 `.sortedKeys`로 고정 (E-MAC-STORE-5012)
- [ ] **`saveContext` → `Bool` 반환** — 23개 호출부. 컴파일 오류로 누락 호출부 자동 발견.
  **검증 수단 없음** — chmod는 소유자에게 통하지 않고 SQLite 배타 락은 무한 대기를 유발
- [x] **저장 debounce** — **T-176으로 완료**(2026-09-29). `CoalescingScheduler`가
  `updateShortcutSteps`만 합친다. 명시적 뮤테이션(추가·삭제·이름)은 합치지 않는다 —
  합치면 "추제한 게 안 보인다"는 불안이 생긴다. 종료 시 `flushPendingSaves()`로 유실 방지
- [x] **`ConfigStore()` 인스턴스 테스트 0건 보강** — **T-169로 완료**(2026-09-29).
  `init`에 storeDirectory·defaults 주입 + 테스트 23건
- [ ] **단축키 프로필/빠른 전환**
- [x] Run Shortcut 호출 시 … 조회 단계 연결 — **T-181로 완료**(2026-09-29).
  조사 결과 엔진은 정상이었고 **설정 UI가 없었다**(`DefaultSettingsView`로 떨어짐) —
  사용자가 UUID를 직접 입력해야 했다. 전용 피커를 추가했다. `ThemedRoot`가
  `store`를 주입하지 않아 `@EnvironmentObject` 크래시가 날 뻔한 건을 함께 막았다
- [ ] Choose from Menu/Use Model 등 단계 저장값(actionParameters) UI 연동 세부 다듬기
- [ ] **AI 3종 실제 FoundationModels 연동** — A-03은 "정직한 실패"로 전환하는 것. 실제 구현은 별도 과제(리서치 필요)
- [x] **P1 순수 로직 11종** — **T-171로 완료**(2026-09-29). `text`·`combineText`·`splitText`·`trimWhitespace`·`replaceText`·`regex`·`matchText`·`count`·`formatNumber`·`getClipboard`·`setClipboard` 11종 구현 + 전용 설정 UI + 테스트 40건
- [~] 오프라인/큐 — **비해당.** 로컬 앱이다
- [ ] macOS 14 런타임 실기 검증 (v0.3.2로 SwiftUI 빈 윈도우 근본 제거, macOS 26에서 검증 완료) — 배포 타깃 14 컴파일만 보장
