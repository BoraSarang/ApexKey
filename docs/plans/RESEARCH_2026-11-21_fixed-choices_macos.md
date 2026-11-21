# RESEARCH 2026-11-21 — 고정 선택지 감사: 사용자가 자기 환경을 고를 수 없는 곳

> status: **조사 완료 (2026-11-21)** → **최소 결함 3건 구현 완료 (2026-11-21, R-20261121-01)**. 서드파티 통합·설정 확장은 보류.
> 질문: "터미널 앱 선택이 iTerm2/터미널로 고정돼 있다. 이렇게 고정된 항목을 쓰는 기능을 전부 찾아라. 자율성·유동성이 없는 것들, 비슷한 개념이어도 좋다."
> 범위: `Sources/ApexKey/` 전체 코드 읽기. 단계 설정 UI 피커, 실행 서비스, 앱 탐색, 설정 상수.
> 방법: `enum … CaseIterable`, 하드코딩 bundle ID, `AppFinder`, AppleScript 대상, 고정 상수 grep + 해당 파일 정독.
> 한계: 실기 클릭·실행 검증 없음(사용자 지시로 에이전트의 맥 제어 금지). Ghostty·Warp·kitty·WezTerm의 폴더 열기·AppleScript 사전 지원은 **미실측**.

---

## 0. 결론 먼저

**터미널은 "목록만" 고정된 게 아니다.** 설정 화면의 피커가 2종인 것을 넘어, `TerminalLauncher.resolveApp`이 enum에 없는 bundle ID를 **거부**한다. 그래서 Ghostty의 bundle ID를 어딘가에 넣어도 `nil`이 되어 "터미널 앱 없음"으로 실패한다. 반면 "새 창" 실행은 `NSWorkspace.open(_:withApplicationAt:)`이라 **앱이 폴더 열기만 지원하면 무엇이든 된다.** 막고 있는 것은 실행 계층이 아니라 **2-case enum 하나**다.

같은 패턴(외부 앱을 enum 또는 고정 AppleScript 이름으로 지정)이 6묶음 더 있다.

| 묶음 | 고정된 것 | 사용자가 쓰는 앱 예시(불가) |
|---|---|---|
| 터미널 | iTerm2, Terminal | Ghostty, Warp, kitty, WezTerm, Alacritty |
| 문서 | TextEdit, Pages, Numbers | Word, Excel, Obsidian, Typora, Bear |
| Apple 앱 1 | Notes, Reminders, Calendar | Things, Todoist, Notion, Fantastical |
| Apple 앱 2 | Mail, Music, Podcasts, Photos | Outlook, Spark, Spotify, Overcast |
| 콘텐츠 | Messages, Apple Maps, Keynote | KakaoTalk, Google Maps, PowerPoint |
| URL 열기 | 기본 브라우저 | Chrome/Arc/Firefox로 고정 |

자유 입력 우회로가 있는 곳은 3곳이다: **앱 실행**(검색 + OpenPanel + bundle ID 직접 입력), **파일 열기**(bundle ID 직접 입력, 피커는 없음), **앱 목록 화면의 수동 추가**(OpenPanel). 반면 **팔레트 검색과 메뉴 명령은 스캔 결과만** 쓰고, 메뉴 명령에는 우회로가 아예 없다.

나머지는 "닫힌 집합이 타당한" 것들이 대부분이다(텍스트 변환·해시·단위·시스템 동작). 이 문서는 **사용자 환경에 따라 달라지는 것**과 **제품이 일부러 닫은 것**을 분리했다.

---

## 1. 한눈에 보는 표

영향: 🔴 기능 자체를 못 씀 / 🟠 불편하지만 우회 가능 / 🟡 취향·낮음
난이도: S(1~2파일) / M(설정 모델+UI+테스트) / L(기능 확장)

