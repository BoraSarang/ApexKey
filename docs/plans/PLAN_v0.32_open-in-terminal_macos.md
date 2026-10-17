# PLAN_v0.32_open-in-terminal_macos — 터미널에서 열기 (T-195)

> status: in-progress (2026-10-17 착수)
> 전제: `docs/STATUS.md` 2026-10-15 (552건·v1.5.0) · 카탈로그에 터미널 계열 액션 **없음**(grep 확인)
> 사용자 요청: "파인더에서 선택한 디렉토리를 iTerm2로 열리게" → **워크플로우 단계로 등록**

## 1. 목표

- 파인더에서 고른 폴더를 **터미널(iTerm2 또는 터미널.app)에서 열기**를 ApexKey 카탈로그의
  정식 액션 1종(`openInTerminal`)으로 등록한다. 어떤 워크플로우에도 단계로 넣을 수 있다.
- 열 폴더 결정: **선택 우선 → 선택 없으면 현재 창 폴더** (사용자 확정).
- 터미널 앱: **자동(iTerm2 우선) / iTerm2 / 터미널** 선택식 (사용자 확정). 여는 방식: 새 창(기본) / 새 탭.

## 2. 왜 새 액션 타입인가 (기존 기능으로 불가)

- 기존 스텝(셸 스크립트/AppleScript)으로 흉내는 가능하지만
  ① Finder 경로 읽기가 사용자 스크립트의 몫이 되고 ② 카탈로그에 보이지 않는다.
- `ActionType.file` 확장으로는 불가 — "여는 앱"은 표현돼도 "터미널에서 그 폴더에 `cd`"는 다른 의미다.

## 3. 설계 (저장 스키마 변경 없음)

- **`ShortcutStep` 필드를 추가하지 않는다.** `stepsData` blob의 키 누락 내성(E-MAC-STORE-5008)을
  깨지 않기 위해 부가설정은 전부 `actionParameters` JSON(`TerminalOpenConfig{appBundleID, openInNewTab}`)에 넣는다.
  `FileOpenConfig`(T-188)와 동일 패턴. `target`은 "명시 경로(비우면 Finder)" 한 줄로 재사용.
- **Finder 경로는 AppleScript가 아니라 접근성(AX)으로 읽는다.** T-194에서 `Finder` AppleScript가
  Automation 권한 부족으로 실패한 전례가 있고, ApexKey는 이미 접근성 권한을 필수로 받는다.
  → `Services/FinderPathProvider.swift`. 실패는 `nil` + `E-MAC-TERM-810x` 로그, 호출부가 사용자 문구로 표면화.
- 순수 로직 분리(테스트 대상): `resolveFolder(selection:currentFolder:isDirectory:)`,
  `TerminalApp.resolve(bundleID:isInstalled:)`, `AppleScriptLiteral.quoted(_:)`.
- 실행 경로 2개를 모두 배선한다 (`FileOpenConfig`의 비대칭을 답습하되 문서화):
  - 워크플로우 단계 → `ExecutionEngine.executeOpenInTerminal` (actionParameters 사용)
  - 핫키 직접 바인딩 → `ActionExecutor.executeWithDetail` `case .openInTerminal` (config 없음 → 자동 앱·새 창)
- 여는 방식:
  - **새 창**: `NSWorkspace.open([folder], withApplicationAt:)` — Automation 권한 불필요.
  - **새 탭**: AppleScript(`create tab`/`do script`) — **Automation 권한 필요**. 실패 시
    `toast.reason.terminal_tab_failed`로 정직하게 실패(무음 폴백 없음).

## 4. 변경 파일

| 파일 | 내용 |
|---|---|
| `Models/ActionType.swift` | `case openInTerminal` + essential `actionTypes` 등재 |
| `Models/ActionMetadata.swift` | 메타데이터 1줄 (`action.openInTerminal`, `terminal.fill`) |
| `Models/ActionType+Implementation.swift` | `.implemented` 등재 (컴파일 강제 지점) |
| `Models/TerminalOpenConfig.swift` | 신규 — `appBundleID?`, `openInNewTab` (관대 디코딩) |
| `Services/FinderPathProvider.swift` | 신규 — AX로 선택/현재 폴더 해석 |
| `Services/TerminalLauncher.swift` | 신규 — 앱 선택·새 창/새 탭 열기 |
| `Utils/AppleScriptLiteral.swift` | 신규 — AppleScript 문자열 인용 단일 출처 (`MenuEnumerator` 중복 제거) |
| `Services/ActionExecutor.swift` | `case .openInTerminal` + `openInTerminal(path:appBundleID:newTab:)` |
| `Services/ExecutionEngine.swift` | `case .openInTerminal` → `executeOpenInTerminal` |
| `Views/StepSettings/TerminalOpenSettingsView.swift` | 신규 — 앱/방식/경로 설정 |
| `Views/StepSettingsView.swift` | 라우팅 1줄 |
| `Localizable.strings` (en+ko) | 액션명·설정 라벨·실패 문구 |
| `docs/TODO.md`, `docs/STATUS.md`, `docs/CHANGELOG.md`, `README*.md`, `website/**` | T-195 등록·수치 현행화 |

## 5. 오류 코드 (신규 대역 `E-MAC-TERM-81xx`)

- `8101` 접근성 권한 없음 · `8102` Finder에서 폴더를 찾을 수 없음 · `8103` 터미널 앱 없음 ·
  `8104` 폴더 열기 실패 · `8105` 새 탭 열기 실패(Automation)

## 6. 검증

- 신규 테스트 `OpenInTerminalTests`: config 라운드트립·구버전 JSON 내성, `resolveFolder` 4분기,
  `TerminalApp.resolve` 3분기, AppleScript 인용(따옴표/역슬래시/작은따옴표), 없는 경로 실패 시
  엔진이 `toast.reason.unimplemented`를 내지 않을 것.
- AX 순회 자체는 이 환경에서 **단위 테스트 불가** → 사용자 실동작 확인 항목으로 남긴다
  (`FUNCTIONAL_CHECKLIST.md` §8). 접근성 권한 없는 CI는 기존 T-184 패턴대로 스킵.
- 게이트: `check-localizable.py` 통과 · `check-version.py` 무변경 · `xcodebuild clean build` 경고 0 ·
  `./build_and_run.sh test macos unit`.

## 7. 범위 밖

- 서명·공증(TODO #1), macOS 14 실기, `error_message_ko.json`, 새 탭의 Automation 권한 사전 점검 UI,
  터미널 프로필 지정, iTerm2 종료 상태에서 시작 창이 함께 뜨는 문제(사용자 iTerm2 설정 영역).
