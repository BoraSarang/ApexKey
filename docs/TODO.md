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

## v0.3.3 — 스크립트 동작 쉽게 만들기 (2026-09-16)

- [x] T-130: 셸 실행 강화 — `ActionExecutor.runShellScript`가 Homebrew/Android SDK PATH 자동 포함 + 출력/종료코드 로그 + 성공 여부 반환. `.runScriptInShell` 미구현(E-MAC-ACT-3005) 해소. `ExecutionEngine`에 `.script`/`.runScriptInShell` 명시 분기(변수 토큰 치환 후 실행)
- [x] T-131: 스크립트 전용 설정 UI — `ScriptSettingsView`(제목+여러 줄 명령+테스트 실행 버튼). `ShortcutEditorView.selectStep`이 스크립트 단계도 설정 창 열도록 연결 (기존엔 설정 창이 안 열려 target 비어있는 채로 방치됨)
- [x] T-132: `ADB Wi-Fi 연결` 샘플 동작 자동 제공 — 첫 실행이 아닌 기존 사용자도 이름 기준 1회 생성 (`ConfigStore.ensureADBWifiSample`)
- [x] T-133: 스크립트 테스트 결과 표시 — `runShellScriptResult`가 출력/종료코드 반환, `ScriptSettingsView`에 성공·실패 배지 + 결과 텍스트 표시. `ApexKeyScriptTests` 7건(ADB 실기 end-to-end 포함)
- [x] T-134: Cmd+C/V/X/A/Z 미동작 — 메인 메뉴에 앱 메뉴만 있고 편집 메뉴가 없어 first responder로 전달 불가. `AppDelegate.makeMainMenu`에 편집 메뉴(실행 취소/다시 실행/잘라내기/복사/붙여넣기/지우기/모두 선택, target nil=responder chain) 추가. `ApexKeyMenuTests` 회귀 테스트
- [x] T-135: 동작 고정 프리셋 — 시스템 탭(SystemActionType)과 동급 취급. `BuiltInShortcutPresets`(Android Untether/Mirror 2개, 단축키 없음·삭제 가능)에 코드 고정 + `ensureBuiltInShortcuts`가 설치·업데이트 후 이름 기준 자동 보충. 구 `ADB Wi-Fi 연결`명 재생성 중단 (중복 방지). 미러 scrcpy 옵션(`--show-touches --stay-awake --legacy-paste --max-size=1024 --video-bit-rate=2M --max-fps=30`) 반영
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
- [x] T-141: SettingsView 언어 선택 섹션(Picker: 시스템/한국어/영어) + 재시작 필요 안내
- [x] T-142: 전체 UI 문자열 키 추출·ko/en 번역 + Text(LocalizedStringKey) 치환 + ActionMetadata 연계

## v0.6 — 잔여 문자열 다국어화 (PLAN_v0.6_l10n)

- [x] L-01: 키 "variable.*" 추가 + VariableModels displayName 로컬라이즈
- [x] L-02: 키 "condition.op.*"·"flow.*" 추가 + FlowControlModels 로컬라이즈
- [x] L-03: 키 "category.app.*" 추가 + AppItem AppCategory 로컬라이즈
- [x] L-04: 키 "system.action.*"·"color.name.*" 추가 + SystemActionType/ShortcutColor 로컬라이즈
- [x] L-05: 키 "step.*" 추가 + Shortcut.summary/runCount/lastRun 로컬라이즈
- [x] L-06: 키 "error.user.*" 추가 + ExecutionEngine/ActionExecutor/AIAvailability 사용자 에러 로컬라이즈
- [x] L-07: ConfigStore(+Preferences/+Macro/+Bindings) + Views(ThemeSettings/SidebarNavigation/StepSettings/MenuHUD/HotKeyRecorder) + AppDelegate 창 타이틀 로컬라이즈
- [x] L-08: ApexKeyModelTests를 키 기반 비교로 재작성 (언어 무관)
- [x] L-09: 검증 — strings 문법(plutil OK) + 코드 참조 키 526 전수 존재 + build_and_run test smoke 통과(compile) + 현지화 가드 0건 통과
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

## 다음 백로그

- [ ] 대형 파일 분할 (CustomTheme 1600줄·AppDelegate 845줄)
- [ ] `menuPath` 편집 UI + `runShortcut`/`system` 선택 UI (P1-5 잔류)
- [ ] blob 손상 덮어씀 가드 (P0-8 잔류 — 설계 필요)
- [ ] 단축키 프로필/빠른 전환
- [ ] Run Shortcut 호출 시 ConfigStore 자동화 UI에서 조회 단계 연결 (multishortcut 재귀 공유 변수 전달)
- [ ] Choose from Menu/Use Model 등 단계 저장값(actionParameters) UI 연동 세부 다듬기
- [ ] 오프라인/큐(비해당 — 로컬 앱)
- [ ] macOS 14 런타임 실기 검증 (v0.3.2로 SwiftUI 빈 윈도우 근본 제거, macOS 26에서 검증 완료) — 배포 타깃 14 컴파일만 보장