| # | 기능 | 고정된 내용 | 우회로 | 영향 | 난이도 | 근거 |
|---|---|---|---|---|---|---|
| 1 | 터미널에서 열기 | iTerm2 / Terminal 2종, enum 밖 거부 | 없음 | 🔴 | S | `TerminalLauncher.swift:5`, `:37-46` |
| 2 | 메뉴 명령 | 스캔된 앱 목록에서만 선택 | 없음 | 🔴 | S | `MenuCommandSettingsView.swift:42-127` |
| 3 | 앱 탐색 | 4개 디렉터리·비재귀 | 앱 실행은 OpenPanel | 🟠 | S | `AppFinder.swift:8-42` |
| 4 | 문서 앱 | TextEdit / Pages / Numbers | 보기만 기본 앱 | 🔴 | M | `DocumentConfig.swift:11-45` |
| 5 | Notes·Reminders·Calendar | Apple 앱 고정 | 없음 | 🔴 | L | `AppleAppConfig.swift:13-58` |
| 6 | Mail·Music·Podcasts·Photos | Apple 앱 고정 | 없음 | 🔴 | L | `AppleMediaApps.swift`, `MediaEditing.swift:389-421` |
| 7 | Messages·지도·프레젠테이션 | Messages / Apple Maps / Keynote | 없음 | 🟠 | L | `ContentLinkActions.swift:72,124,266` |
| 8 | URL 열기 | 기본 브라우저 | 없음 | 🟠 | S | `ActionExecutor.swift:90-95` |
| 9 | 파일 열기 앱 | 자유 입력이지만 피커 없음 | bundle ID 직접 입력 | 🟠 | S | `StepMiscViews.swift:100-115` |
| 10 | 스크린샷 | 대화형 + 데스크탑 저장 고정 | 없음 | 🟠 | S | `SystemActionExecutor.swift:248-259` |
| 11 | 창 타일링 | 40 / 50 / 60% 3종 | 없음 | 🟡 | S | `SystemActionExecutor.swift:17-23` |
| 12 | 카메라 | 기본 비디오 장치 | 없음 | 🟠 | S | `CameraCapture.swift:38` |
| 13 | 클립보드 | 100건·30일·5MB·200MB, 제외 앱 8개 | 없음 | 🟠 | M | `ClipboardHistory.swift:61-76` |
| 14 | 셸 | `/bin/zsh -c` (파일은 `/bin/bash`) | 없음 | 🟠 | M | `ActionExecutor.swift:203,235` |
| 15 | AI 제공자 | Apple 4종(그리고 stub) | 없음 | 🟡 | L | `AIModels.swift:4-64` |
| 16 | 앱 카테고리 | 9종 고정 | 수동 변경만 | 🟡 | S | `AppItem.swift:33-70` |
| 17 | 단축키 색상 | 13색 enum, 선택 UI 없음 | 없음 | 🟡 | S | `Shortcut.swift:633` |
| 18 | 시스템 동작·트랙패드 | 닫힌 집합 | 스크립트·워크플로우로 확장 | 🟡 | — | `SystemActionExecutor.swift`, `TrackpadModels.swift` |
| 19 | 텍스트·데이터 변환 | 닫힌 집합 | 없음(대상이 명확) | 🟡 | — | `DataActions.swift`, `TextActionConfig.swift` |
| 20 | 테마·HUD·키캡 | 프리셋 | 사용자 테마·폰트 크기 | 🟡 | — | `ThemeSettingsView.swift` |

---

## 2. 상세

### 2.1 터미널에서 열기 — iTerm2 / Terminal (🔴, S)

**왜 2종인가.** T-195가 iTerm2와 Apple Terminal만 구현했다. 새 탭 열기가 앱별 AppleScript에 의존하기 때문이다. 문제는 **새 창**까지 같은 enum으로 묶은 것이다.

```swift
// TerminalLauncher.swift
enum TerminalApp: String, CaseIterable, Identifiable {
    case iTerm2 = "com.googlecode.iterm2"
    case appleTerminal = "com.apple.Terminal"
}

static func resolveApp(bundleID: String?, isInstalled: (String) -> Bool = ...) -> TerminalApp? {
    let trimmed = ...
    if !trimmed.isEmpty {
        return TerminalApp(rawValue: trimmed)   // ← enum 밖이면 nil
    }
    return TerminalApp.allCases.first { isInstalled($0.bundleID) }
}
```

