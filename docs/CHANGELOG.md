# ApexKey — 변경 이력

> 형식: `{날짜} {platform} {error_code/부가} — 내용`
> 프로젝트 전체 변경 내역은 이 파일에 기록합니다.

## 2026-09-03 macos — 빈 창 제거(AppKit @main 전환) + 패널 토글 개선 + 전체화면 HUD 정렬 (A·B·C·D)

> **목표**: (A) SwiftUI `WindowGroup { EmptyView() }`가 만드는 시작 빈 창 근본 제거, (B) '뒤로 숨은' 패널을 메뉴바 클릭 한 번으로 앞으로 가져오기, (C·D) 전체화면 HUD 정렬 개선.
> BUILD SUCCEEDED · `./build_and_run.sh test macos unit` 통과(신규 회귀 포함 36/37, 기존 1건은 환경 의존 실패 무관).

- **A (빈 창 제거) — 순수 AppKit `@main` 전환** — `Sources/ApexKey/ApexKeyApp.swift`(`@main struct ApexKeyApp: App` + `WindowGroup { EmptyView() }`, 빈 창 원본) 삭제하고 `Sources/ApexKey/main.swift` 신규:
  ```swift
  MainActor.assumeIsolated {
      let app = NSApplication.shared
      let delegate = AppDelegate()
      app.delegate = delegate
      app.run()
  }
  ```
  - 이미 AppKit(`NSPanel`/`NSStatusItem`)이 모든 창·메뉴바를 담당하므로 SwiftUI scene 불필요. `@main`과 top-level `main.swift` 공존 충돌 방지를 위해 `ApexKeyApp` 제거.
  - **`closeBootWindow()` 폐기** — WindowGroup이 사라져 시작 시 빈 창 자체가 생성되지 않음 (기존엔 `applicationDidFinishLaunching` 시점에 SwiftUI 창이 아직 없어 닫지 못하는 타이밍 문제로 잔류했음).
  - **`applicationShouldHandleReopen(_:hasVisibleWindows:)` 구현** — 파인더/Dock 재실행(open) 시 새 빈 창을 만들지 않고 메뉴바만 유지(선택 a). `hasVisibleWindows==true`면 기존 패널을 앞으로, 그 외엔 activate만.
