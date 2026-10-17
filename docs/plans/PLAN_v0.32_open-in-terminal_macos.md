# PLAN_v0.32_open-in-terminal_macos — 터미널에서 열기 (T-195)

> status: **완료 (2026-10-17)** — 구현·실측·사용자 실동작 확인까지 끝. 단축키는 사용자가 ⌥E로 변경해 사용 중.
> 전제: `docs/STATUS.md` 2026-10-15 (552건·v1.5.0) · 카탈로그에 터미널 계열 액션 **없음**(grep 확인)
> 사용자 요청: "파인더에서 선택한 디렉토리를 iTerm2로 열리게" → **워크플로우 단계로 등록**

## 0. 최종 결론 (2026-10-17 실측 — 먼저 읽을 것)

파인더 폴더 읽기는 **AppleScript(Finder 자동화)** 로 한다. AX(접근성)로는 **이 macOS에서 불가능**함을 실측했다.

그리고 그 AppleScript가 T-194에서 실패한 **진짜 원인**은 권한 승인이 아니라 **하드닝 런타임
자동화 엔타이틀먼트 누락**이었다:

| 시점 | 관측 | 해석 |
|---|---|---|
| 엔타이틀먼트 이전 | `-1743` + **프롬프트 없음** | tccd: `Policy disallows prompt for com.borasarang.ApexKey` |
| 엔타이틀먼트 이전 | tccd에 AppleEvents 요청 기록 **없음** | TCC 이전 단계(AE 계층)에서 거부 |
| `com.apple.security.automation.apple-events` 추가 후 | 프롬프트 표시 → 승인 → `TCCDEvent: type=Create` | 정상 |
| 추가 후 실측 | `folder=/Users/lee/Documents/Files/Qwen2.5-32B` (선택 우선 OK) | 경로 정확 |

**파급**: 이 엔타이틀먼트 누락은 T-195만의 문제가 아니라 **System Events 메뉴 클릭·AppleScript/JXA
액션·새 탭 열기 전부**를 조용히 깨뜨리고 있었다(프로브: `System Events`·`Finder` 둘 다 `-1743`).
`ENABLE_HARDENED_RUNTIME: YES`인 동안은 "프롬프트도 안 뜨고 그냥 실패"하는 상태였다.

### AX 실측 근거 (왜 AX를 버렸는가)

| 확인 | 결과 |
|---|---|
| 창 `AXDocument` (현재 폴더) | `kAXErrorNoValue(-25212)` — **값 없음** |
| 목록 행/셀 | `AXURL`·`AXDocument`·`AXFilename` **속성 자체 없음** |
| 얻을 수 있는 것 | 폴더 **표시 이름**(`AXTitle` = "Files")·파일 이름뿐 → 절대 경로 불가 |
| `AXSections` | 속성 0개(불투명) |
| 접근성 권한 | `Allowed (System Set)` — 권한은 있으나 위 이유로 무용 |

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
- **Finder 경로는 AppleScript(Finder 자동화)로 읽는다** (§0 실측). AX는 이 macOS에서 현재 폴더도
  선택 항목 경로도 노출하지 않아 대안이 될 수 없다 — `resolveFolderURL()`을 AX로 구현한 초판은 폐기했다.
  → `Services/FinderPathProvider.swift`: `target of front window`(현재 폴더) + `selection`(선택)을
  **NUL 구분자 한 번의 스크립트**로 받아 파싱한다. 구분자가 NUL인 이유: 경로에 `\n`이 들어갈 수 있다.
  실패는 `Outcome{folder,failure}`로 돌려주고 호출부가 문구로 표면화(`automationDenied` / `notFound`).
- **하드닝 런타임 자동화 엔타이틀먼트를 추가한다** (§0): `Sources/ApexKey/ApexKey.entitlements`
  (`com.apple.security.automation.apple-events` = `<true/>` — 문자열 `YES`는 invalid로 실패)
  + `project.yml`의 `CODE_SIGN_ENTITLEMENTS`. 이 한 줄이 메뉴 클릭·AppleScript 액션·새 탭까지 함께 살린다.
  첫 사용 시 "Finder를 제어하려고 합니다" 승인 1회가 필요하고, 거부되면 `toast.reason.terminal_permission`
  으로 시스템 설정 경로를 안내한다.
- 순수 로직 분리(테스트 대상): `resolveFolder(selection:currentFolder:isDirectory:)`,
  `TerminalApp.resolve(bundleID:isInstalled:)`, `AppleScriptLiteral.quoted(_:)`.
- 실행 경로 2개를 모두 배선한다 (`FileOpenConfig`의 비대칭을 답습하되 문서화):
  - 워크플로우 단계 → `ExecutionEngine.executeOpenInTerminal` (actionParameters 사용)
  - 핫키 직접 바인딩 → `ActionExecutor.executeWithDetail` `case .openInTerminal` (config 없음 → 자동 앱·새 창)