- `TerminalOpenConfig.appBundleID`는 `String?`이라 저장 자체는 자유롭다. 하지만 실행 시 `resolveApp`이 enum으로 좁힌다. **설정 파일을 직접 고쳐도 Ghostty는 열리지 않는다.**
- "새 창" 경로(`TerminalLauncher.open`)는 `NSWorkspace.shared.open([folder], withApplicationAt: appURL, ...)`이다. 폴더 열기(`application:openFile:`)를 지원하는 앱이면 **이미 범용**이다.
- "새 탭" 경로만 `tell application "iTerm2"` / `"Terminal"`로 고정이다.
- 직접 핫키 바인딩은 `actionParameters`가 없어 **항상 자동·새 창**이다(`ActionExecutor.swift:103-107`). 워크플로우 단계에서만 설정이 먹는다.

**설계 제안**

1. `TerminalApp`을 `TerminalTarget`으로 확장:
   - `.auto`
   - `.known(TerminalApp)` — 새 탭 AppleScript 지원
   - `.custom(bundleID: String, path: String)` — 새 창만 지원
2. `resolveApp`은 `.custom`이면 설치 여부만 확인하고 통과.
3. UI: 기존 피커 아래 **"다른 앱 선택…"** 버튼(OpenPanel, `.applicationBundle`) + 저장된 앱 이름 표시. 새 탭 선택 시 "이 앱은 새 창만 지원합니다" 안내.
4. 새 탭은 known 2종에서만 활성화. Ghostty 등이 AppleScript/CLI로 새 탭을 지원하면 그때 추가.
5. 직접 핫키 바인딩에도 설정을 붙이려면 `HotKeyBinding`에 `actionParameters`가 필요하다 — 별도 스키마 작업(T-195 후속).

> 주의: Ghostty가 `open -a Ghostty <폴더>`를 폴더 열기로 처리하는지, 새 창/새 탭 CLI가 있는지는 **실측 전 확정하지 않는다.** 이 문서는 "enum이 막고 있다"까지만 주장한다.

---

### 2.2 메뉴 명령 — 앱 목록에 우회로가 없음 (🔴, S)

`MenuCommandSettingsView`는 `AppFinder.installedApps()` 결과에서만 앱을 고른다. bundle ID 직접 입력 필드도, OpenPanel도 없다.

```swift
// MenuCommandSettingsView.swift
private var filteredApps: [AppItem] {
    ...
    return allApps.filter { ... }.prefix(20).map { $0 }
}
```

`AppFinder`가 놓친 앱은 **메뉴 명령을 아예 만들 수 없다.** 실행 계층(`MenuEnumerator.performAction(item, in: bundleID)`)은 bundle ID만 있으면 되므로 UI 제약이 전부다.

**설계 제안**: 앱 실행 화면과 같은 `AppPicker`를 재사용하고, "직접 선택…"(OpenPanel)과 bundle ID 입력을 추가. `AppFinder` 결과에 없어도 저장 가능해야 한다.

---

### 2.3 앱 탐색 — 4개 디렉터리·비재귀 (🟠, S)

```swift
// AppFinder.swift
var appURLs = [
    URL(fileURLWithPath: "/Applications"),
    URL(fileURLWithPath: NSHomeDirectory() + "/Applications"),
]
if includesSystem {
    appURLs.append(contentsOf: [
        URL(fileURLWithPath: "/System/Applications"),
        URL(fileURLWithPath: "/System/Applications/Utilities"),
    ])
}
for dir in appURLs {
    guard let entries = try? FileManager.default.contentsOfDirectory(...) else { continue }
    for url in entries where url.pathExtension == "app" { ... }   // ← 재귀 없음
}
```

- 하위 폴더에 설치된 앱(사용자 커스텀 폴더, 일부 배포판)이 누락된다.
- Finder는 별도 보정하지만(`/System/Library/CoreServices/Finder.app`), 다른 CoreServices 앱은 빠진다.
- 영향 범위: 팔레트 검색, 메뉴 명령, "설치된 앱 추가", 앱 실행 검색. 앱 실행은 OpenPanel, 앱 목록 화면은 수동 추가로 우회할 수 있지만 **팔레트 검색과 메뉴 명령은 스캔 결과만** 쓴다(메뉴 명령은 우회로 없음).
- 참고: `categorize`는 Spotlight/Info.plist 기반이라 하드코딩이 아니다(좋은 패턴).

**설계 제안**: `/Applications`·`~/Applications`를 **깊이 2까지 재귀** 스캔하고, `/System/Library/CoreServices`를 추가. 성능은 캐시(앱 목록은 자주 안 바뀜)로 상쇄.