- **B (패널 토글 개선) — `togglePanel`이 '뒤로 숨은 패널'을 앞으로 가져오기** — 기존 `if panel.isVisible`은 `hidesOnDeactivate=false`라 다른 앱 뒤로 숨은 패널(`isVisible=true`)도 '닫힘'으로 오판 → 첫 클릭이 반응 없음처럼 보임. `if panel.isVisible && (panel.isKeyWindow || NSApp.keyWindow === panel)`이면 닫고, 그 외엔 `activate + makeKeyAndOrderFront + orderFrontRegardless`로 앞으로 가져오기 (`AppDelegate.swift`)
- **C (전체화면 HUD 단일 메뉴 왼쪽 정렬) — 4열 틀 유지 + 좌측 정렬** — `MenuHUDOverlayView.grid`의 `HStack`이 중앙 정렬이라 메뉴 1개(첫 열·240폭)가 왼쪽 25%가 아니라 중앙(두 번째 칸 위치)에 옴. `ScrollView(.vertical)`로 명시(양방향 무한 폭 제안 회피) + `HStack`에 `.frame(maxWidth:.infinity, alignment:.leading)` 적용 → 4열 틀과 빈 칸은 유지하되 첫 열이 화면 가장 왼쪽에 (메뉴 1개 = 첫 칸 표시) (`MenuHUDOverlayView.swift`)
- **D (전체화면 HUD 단축키 없는 항목 keycap 자리 유지) — 고정 빈칸** — `row`/`selectableRow`가 `if hasKeyEquivalent { keycap }`이라 단축키 없는 항목은 keycap 자체가 사라져 `Text(title)`이 왼쪽 끝으로 밀려 정렬이 깨짐. 공용 `@ViewBuilder func shortcutSlot(_:)`으로 단축키 있으면 `keycap`, 없으면 **`Text("").frame(width:52, height:22)` 고정 빈칸**으로 텍스트 시작 위치(단축키 열) 세로 정렬 유지. ⚠️ 시행착오: `Color.clear.frame(minWidth:52)`는 flex 팽창으로 HStack 레이아웃을 깨뜨려(메뉴 오른쪽 밀림·빈 칸) 부적합, `Text("없음")` 배지는 정렬은 되나 어색 → **고정 크기 빈칸**으로 확정 (`MenuHUDOverlayView.swift`)
- **E (전 앱에서 시스템 '서비스' 메뉴 제거) — Services 서브메뉴 통째 제외** — 계산기 등 모든 앱에 macOS가 주입하는 표준 Services 메뉴(제목 '서비스'/영문 'Services')는 단축키 실행에 무의미하고 목록을 오염시킴. `MenuEnumerator.menuItems(from:)` 자식 재귀에서 title이 `"서비스"`/`"Services"`인 서브메뉴와 그 하위 전체를 건너뜀 (하드코딩 없이 전 앱 일관 제거) (`MenuEnumerator.swift`)
- **F (HUD macOS 표준 레이아웃: 메뉴명 … 단축키 + 서브메뉴 indent) — 단축키를 오른쪽으로** — 기존 HUD가 KeyCue식 '단축키 : 메뉴명'(단축키 왼쪽)이라 맥 표준과 어긋나고 들여쓰기가 어색했음. `row`/`selectableRow`를 **`메뉴명 … 단축키(오른쪽)`** 로 전환(전체화면+플로팅 모두). 서브메뉴 부모는 오른쪽 `▸`, 단축키는 오른쪽 keycap/고정 빈칸. `MenuItem`에 `depth` 필드 추가 + `flattenedWithDepth`(서브메뉴 부모 노드 포함·깊이 보존 평탄화, 최상위 메뉴 노드는 그룹 헤더와 중복이라 생략)로 HUD groups 구성 변경 → 서브메뉴 자식은 메뉴명 왼쪽에서 depth만큼 들여쓰기 (`MenuItem.swift`/`MenuEnumerator.swift`/`AppDelegate.swift`/`MenuHUDOverlayView.swift`/`MenuCheatSheetView.swift`)
- **G (HUD 서브메뉴 부모 클릭 크래시 수정) — SIGTRAP 방지** — `flattenedWithDepth`가 최상위 메뉴 부모 노드(menuPath 단일)를 HUD 행으로 노출시켜 클릭 시 `performAction`의 `path[1..<(path.count-1)]` = `path[1..<0]` 잘못된 범위 접근으로 크래시(EXC_BREAKPOINT/SIGTRAP). ① 최상위 depth 0 노드 생략, ② `performAction` 서브메뉴 체인 루프를 `path.count > 1`로 가드, ③ HUD/플로팅 모든 실행 진입점에서 `!item.isSubmenu` 가드로 서브메뉴 부모 클릭/Enter 실행 차단 (`MenuEnumerator.swift`/`MenuHUDOverlayView.swift`/`MenuCheatSheetView.swift`)
- **검증** — `open`으로 첫 실행·재실행 모두 창 count 0(빈 창 없음) + unified log `[APP] ApexKey 시작`/`No windows open yet` 확인. 핫키 `⇧⌥A`로 `[PANEL] 열기/닫기` 분기 검증. 전체화면 HUD(⇧⌥S, `pref.menuHUDStyle=fullscreen`) 메뉴 1개·5항목 표시·정상 닫힘 확인
- **참고(배경)** — 저장된 `NSWindow Frame SwiftUI.EmptyView-1-AppWindow-1` default 프레임 잔재는 더 이상 사용되지 않음(WindowGroup 제거로)

## 2026-09-03 macos — 흐름·자동화·AI 실행 심층 감사 버그 수정 (B8~B19, P1)

> 깊이 있는 코드 감사(4개 병렬 탐색)로 확인된 **확정 버그** 체계 수정 + 회귀 단위 테스트 19건 추가.
> BUILD SUCCEEDED · `./build_and_run.sh test macos unit` 통과(신규 19건 + 기존 모델 12건 0실패, 기존 1건은 환경 의존 실패 무관).