- 여는 방식:
  - **새 창**: `NSWorkspace.open([folder], withApplicationAt:)` — **터미널에는** AppleEvent를 보내지 않는다.
    (Finder 폴더 읽기는 AppleScript라 자동화 권한이 필요하다 — §0. 이 점이 초판 설계와 달라졌다.)
  - **새 탭**: AppleScript(`create tab`/`do script`) — 자동화 권한 필요. 실패 시
    `toast.reason.terminal_tab_failed`로 정직하게 실패(무음 폴백 없음).

## 4. 변경 파일

| 파일 | 내용 |
|---|---|
| `Models/ActionType.swift` | `case openInTerminal` + essential `actionTypes` 등재 |
| `Models/ActionMetadata.swift` | 메타데이터 1줄 (`action.openInTerminal`, `terminal.fill`) |
| `Models/ActionType+Implementation.swift` | `.implemented` 등재 (컴파일 강제 지점) |
| `Models/TerminalOpenConfig.swift` | 신규 — `appBundleID?`, `openInNewTab` (관대 디코딩) |
| `Services/FinderPathProvider.swift` | 신규 — AppleScript로 선택/현재 폴더 해석 (NUL 구분 파싱은 순수 함수) |
| `Sources/ApexKey/ApexKey.entitlements` | **신규 — 하드닝 런타임 자동화 엔타이틀먼트 (근본 원인 수정)** |
| `project.yml` | `CODE_SIGN_ENTITLEMENTS` + `NSAppleEventsUsageDescription` 문구 확장 |
| `Services/TerminalLauncher.swift` | 신규 — 앱 선택·새 창/새 탭 열기 |
| `Utils/AppleScriptLiteral.swift` | 신규 — AppleScript 문자열 인용 단일 출처 (`MenuEnumerator` 중복 제거) |
| `Services/ActionExecutor.swift` | `case .openInTerminal` + `openInTerminal(path:appBundleID:newTab:)` |
| `Services/ExecutionEngine.swift` | `case .openInTerminal` → `executeOpenInTerminal` |
| `Views/StepSettings/TerminalOpenSettingsView.swift` | 신규 — 앱/방식/경로 설정 |
| `Views/StepSettingsView.swift` | 라우팅 1줄 |
| `Localizable.strings` (en+ko) | 액션명·설정 라벨·실패 문구 |
| `docs/TODO.md`, `docs/STATUS.md`, `docs/CHANGELOG.md`, `README*.md`, `website/**` | T-195 등록·수치 현행화 |

## 5. 오류 코드 (신규 대역 `E-MAC-TERM-81xx`)

- `8101` 자동화 권한 없음(`-1743` — 시스템 설정 경로 안내) · `8102` Finder에서 폴더를 찾을 수 없음 ·
  `8103` 터미널 앱 없음 · `8104` 폴더 열기 실패 · `8105` 새 탭 열기 실패

## 6. 검증

- 신규 테스트 `OpenInTerminalTests`(21건): config 라운드트립·구버전 JSON 내성, `resolveFolder` 4분기,
  AppleScript 출력 파싱 4건(NUL 구분·현재폴더 없음·빈 출력·경로 내 줄바꿈), `TerminalApp.resolve` 3분기,
  AppleScript 인용, 없는 경로 실패 시 엔진이 `toast.reason.unimplemented`를 내지 않을 것.
- **AppleScript 문법**: 추출한 스크립트를 `osacompile`로 컴파일 검증(권한 없이 가능).
- **라이브 실측**(임시 프로브 → 삭제): 엔타이틀먼트 추가 후 `folder=/Users/lee/Documents/Files/Qwen2.5-32B`,
  원시 출력 `[/Users/lee/Documents/Files/ | /Users/lee/Documents/Files/Qwen2.5-32B/ | ]` — 선택 우선 규칙 일치.
- 사용자 실동작 확인: **완료(2026-10-17)** — `FUNCTIONAL_CHECKLIST.md` §8-13 중 3항목 실측(자동화 승인,
  선택 폴더 3건, 선택 없이 현재 창 1건). 사용자는 단축키를 **⌥E**로 바꿔 사용 중(등록 시 제공값은 ⌥⌃T).
- 게이트: `check-localizable.py` 통과(1033키 ko/en 일치) · `check-version.py` 무변경 ·
  클린 빌드 신규 경고 0 · `./build_and_run.sh test macos unit`.

## 7. 범위 밖

- 서명·공증(TODO #1), macOS 14 실기, `error_message_ko.json`, 새 탭의 Automation 권한 사전 점검 UI,
  터미널 프로필 지정, iTerm2 종료 상태에서 시작 창이 함께 뜨는 문제(사용자 iTerm2 설정 영역).