---

### 2.4 문서 앱 — TextEdit / Pages / Numbers (🔴, M)

```swift
// DocumentConfig.swift
enum App: String, Codable, CaseIterable, Hashable {
    case textEdit, pages, numbers
    case defaultApp   // viewDocument 전용
}
```

- `viewDocument`만 `defaultApp`(기본 앱)이 가능하고, 생성·편집은 3종 고정이다.
- Word/Excel 사용자, Markdown 편집기 사용자는 "새 문서"·"문서 편집"을 못 쓴다.
- 본문 편집·글꼴은 TextEdit 전용이라는 구현 제약이 문서화되어 있다(`doc.unsupported_hint`).

**설계 제안(단계적)**
1. `viewDocument`에 "다른 앱으로 열기"를 추가 — `NSWorkspace.open(_:withApplicationAt:)`라 앱별 스크립트가 필요 없다. **가장 싸고 효과 큼.**
2. `newDocument`는 범용이 어렵다(앱마다 새 문서 명령이 다름). `open -a <앱>`으로 빈 파일을 여는 방식은 앱별 동작 차이가 커서 실측 후 결정.
3. `editDocument`/`setParagraphStyle`은 TextEdit 전용을 유지하고 UI에서 명시.

---

### 2.5 Apple 앱 1 — Notes / Reminders / Calendar (🔴, L)

`AppleAppConfig`와 `AppleApps`가 AppleScript로 Notes·Reminders·Calendar만 직접 제어한다. Things/Todoist/Notion/Fantastical은 구조적으로 불가하다.

- 이 묶음은 **"Apple 앱 연동"이라는 제품 기능**이므로, 서드파티 일반화는 단순 유동성이 아니라 신규 통합이다.
- 같은 이유로 시스템 동작 `.newNote`·`.newQuickNote`도 Notes 전용이다(`SystemActionExecutor`).
- 대안: `runShortcut`/`appAction`(URL scheme)로 사용자가 Shortcuts를 경유해 우회할 수 있다. 다만 발견성이 낮다.

**설계 제안**: 기능 동결 원칙상 **현상 유지**. 대신 단계 설정에 "다른 앱은 '단축어 실행' 또는 '앱 동작(URL)'으로 연결" 안내 1줄. 서드파티 통합은 별도 승인 사항.

---

### 2.6 Mail / Music / Podcasts / Photos (🔴, L)

- `AppleMediaApps`: Mail 초안·본문·수신자, Music 재생, Podcasts URL, Photos 최근/내보내기/앨범.
- `MediaEditing.music`은 `tell application "Music"` 고정. Spotify/YouTube Music 사용자는 재생 제어 불가.
- `FileActions.mailAttachments`는 `com.apple.mail` 실행 여부를 확인하고 Mail의 `selection`을 읽는다. Outlook/Spark 사용자는 첨부 저장 불가.
- Podcasts는 `sdef`가 없어 URL scheme만 지원한다고 문서화되어 있다(정직한 실패).

**설계 제안**
1. **음악 재생**을 `MediaApp`(Apple Music / Spotify / 사용자 지정)로 확장. Spotify는 AppleScript 사전이 있으므로 `tell application "Spotify"` 분기 추가 가능. 단, 앱별 스크립트·권한·테스트 필요.
2. **메일**은 `MailApp`(Apple Mail / Outlook / 사용자 지정)로 확장. 초안 작성은 앱별 AppleScript 차이가 커서 `mailto:` URL fallback이 현실적.
3. **첨부 저장**은 Mail 전용을 유지하되, UI에 "Apple Mail 전용" 명시.
4. Photos/Podcasts는 Apple 생태계 기능이므로 유지.

---

### 2.7 Messages / 지도 / 프레젠테이션 (🟠, L)

- 메시지: Messages AppleScript 고정.
- 지도: `https://maps.apple.com/` + `dirflg`(자동차/도보/대중교통) 고정. Google Maps 선택지 없음.
- 프레젠테이션: Keynote bundle ID 고정.

**설계 제안**
1. 지도는 **URL 템플릿**을 설정으로 빼면 앱 코드 없이 Google Maps/네이버 지도 지원이 가능하다(예: `https://maps.google.com/?q={query}`). 가장 싼 확장.
2. 메시지는 `sms:`/`imessage:` URL fallback 또는 Shortcuts 안내.
3. 프레젠테이션은 Keynote 유지(다른 앱은 URL scheme이 제각각).