- **B13 (E-MAC-FLOW) — 반복 인덱스/항목이 특수변수 해석 안 됨** — `Repeat` 루프가 `repeatIndex`/`repeatItem`을 `context.setOutput`(stepOutputs)에만 저장했으나, `SpecialVariable.repeatIndex/repeatItem`은 `ResolveContext.repeatIndex/repeatItem`을 읽어 항상 null. `ExecutionContext`에 `repeatIndex/repeatItem` 상태 추가 + `executeRepeatCountEach`가 설정 + `makeResolveContext`가 전달 (`ExecutionEngine.swift`/`UseModelExecutor.swift`)
- **B14 — `notEquals`가 rightOperand 없을 때 항상 true** — `rightValue == nil || leftValue != rightValue` → 이항 비교로 수정(`rightValue nil/null이면 false`) (`FlowControlModels.swift`)
- **B15 — If 조건의 `ConditionOperand.specialVariable` 항상 null** — 조건 평가를 `[UUID:VariableValue]` 대신 `ResolveContext` 기반으로 전환, specialVariable(`repeatIndex`/`lastResult` 등)·magicVariable(`stepOutputs`) 해석 (`FlowControlModels.swift`/`ExecutionEngine.swift`)
- **B8 — `whileLoop` 0회 조용한 실패** — 매치 없이 `count ?? 0`=0회 실행 → 1회 폴백 + `E-MAC-FLOW-7008` 경고 (`ExecutionEngine.swift`)
- **B9 — Choose from Menu `NSAlert.runModal()` 비메인 스레드 호출** — 메인 스레드 보장(`main.sync`) (`ExecutionEngine.swift`)
- **B16 — `runPauseUntilInput`가 no-op(등록만 하고 복귀)** — 실제로 ⌘⇧↩ 입력까지 블로킹. 로컬 모니터는 메인 런루프에 등록, 호출 스레드는 세마포어 대기 (`ActionExecutor.swift`)
- **B17 — `runWait` 메인 스레드 `Thread.sleep` 블로킹** — 메인 스레드 시 백그라운드로 대기 분기 (`ActionExecutor.swift`)
- **B10 — 충전기 트리거 양쪽(연결/해제) 지정 시 한쪽만 평가** — `switch _ where` 분기가 첫 매치만 실행 → 각 eventType 독립 `if` 평가 (`AutomationManager.swift`)
- **B11 — 폴더 트리거 이벤트가 무조건 `.added`** — FSEvent 플래그(파생)로 `added/renamed/removed/modified` 판정 + 트리거 `eventTypes` 필터 (`AutomationManager.swift`)
- **B19 — 실행 통계가 실패에도 증가** — `executeShortcutStats`/`runAutomation`을 `execute` 성공 시에만 `runCount`/`lastRunAt` 갱신 (`ConfigStore.swift`)
- **B18 — 자동화 재등록** — `updateShortcutAutomations`가 `AutomationManager.unregister+register` 호출 확인(기존 커버), 위험 요소 없음 확인
- **신규 발견 — `VariableResolver.stringValue` 숫자 포맷** — `String(Double)`이 정수를 "2.0"으로 표시 → 정수는 "2"로 출력 (`VariableResolver.swift`)
- **도구 — `build_and_run.sh test macos {smoke|unit|full}` 서브커맨드 추가** (기존 빌드 게이트 문서상의 `test` 커맨드 부재 해소)
- **테스트 — `ApexKeyFlowTests` 19건 추가** — B13(B13 반복 인덱스 저장)/B15(LastResult 특수변수 조건 분기) 통합 회귀 + `Condition`(equals/notEquals/특수/매직/greaterThan/contains/isEmpty) + `VariableResolver`(토큰/마법 치환) + `RepeatRule`(평일/주말/매일) + `VariableValue`(Codable 왕복/타입 변환)
- **미해결 (문서화)** — B12 `RepeatRule.weekly/monthly/custom` 항상 true(요일/날짜 저장 필드 부재 → 모델 확장 필요), B7 일반 액션 `toBinding`이 `outputVariables`/`actionParameters` 탈락(R5 리팩터, 블록 편집 R1과 함께 별도 작업)

## 2026-09-03 macos — 동작을 iPhone 단축어 방식으로 전환 (v0.3, Phase 1~8)

