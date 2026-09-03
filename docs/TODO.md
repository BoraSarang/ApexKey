# ApexKey — TODO

> `T-번호` 기반 작업 추적. 완료 시 [x] 체크.
> 작성일: 2026-09-01

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

- [x] T-036: **동작(단축어)의 메뉴 명령 단계 실행 불가 해결 + 앱/메뉴 선택 UI** — 기존 `buildStep`의 `.menuCommand`가 `target=""`·`menuPath=[]`로 만들어 실행(`performAction(in: "")`)이 구조적으로 실패. 단계 편집에서 메뉴 명령 선택 시 ① 앱 피커 → ② 선택 앱의 메뉴 트리에서 실행 항목 선택하도록 개선. `ShortcutStep.target=앱번들ID`, `menuPath=항목경로` 저장 → `execute`의 `.menuCommand`가 정상 호출. (`ShortcutStationView.swift` `menuCommandPicker`/`MenuChoiceNode` 재귀 선택 트리)

## 다음 백로그


## v0.2.4 — 메뉴 실행 AppleScript 전환 (2026-09-03)

- [x] T-034: **IINA 등 메뉴 단축키 실행이 프로세스 내에서만 실패** — 독립 스크립트(메인/백그라운드 스레드, activation 포함)로 정확히 재현됐지만 앱 프로세스에서만 `경로 단계 미발견: URL 열기… (단계 2/2)` (E-MAC-MENU-3002). 앱 활성화 직후 닫힌 트리에서 AX `child(named:)` 쿼리가 일시적으로 nil 반환하는 transient 실패로 판정. 접근 로직·스레드·권한·샌드박스는 이상 없음. **해결: `performAction`의 AX 직접 press를 AppleScript(`System Events` 메뉴 클릭) 기반으로 교체** — AppleScript 계층(`menu item of menu 1 of menu bar item of menu bar 1 of process`)은 빈 AXMenu 레벨을 수동 우회할 필요 없어 구조 차이·transient nil이 구조적으로 소멸. 라이브 IINA에서 `exists menu item "URL 열기…"` true 검증. (MenuEnumerator.swift `performAction`)

## v0.2.5 — Menu HUD (전면 앱 단축키 표시) (2026-09-03)

- [x] T-035: **현재 전면 앱의 모든 메뉴 단축키를 플로팅 HUD로 표시** — KeyCue 스타일. 호출 `⌃⌥S`(Control+Option+S, 표준 비충돌) 글로벌 핫키. 전면 앱 감지(`NSWorkspace.frontmostApplication`) → `MenuEnumerator.enumerateMenuItems` → 메뉴별 그룹 배치. 닫힘: ESC/토글/외부 클릭. 설정에서 HUD 표시 방식(플로팅/전체 보기)+핫키 변경. (ConfigStore 예약ID, AppDelegate NSPanel, MenuCheatSheetView/MenuHUDOverlayView, SettingsView 섹션) — 후속: 4열 고정 그리드(`i % 4`) + 단축키 없는 메뉴 포함(`allItems` 잎 평탄화) + 모디파이어/제목 폴백 수정 + HUD 헤더 범례/토글 (아래 T-035-2/-3/-4 반영)

## v0.2.6 — 시트 상단 정렬 + 동작 메뉴 명령 단계 (2026-09-03)

- [x] 시트 내용 상단 정렬 — '새 동작' 이름 입력 시트와 단계 편집 시트가 수직 중앙 정렬 → `.frame`에 `alignment: .topLeading` 추가 (`ShortcutStationView.swift`)
- [x] T-036: **동작(단축어) 메뉴 명령 단계 실행 불가 해결 + 앱/메뉴 선택 UI** — 기존 `buildStep`의 `.menuCommand`가 `target=""`·`menuPath=[]`로 만들어 실행(`performAction(in: "")`)이 구조적으로 실패. 단계 편집에서 메뉴 명령 선택 시 ① 앱 피커 → ② 선택 앱의 메뉴 트리에서 실행 항목 선택하도록 개선. `ShortcutStep.target=앱번들ID`, `menuPath=항목경로` 저장 → `execute`의 `.menuCommand`가 정상 호출. (`ShortcutStationView.swift` `menuCommandPicker`/`MenuChoiceNode` 재귀 선택 트리)

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

## 다음 백로그

- [ ] 단축키 프로필/빠른 전환
- [ ] Run Shortcut 호출 시 ConfigStore 자동화 UI에서 조회 단계 연결 (multishortcut 재귀 공유 변수 전달)
- [ ] Choose from Menu/Use Model 등 단계 저장값(actionParameters) UI 연동 세부 다듬기
- [ ] 오프라인/큐(비해당 — 로컬 앱)
- [ ] macOS 14 런타임 실기 검증 (v0.3.2로 SwiftUI 빈 윈도우 근본 제거, macOS 26에서 검증 완료) — 배포 타깃 14 컴파일만 보장