---

### 2.8 URL 열기 — 기본 브라우저 고정 (🟠, S)

```swift
case .url:
    guard let url = URL(string: binding.target), url.scheme != nil else { ... }
    NSWorkspace.shared.open(url)   // ← 기본 브라우저
```

파일 열기는 `FileOpenConfig.appBundleID`로 앱을 지정할 수 있는데, **URL만 그런 설정이 없다.** Chrome/Arc 사용자가 "업무용 브라우저로 열기"를 만들 수 없다.

**설계 제안**: `URLOpenConfig { appBundleID: String? }`를 추가하고 `FileOpenConfig`와 같은 패턴(관대 디코딩, `actionParameters`)으로 저장. UI는 앱 피커 + "기본 브라우저" 옵션.

---

### 2.9 파일 열기 앱 — 자유롭지만 피커가 없음 (🟠, S)

`DefaultSettingsView`의 파일 단계는 `file.open_with.app` 레이블 아래 **bundle ID 텍스트 필드**만 제공한다. `FileOpenConfig` 자체는 자유롭다.

**설계 제안**: 앱 실행 화면의 `AppPicker`(검색 + OpenPanel)를 재사용. bundle ID 직접 입력은 유지(고급 사용자용).

---

### 2.10 스크린샷 — 대화형·데스크탑 고정 (🟠, S)

```swift
process.arguments = ["-i", "-x", path]   // 대화형 선택, 소리 없음
let desktop = FileManager.default.urls(for: .desktopDirectory, ...)
```
- 전체 화면/창/클립보드 저장, 타이머, 저장 폴더 선택이 없다.
- `screencapture`는 `-c`(클립보드), `-w`(창), `-m`(메인 디스플레이) 등을 지원하므로 설정만 추가하면 된다.

**설계 제안**: `ScreenshotConfig { mode: interactive|full|window|clipboard, destination: desktop|clipboard|customPath }` + 단계 설정 UI.

---

### 2.11 창 타일링 — 40 / 50 / 60% (🟡, S)

`SystemActionType`에 `windowLeft40/50/60`, `windowRight40/50/60`이 고정되어 있다. 33%/66% 같은 비율은 불가.

**설계 제안**: 프리셋은 유지하되 "사용자 비율" 액션 1개(`windowLeftCustom`) + 단계 설정에서 % 입력. 또는 기존 6종을 파라미터형으로 통합(마이그레이션 필요).

---

### 2.12 카메라 — 기본 장치 고정 (🟠, S)

`AVCaptureDevice.default(for: .video)`만 쓴다. Continuity Camera/외장 카메라 선택이 없다.

**설계 제안**: `AVCaptureDevice.DiscoverySession`으로 장치 목록을 만들어 `CameraConfig.deviceID` 저장. 기본값은 현재 동작(시스템 기본).

---

### 2.13 클립보드 — 보관 정책·제외 앱 고정 (🟠, M)

```swift
static let maxItems = 100
static let retentionDays = 30
static let maxImageBytes = 5 * 1024 * 1024
static let maxTotalBytes: Int64 = 200 * 1024 * 1024

static let ignoredBundleIDs: Set<String> = [
    "com.apple.keychainaccess", "com.agilebits.onepassword7", ...
]
```

- 개수/기간/용량을 사용자가 못 바꾼다.
- 제외 앱은 비밀번호 관리자 8개 고정. 사용자가 "이 앱은 기록하지 마"를 추가할 수 없다.

**설계 제안**: 설정에 보관 개수(50/100/200/500)·기간(7/30/90/무제한)·제외 앱 추가/삭제를 노출. 저장은 `UserDefaults`(기존 `PrefKeys` 패턴).

---

### 2.14 셸 — zsh 고정 (🟠, M)

- 셸 명령: `/bin/zsh -c` (`ActionExecutor.swift:235`)
- 스크립트 파일: `/bin/bash <path>` (`:203`, shebang 존중 목적)

fish/nu 사용자는 자신의 셸 환경(PATH·alias·함수)로 실행되지 않는다. `PATH`는 `ShellEnvironment`가 Homebrew/Android SDK를 보정하지만, 셸 자체는 바꿀 수 없다.