- **변경** — '동작(단축어)'을 단순 순차 단계 나열에서 iPhone Shortcuts 방식으로 업그레이드
  - **도메인 모델(T-101)** — `ActionType` 12카테고리(앱/문서/웹/메시지/스크립트/파일/시스템/효율/개발/AI/흐름제어/기타), `Variable`/`FlowControl`/`AutomationTrigger`/`ShortcutPermissions` 모델, `ShortcutItem.combo/automations/variables`, `PersistedShortcut` JSON 데이터 컬럼(steps/triggers/variables/permissions)
  - **편집 UI(T-102)** — `ActionCatalogView`(액션 카탈로그)+`VariablePanelView`(변수 패널)+`StepRowView`/`BlockStepRow`/`StepListView`(계층 단계)+`ShortcutEditorView` 3열 편집기+`StepSettingsView`(T-107)+`AutomationSettingsView`(T-107)
  - **AI 통합(T-103)** — `AIAvailabilityManager`+`UseModelExecutor`/`WritingToolExecutor`/`ImagePlaygroundExecutor`(FoundationModels `#if canImport`+`#available(macOS 26)` 폴백), 커스텀 Logger 전환, 배터리(IOKit)/Wi-Fi(CoreWLAN) 조회
  - **흐름 제어(T-104)** — `ExecutionEngine`(If/Otherwise, Repeat/Repeat Each, Choose from Menu, Stop Shortcut, Set/Output Variable, Run Shortcut)
  - **자동화(T-105)** — `AutomationManager`(시간/폴더/FSEvents+3s debounce/배터리/충전기), 등록·해제·재등록, `runAutomation` 콜백
  - **변수 해석(T-106)** — `VariableResolver` ({매직변수}/{특수변수:name}, 배터리/Wi-Fi, 변수·단계출력·마지막출력 컨텍스트)
- **검증** — Phase 1~7 빌드 성공 후 Phase 8에서 `./build_and_run.sh build macos` → `** BUILD SUCCEEDED **`, `./build_and_run.sh debug macos` → 설치 완료 `~/Applications/ApexKey.app` (손상 없음)
- **Phase 8 하이라이트(T-108)** —
  - 단축키(combo)→단축어 실행 경로 확인(`handleHotKey`/`repeatLastBinding`) + 실행 시 `lastRunAt`/`runCount` 통계 갱신(`executeShortcutStats`)
  - RunShortcut 완성 — `ExecutionEngine.shortcutProvider`(ConfigStore에서 주입)로 실제 단축어 조회·재귀 실행 (`step.target`=UUID)
  - `syncShortcut`이 automations/variables/permissions 등 전 필드 영속화(기존 name/combo/steps만), 접근 제한 `private`→`internal`로 에디터 확장 메서드(`updateShortcutSteps/_Name/_Description/_Automations/_Variables`)에서 호출 가능하게 변경
  - `executeSetVariable`에 VariableResolver 변수 치환 + 값 타입 추론(숫자/불리언/텍스트)
- **문서** — `docs/TODO.md` v0.3 섹션(T-101~108) 기록, 'iPhone 단축어 방식 재검토' 백로그 항목 구현 완료로 제거

## 2026-09-03 macos — 동작 메뉴 명령 단계: 앱/메뉴 선택 UI (T-036)

- **증상** — 동작(단축어)에서 '메뉴 명령' 단계가 실행되지 않음
- **근본 원인** — `ShortcutStationView.buildStep`의 `.menuCommand`가 `target=""`(앱 미지정)·`menuPath=[]`(경로 미지정)로 단계를 생성. `ActionExecutor.execute`의 `.menuCommand`는 `performAction(item, in: binding.target="")`을 호출해 어느 앱에서도 실행하지 못해 구조적으로 실패. (앱 상세 뷰는 앱+경로가 고정돼 동작했지만 동작 단계는 정보가 비어 있었음)
- **수정** — `ShortcutStationView.swift`
  - 단계 편집에서 메뉴 명령 선택 시 '앱 피커' → 선택 앱의 **메뉴 트리에서 실행 항목 선택** UI 제공 (`menuCommandPicker` + 재귀 `MenuChoiceNode`)
  - `ShortcutStep.target=앱번들ID`, `menuPath=항목경로` 저장 (기존 `title` 텍스트 입력 제거) → `menuCommand` 단계가 정상 실행
- **검증** — 빌드 성공 + 재설치/재시작 완료 (PID 27649). IINA 메뉴 AppleScript로 확인: `재생 > 재생목록 반복 재생` 존재 → 동작으로 구성 가능

## 2026-09-03 macos — 시트 내용 상단 정렬

- '새 동작' 이름 입력 시트와 단계 편집 시트가 수직 중앙 정렬 → `.frame`에 `alignment: .topLeading` 추가로 상단 정렬 수정 (`ShortcutStationView.swift`)

## 2026-09-03 macos — 메뉴 HUD 4열 고정 + 단축키 없는 메뉴 포함 + 모디파이어/폴백 수정 (T-035)

