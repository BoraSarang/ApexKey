# ApexKey — 변경 이력

> 형식: `{날짜} {platform} {error_code/부가} — 내용`
> 프로젝트 전체 변경 내역은 이 파일에 기록합니다.

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