**설계 제안**: `ShellConfig { executable: String, login: Bool }` — 기본 `/bin/zsh -lc`, 고급에서 경로 변경. 보안상 임의 셸 실행은 사용자 명시 설정으로 제한.

---

### 2.15 AI 제공자 — Apple 4종 고정, 현재 stub (🟡, L)

`AIModelType`은 `onDevice`, `privateCloud`, `chatGPT`, `askEachTime` 4종이다. 외부 API(OpenAI/Anthropic/Gemini/Ollama) 제공자가 없다. 다만 `useModel`·`writingTool`·`imagePlayground`는 **`.stub`** 이라 카탈로그에서 선택할 수 없다(`ActionType+Implementation.swift`). 지금은 사용자 영향이 없다.

**설계 제안**: 기능 동결 원칙상 **현상 유지**. AI를 실제로 열 때 제공자 추상화(`AIProvider` 프로토콜)를 먼저 설계하고, 그때 로컬/클라우드 선택을 넣는다. 지금 "유동성"만 추가하는 것은 의미 없음.

---

### 2.16 앱 카테고리 — 9종 고정 (🟡, S)

`AppCategory`는 App Store 표준 9종이다. 사용자가 카테고리를 수동 변경할 수는 있지만, **새 카테고리를 만들거나 이름을 바꿀 수는 없다.** 사이드바 그룹핑 용도라 영향은 낮다.

---

### 2.17 단축키 색상 — 13색 enum, 선택 UI 없음 (🟡, S)

`ShortcutColor`는 13색이지만 설정 화면에 색상 피커가 없다(기본 `.blue`). "고정 목록"이라기보다 **미노출 기능**에 가깝다. 필요하면 색상 선택 UI만 추가하면 된다.

---

### 2.18 의도적으로 닫힌 집합 (문제 아님)

| 영역 | 이유 |
|---|---|
| 시스템 동작(`SystemActionType`) | OS가 제공하는 동작 목록. 스크립트·단축어로 확장 가능 |
| 자동화 트리거(`AutomationModels`) | OS 이벤트 종류가 닫힌 집합. 사용자 정의 이벤트 소스는 별도 기능 |
| 트랙패드 제스처/슬라이더 | 대상은 기존 자산(워크플로우·핫키·메뉴·시스템) 재사용 — 유동성 충분 |
| 텍스트·데이터 변환(해시·케이스·단위·정렬) | 변환 알고리즘 자체가 닫힌 집합 |
| 파일 조작(복사·이동·휴지통 등) | OS 동작이 닫힌 집합 |
| 테마·HUD·키캡 | 취향 옵션. 테마는 사용자 테마·폰트 크기로 확장 가능 |
| App Intent | 공개 런타임 API가 없어 Shortcuts 경유가 유일(문서화됨) |

---

## 3. 공통 패턴과 설계 제안

### 3.1 "고정 목록 + 자유 입력 escape hatch"를 표준으로

이미 좋은 선례가 있다.

- **앱 실행**: 검색 + `NSOpenPanel` + bundle ID/경로 직접 입력 (`LaunchAppSettingsView`)
- **파일 열기**: bundle ID 직접 입력 (`DefaultSettingsView`)
- **앱 목록 화면의 수동 추가**: OpenPanel (`AppsContentView.addAppManually`)

이 패턴을 앱을 고르는 모든 곳에 적용한다.

```
[앱 피커]
( ) 자동 (iTerm2 우선)
( ) iTerm2
( ) Terminal
(•) 직접 선택: [Ghostty            ] [찾기…]
    com.mitchellh.ghostty
```

공통 컴포넌트 후보: `AppChoiceField`
- 검색 가능한 설치 앱 목록(`AppFinder`)
- OpenPanel("찾기…")
- bundle ID/경로 직접 입력(고급)
- 선택 해제("자동/기본")
- 저장 형식: `{ bundleID: String?, path: String? }` (기존 `LaunchConfig`와 호환)

### 3.2 실행 계층은 이미 범용인 곳이 많다