- **증상** — ① 메뉴 HUD가 4열 고정 배치가 아니었다(6개 메뉴에서 3열로 줄어듦). ② 모디파이어가 전부 유실(예: "새 세션"이 "S"로 표시). ③ 점 표기 "…"/한글 제목이 단축키 키캡으로 오인 표시. ④ 단축키 없는 메뉴 항목이 HUD·앱 단축키 설정에서 누락
- **근본 원인** —
  - 그리드: 연속 블록 `ceil(n/4)` 청킹은 n=6에서 3열 생성 → `i % 4` round-robin으로 항상 4열 유지 필요
  - 모디파이어: AX `kAXMenuItemCmdModifiersAttribute`는 **low-4-bit 인코딩**(bit0⇧/bit1⌥/bit2⌃/bit3=⌘없음 역치). 기존 Carbon `cmdMask(1<<8)` 등으로 AND → 모든 모디파이어 유실
  - 폴백: `parseKeyEquivalent`가 문자가 1글자/F키(`^F\d+$`)가 아니어도 키로 취급해 "…"·한글을 키캡으로 표시
  - 필터: `shortcutItems`(단축키 있는 잎만)를 그대로 쓰면서 단축키 없는 명령이 목록에서 사라짐
- **수정** — `MenuEnumerator.swift`, `AppDelegate.swift`, `MenuHUDOverlayView.swift`, `MenuCheatSheetView.swift`, `AppDetailView.swift`, `ConfigStore.swift`
  - `menuColumns`: `i % 4` round-robin → 항상 4열(각 25%), `HStack(alignment:.top)` + 좌/상단 정렬
  - `keyEquivalent(from:title:)`: AX low-4-bit → Carbon flags 변환(commandChar/modifiers 정확화)
  - `parseKeyEquivalent(in:)`: 단일 문자·`^F\d+$`만 유효, 그 외 `("",0)` (단축키 없음)
  - `allItems(in:)` 추가: 서브메뉴 재귀 평탄화, 단축키 유무 무관 잎 평면화 → HUD 그룹 및 AppDetailView 검색에 적용
  - HUD 헤더에 모디파이어 범례(`⌘ ⌃ ⇧ ⌥ 🌐`) + `단축키 없는 메뉴 표시` 토글(`ConfigStore.showNoShortcutItems`, 기본 ON·Persisted)
  - 단축키 없는 항목: 키캡/배지 자리 미표시(제목만). 분리자(`isSeparator`): 텍스트 대신 가로 구분선. 검색 결과에서 분리자 제외
- **검증** — 빌드 성공, 유닛테스트 12건 통과(1건은 MovistPro 미설치 환경 실패·변경 무관), 재설치/재시작 완료 (PID 76271). 4열 최종 렌더는 사용자 확인 대기

## 2026-09-03 macos — 메뉴 실행 AppleScript 전환 (T-034, E-MAC-MENU-3002)

- **증상** — IINA "URL 열기…"/"열기…" 메뉴 단축키(테스트·핫키)가 프로세스 내에서만 실패. 로그: `메뉴 실행 경로: 파일 > URL 열기…` → `경로 단계 미발견: URL 열기… (단계 2/2)` → `E-MAC-MENU-3002`
- **근본 원인** — AX 직접 press(`child(named:)` 경로 해석 + `kAXShowMenuAction`/`kAXPressAction`)가 대상 앱 **활성화 직후 닫힌 트리에서 일시적으로 nil**을 반환하는 transient 실패. 독립 재현 스크립트(메인/백그라운드 스레드·activation 포함)로는 FOUND여서 앱 프로세스 한정으로 확인. 접근 로직/스레드/권한/샌드박스(미샌드박스) 이상 없음
- **수정** — `MenuEnumerator.performAction`을 AX 직접 press에서 **System Events AppleScript 메뉴 클릭**으로 교체
  - 경로 예 `["파일","URL 열기…"]` → `tell process "IINA" to click menu item "URL 열기…" of menu 1 of menu bar item "파일" of menu bar 1`
  - 3단계 이상 서브메뉴는 `of menu 1 of menu item "<중간>" of …` 체인으로 구성
  - AppleScript 계층은 빈 AXMenu 레벨을 자동 처리 → 구조 차이·transient nil이 구조적으로 소멸
  - 죽은 코드 정리: AX 경로 해석 `child(named:)`, `MenuActionResult.pressFailed(AXError)` 제거
- **검증** — 라이브 IINA에서 `exists menu item "URL 열기…" of menu 1 of menu bar item "파일" of menu bar 1` = true. 실제 핫키(⌥⌃L) 및 테스트에서 URL 열기 대화상자 6회 연속 성공. 빌드 + 유닛테스트 통과(환경 의존 `testRegisteredAppURLResolvedByBundleID`는 MovistPro 미설치로 실패, 변경 무관). 재설치/재시작 완료

## 2026-09-03 macos — 앱 간 빈 AXMenu 구조 차이로 인한 메뉴 실행 실패 해결 (T-033, E-MAC-MENU-3002)

- **증상** — T-032 이후 AIModelTalk/IINA는 실행되지만, MovistPro "파일 열기…"는 실행 실패. 실제 로그:
  `메뉴 실행 경로: 파일 >  > 파일 열기…` → `경로 단계 미발견: "" (단계 2/3)` → `E-MAC-MENU-3002 메뉴 항목을 찾지 못함`
- **근본 원인** — 빈 `AXMenu(title="")` 컨테이너 레벨의 유무가 **앱마다 다름**.
  - AIModelTalk/IINA: `AXMenuBarItem("파일") > AXMenu("") > AXMenuItem` (빈 레벨 존재)
  - MovistPro: `AXMenuBarItem("파일") > AXMenuItem` (빈 레벨 없음, 항목이 직계)
  T-032에서 빈 단계를 "무조건 보존"했더니, 빈 레벨이 없는 앱에서는 경로의 `""` 단계를 못 찾아 실패.
- **수정** — `MenuEnumerator.swift`
  - `makeMenuItem`: 빈 title 컨테이너를 `menuPath`에 넣지 않고 **자식 경로로 흡수** (`effectivePath`) → menuPath가 앱 무관하게 일관된 `["파일", "항목"]` 형태로 저장
  - `child(named:of:)`: **빈 title + submenu인 AXMenu 컨테이너를 재귀로 파고들어** 원하는 항목을 찾도록 개선 → 빈 레벨 있든/없든 동일 경로로 동작
- **검증** — 메모리 트리 시뮬레이션(빈 레벨 유/무 2구조 × 신규 child 로직) 전부 FOUND. 빌드 + 유닛테스트 통과(환경 의존 `testRegisteredAppURLResolvedByBundleID`는 MovistPro 미설치라 실패, 변경 무관). debug 빌드/설치/재시작 완료

## 2026-09-03 macos — IINA 등 메뉴 트리에 "(하위 메뉴)" 노드로 숨던 문제 해결 (T-033 후속, 메뉴 트리)

- **증상** — IINA 앱 상세에서 메뉴 트리가 안 나옴(실제 항목이 안 보임). 각 최상위 메뉴가 빈 `AXMenu("")` 컨테이너 하나를 유일한 자식으로 가져, 항목들이 한 단계 더 깊이 "(하위 메뉴)" 노드 안에 접힌 채로 숨음
- **근본 원인** — 메뉴 트리(`MenuTreeView`)가 `MenuItem.title`/`children`으로 그리는데, 열거 시 **빈 title인 `AXMenu("")` 컨테이너가 그대로 MenuItem 노드**로 만들어져 실제 항목들을 감쌌다
- **수정** — `MenuEnumerator` 열거를 `menuItems(from:parentPath:)`로 리팩터. 빈 title + submenu(AXMenu 컨테이너)는 **노드로 만들지 않고 자식만 상위로 끌어올림(flatten)** → 실질 항목들이 최상위 메뉴 직하에 나타남. menuPath도 `["파일", "열기…"]`로 깨끗하게 유지
- **검증** — 라이브 IINA AX로 확인: 파일 14개/재생 35개/비디오 28개 등 직접 항목 표시. `child(named:)` 실행 탐색도 "파일 > 닫기" FOUND (T-033 동작 보존). 빌드 + 유닛테스트 통과, 재설치/재시작 완료

## 2026-09-03 macos — 메뉴 단축키 테스트/실행 실패 해결 (T-032, E-MAC-MENU-*)

- **증상** — 메뉴 단축키 추가 시 테스트 버튼이 항상 실패 (저장 안 한 상태에서도)
- **근본 원인** — `MenuEnumerator.performAction`이 `menuPath.filter { !$0.isEmpty }`로 **빈 문자열(AXMenu 컨테이너, title="") 단계를 제거** → 실제 AX 계층(메뉴바 > 파일 > AXMenu("") > 항목)은 3단계인데 경로가 2단계(`["파일","새 대화"]`)로 축소되어 `.menuNotFound` 실패. 실제 `menuPath=["파일","","새 대화"]`로 AX 재현 스크립트로 확정
- **수정** — `MenuEnumerator.performAction`에서 `filter { !$0.isEmpty }` 제거. 빈 컨테이너 단계를 보존해 `child(named:"")`이 AXMenu와 1:1 일치 → 정상 탐색/실행
- **검증** — AX 재현 스크립트로 menuPath 확정, 빌드 + 유닛테스트 13건 통과, 재설치/재시작