- 파일 열기: `NSWorkspace.open(_:withApplicationAt:)` — 앱 무관
- 새 창 터미널: `NSWorkspace.open([folder], withApplicationAt:)` — 폴더 열기 지원 앱 무관
- URL 열기: `NSWorkspace.open(url)` — 기본 브라우저만, 앱 지정 API 있음
- 앱 활성화: bundle ID/path — 앱 무관

**UI enum이 실행 계층보다 좁은 곳**이 핵심 문제다. 실행 계층을 먼저 확인하고 UI만 넓히면 되는 경우가 많다.

### 3.3 새 탭/앱별 스크립트는 별도 계층으로

새 탭·본문 편집·음악 제어처럼 **앱별 AppleScript가 필요한 기능**은 범용화 비용이 크다. 다음 원칙을 제안한다.

1. 범용 경로(새 창·열기·URL)는 모든 앱 허용
2. 앱별 고급 기능(새 탭·재생 제어·첨부 저장)은 "지원 앱" 목록 유지
3. UI에서 "이 앱은 새 창만 지원합니다"처럼 **지원 범위를 정직하게 표시**

---

## 4. 우선순위 제안

### 4.1 Quick wins (S, 1~2파일)

| 순위 | 항목 | 이유 | 상태 |
|---|---|---|:---:|
| 1 | 터미널 "다른 앱 선택…"(새 창) | 사용자가 바로 체감. 실행 계층은 이미 범용 | ✅ |
| 2 | 메뉴 명령 앱 직접 선택(OpenPanel) | 우회로가 아예 없던 유일한 곳 | ✅ |
| 3 | 파일 열기 앱 피커 | 자유롭지만 발견성 낮음 | — |
| 4 | URL 열기 앱 지정 | 파일 열기와 같은 패턴 | — |
| 5 | AppFinder 재귀 스캔 | 메뉴 명령·팔레트 누락 감소 | ✅ |
| 6 | 스크린샷 모드/저장 위치 | `screencapture` 옵션만 노출 | — |
| 7 | 창 타일링 사용자 비율 | 파라미터 1개 추가 | — |

> 구현 메모: 1·2·5만 적용했다(사용자 선택 — 최소 결함 3건). CoreServices 전체 추가는 시스템 내부 앱이 목록에 섞여서 보류하고 Finder만 유지한다.

### 4.2 중간 (M)

- 문서 보기 "다른 앱으로 열기"
- 카메라 장치 선택
- 클립보드 보관 정책·제외 앱 설정
- 셸 실행 경로 설정

### 4.3 큰 작업 (L, 별도 승인)

- Mail/Music 서드파티 통합(Outlook/Spark/Spotify)
- Notes/Reminders/Calendar 서드파티 통합(Things/Todoist)
- AI 제공자 추상화(기능 동결 해제 시)

---

## 5. 결정이 필요한 질문

1. **기능 동결과의 관계**: 이 항목들을 "버그 수정 + 실사용 마찰 개선"으로 볼 수 있는가? 터미널·메뉴 명령·URL 열기는 **기존 기능이 특정 앱에서만 동작하는 결함**에 가깝다. 서드파티 통합은 신규 기능이다.
2. **새 탭 범위**: Ghostty/Warp/kitty/WezTerm이 폴더 열기·새 탭을 CLI/AppleScript로 지원하는지 실측이 필요하다. 지원하지 않으면 "새 창만" 안내가 정직하다.
3. **서드파티 통합 우선순위**: Mail(Outlook/Spark)과 Music(Spotify) 중 무엇이 먼저인가? 둘 다 별도 기능 승인이 필요하다.
4. **AI 제공자**: 지금 stub인데 제공자 목록만 넓히는 것은 의미가 없다. AI 기능 자체를 열 때 함께 설계할지.

---

## 6. 한계

- 코드 읽기 기준이다. 실제 UI 클릭·실행으로 각 제한을 재현하지 않았다(사용자 지시로 맥 제어 금지).
- Ghostty·Warp·kitty·WezTerm의 폴더 열기/새 탭 지원은 공식 문서·실측을 확인하지 않았다.
- 서드파티 앱의 AppleScript 사전 유무(Spotify 등)는 일반적으로 알려진 범위에서만 언급했고, 이 맥에서 `sdef`를 열어 확인하지 않았다.
- `AppFinder`가 놓치는 앱의 실제 비율은 측정하지 않았다.