## 2026-09-03 macos — 메뉴 목록 트리 표시 (T-031)

- 앱 상세 "메뉴 단축키" 섹션을 **전체 메뉴 트리로 표시**하도록 변경
- 검색어 없음 → `MenuTreeView`가 최상위 메뉴바 그룹을 기본 펼침으로, 하위 서브메뉴는 개별 펼침/접기(DisclosureGroup)로 계층 표시
- 검색어 입력 → 단축키 항목 평면 검색 결과로 전환 (기존 동작 유지)
- 재귀 `MenuTreeNode` 뷰 도입 (각 노드 고유 펼침 상태). 유닛테스트 13건 통과

## 2026-09-03 macos — 메뉴 단축키 검색 불가 해결 (T-030, E-MAC-MENU-*)

- **증상** — AI 모델 Talk, IINA 등에서 "메뉴 단축키를 찾을 수 없습니다" 표시 (접근성 권한·타깃 앱 실행 정상인데도 빈 목록)
- **근본 원인** — AX 메뉴 구조가 `AXMenuBarItem > AXMenu(title="") > AXMenuItem` 3단계인 앱에서, 제목 없는 `AXMenu` 컨테이너가 `MenuEnumerator.makeMenuItem`의 separator 판정(`title.isEmpty && combo.char.isEmpty`)에 걸려 **분리자로 버려지고, 그 자식(단축키 항목)이 전부 유실**
- **수정** — `MenuEnumerator.swift` separator 판정에 `&& children.isEmpty` 조건 추가. 제목이 비어 있어도 자식(submenu)이 있는 `AXMenu`는 separator가 아니라 submenu로 유지
- **검증** — 임시 AX 재현 스크립트로 AIModelTalk 30개 / IINA 81개 단축키 항목 추출 확인. 유닛테스트 13건 통과, debug 빌드/설치/재시작 완료

## 2026-09-03 macos — 접근성 권한 리빌드 유지 (T-029)

- **근본 원인** — `build_and_run.sh`의 ad-hoc 서명(`CODE_SIGN_IDENTITY=-`)은 리빌드마다 **다른 코드 identity**를 만들어 macOS TCC가 접근성 권한을 유지하지 못함 → "설정에서 삭제 후 재등록해야만 동작" 증상
- **수정** — 무료 Apple 개발자 인증서의 `DEVELOPMENT_TEAM=6GPJQ7BQC9` 고정 자동 서명으로 전환
  - `project.yml`: 앱/테스트 타깃 모두 `DEVELOPMENT_TEAM` 추가 (테스트 타깃 `CODE_SIGN_IDENTITY=-` 제거)
  - `build_and_run.sh`: `CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO` → 자동 서명으로 대체
- **검증** — `TeamIdentifier=6GPJQ7BQC9` 고정, 리빌드 2회 연속 동일 `CDHash` 확인 → 접근성 권한이 리빌드 후에도 유지. 유닛테스트 13건 통과, debug 빌드/설치 완료
- **사용자 조치** — 손쉬운 사용에서 ApexKey를 **1회만** 재허용하면 이후 리빌드에도 유지됨

## 2026-09-03 macos — 메뉴 명령 실행 경로화 (T-028)

- **메뉴 명령 미동작 근본 수정** — 열지 않은 채 하위 항목을 직접 `AXPress`하면 실패하던 구조를 경로 기반 실행으로 변경
  - `MenuItem.menuPath`: 최상위 메뉴부터 항목까지의 경로 체인을 열거 시 누적 저장
  - `HotKeyBinding.menuPath` + `PersistedBinding.menuPathRaw`: 메뉴 경로 영속 (자동 경량 마이그레이션, `ZMENUPATHRAW`)
  - `MenuEnumerator.performAction`: 저장된 경로를 따라 최상위 메뉴를 `kAXShowMenuAction`으로 순차 펼친 뒤 최종 항목 `kAXPressAction` — 경로 없음/권한/미발견/press 실패를 `MenuActionResult` enum으로 구분해 실패 원인 식별
  - `ActionExecutor.execute`가 `Bool` 반환 (메뉴 명령 성공 판별/테스트 안내에 사용)
  - 기존 경로 없는 메뉴 바인딩은 title 단일 경로로 fallback
- 단위 테스트 13건 통과 (신규: `menuPath` 영속 왕복, 경로 fallback), debug 빌드/설치 완료 (`~/Applications/ApexKey.app`)

## 2026-09-02 macos — 실행/토글이 미실행 앱도 실행 (T-027)

- **`AppSwitcher.activate` 개선** — 실행/토글 단축키가 꺼져 있는 앱을 못 여는 문제 수정
  - 기존: 바인딩에 경로 미저장(`target`=bundleID)이라 `path`가 nil → 미실행 앱 실행 불가 → 테스트/단축키 모두 `false`
  - 수정: 경로가 없으면 `NSWorkspace.urlForApplication(withBundleIdentifier:)`로 LaunchServices에서 앱 URL 해석 후 `open`
  - 스모크 테스트 추가: `com.apple.Safari`/`com.movist.MovistPro` 등록 앱 URL 해석 확인
- 단위 테스트 11건 통과, debug 빌드/설치 완료 (`~/Applications/ApexKey.app`)

## 2026-09-02 macos — "단축키가 안 먹는" 근본 원인 + 테스트 실동작 (T-024, T-025, T-026)

- **SwiftData 전용 저장소 경로** (`ConfigStore`) — 원인: 기본 경로 `~/Library/Application Support/default.store`가 다른 SwiftData 앱(채팅 앱)과 공유되어 스키마 충돌 → `ModelContainer` 생성 실패 → `addBinding`이 핫키 등록 전에 조기 반환되어 "저장 후 단축키 미동작"이 발생
  - 저장소 URL을 `~/Library/Application Support/com.borasarang.ApexKey/default.store`로 격리 (디렉토리 생성 포함)
  - 회귀 테스트 `ApexKeyStoreTests` 2건 추가 (전용 URL 컨테이너 생성·영속, 서로 다른 컨테이너 무충돌)
- **테스트 버튼 실제 액션 실행** (`HotKeyRecorderView` + 호출부 6곳)
  - `onTest` 프리뷰 추가: 테스트 키 감지 시 실제 액션(메뉴 명령/앱 실행·토글/시스템/스크립트/새액션/패널 토글) 수행
  - 실행 실패 시 "단축키는 감지됐지만 실행에 실패" 안내 (`testFailed`)
- **메뉴 명령 동작 방식 개선** (`AppDetailView`/`ActionExecutor`/`MenuEnumerator`)
  - 메뉴 명령 `onlyWhenAppActive=false` — 전면 여부와 무관하게 실행
  - 실행 시 대상 앱을 `AppSwitcher.activate`로 전면화 후 비동기 AX press
  - `findAXElement`를 leaf(`AXMenuItemRole`·하위 없음) 우선 매칭으로 개선 — 상단 메뉴 이름과 충돌 방지
- 참고: 기존 데이터는 점유된 default.store에 있어 소실 — 단축키 재설정 필요
- 단위 테스트 10건 통과, debug 빌드/설치 완료 (`~/Applications/ApexKey.app`)

## 2026-09-02 macos — 단축키 저장 검증 (T-022, T-023)

- **핫키 저장 플로우 개선** (`HotKeyRecorderView`)
  - "저장" 시 중복/사용 가능 여부를 먼저 검사
  - 사용 가능 → "적용되었습니다" 안내 후 3초 뒤 자동 닫힘
  - 중복/사용 불가 → 사유 안내 후 재입력 가능 (즉시 닫히지 않음)
  - 신규 "테스트" 버튼: 실제 등록 후 눌림을 확인해 성공/실패 표시
- **등록 가능성 검증 추가** (`HotKeyService`)
  - `isComboAvailable(_:)`: 임시 등록(RegisterEventHotKey) 후 즉시 해제로 시스템 점유 여부 판별
  - `beginTest`/`endTest`: 테스트용 임시 등록
- **교체 대상 조합 제외** (`HotKeyCombo.matches(_:)` + 호출부 배포)
  - 패널 토글 / 시스템 동작 / 앱 실행·토글 / 스크립트 단축키 재지정 시 같은 조합 허용
- 단위 테스트 8건 통과, debug 빌드/설치 완료 (`~/Applications/ApexKey.app`)