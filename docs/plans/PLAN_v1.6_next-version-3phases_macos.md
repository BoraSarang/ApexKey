# PLAN — 차기 3차 작업 (v1.6 ~ v1.8) 초안

> 작성: 2026-11-09 · 플랫폼: macOS · 상태: **1·2·3차 완료(구현 124/154) · `v1.8.0` 태그 생성(로컬)**
> 승인: 사용자 — "1차만 먼저 승인", 영구 제외 항목 확정. **2026-11-09 "2차 진행" 승인**.
> 근거: `docs/STATUS.md`, `docs/TODO.md`, `docs/FUNCTIONAL_CHECKLIST.md` §9,
> `ActionType+Implementation.swift`, `AutomationModels.swift`, `SystemActionExecutor.swift`
> 관련: 트랙패드 §8-14는 **이 계획에서 제외**(사용자 결정 2026-11-09)

---

## 0. 전제 — 먼저 승인받아야 하는 것

1. **제품 방향 예외**: `STATUS.md` §2는 "신규 기능 동결"이다. 이 계획은 카탈로그에
   "준비 중"으로 남은 기능을 실제로 구현하는 작업이므로 **동결 예외를 다시 여는 결정**이다.
   범위를 아래 3차로 한정하고, 끝나면 동결로 돌아간다.
   → **2026-11-09 승인: 1차 → 완료, 2차 → 완료, 3차 → 완료.** 3차 결과는 §9에 기록했다.
2. **v1.6.0 선행 조건**: 현재 `MARKETING_VERSION`은 1.5.0인데 v0.33(트랙패드)이
   main에만 있고 미배포다. 1차 릴리스는 **v0.33 + 이번 문서 정합 + 1차 작업**을 함께 묶는다.
   단, 트랙패드 실기 확인(§8-14)이 끝나기 전에는 릴리스하지 않는다.
3. **AI 3종은 계속 제외**: `useModel`·`writingTool`·`imagePlayground`는 무효화 유지.
4. **사설 API 금지 원칙 유지**: 공개 API/AppleScript/URL scheme으로 안 되면 "다음 버전"에
   남기거나 **영구 제외**로 내린다. 비공개 프레임워크 재도입은 별도 승인 없이는 하지 않는다.

> 승인 형태: "1·2·3차 범위 승인" / "1차만 승인" / "항목 조정" 중 하나.

---

## 1. 분류 원칙

| 기준 | 1차로 | 2차로 | 3차로 |
|---|---|---|---|
| 새 권한 | 없음 | 자동화(기존 엔타이틀먼트) | 카메라·화면 기록 등 |
| 의존성 | 시스템 프레임워크만 | AppleScript/파일 시스템 | 사설 API·외부 앱 |
| 위험 | 낮음 | 중간(데이터 변경) | 높음(실패 경로 많음) |
| 검증 | 단위 테스트 가능 | 픽스처+실기 | 실기 위주 |

**1차 목표**: "준비 중"을 실제 동작으로 바꾸되, 권한·데이터 위험 없이 끝난다.
**2차 목표**: 파일과 Apple 앱을 실제로 다룬다. 사용자 데이터 변경이 시작되므로 안전장치가 핵심.
**3차 목표**: 미디어·시스템·App Intents까지 넓히되, 안 되는 것은 과감히 제외한다.

---

## 2. 1차 — 카탈로그 정직성 + 무권한 순수 로직 (v1.6, 약 9~10일)

### 2-1. T-210 카탈로그 정직성 (1.5d) — **완료 (2026-11-09)**

| 항목 | 내용 |
|---|---|
| OneDrive 중복 | `.oneDrive`가 `action.drive` 키를 써서 카탈로그에 "OneDrive"가 2번 나온다 → `action.oneDrive`로 수정. `.drive`는 "OneDrive (항목 세부사항)"으로 구분 |
| 시스템 단계 중복 7종 | 스크린샷·새 메모·빠른 메모·배경화면·화면 깨우기·앱 전면으로 이동·다크모드는 **이미 `시스템` 단계로 실행 가능**하다. 별도 구현 대신 `.implemented`로 승격하고 `SystemActionExecutor`로 위임 |
| 중복 후보 판정 | `takeScreenshot`(→`screenshot`), `clipText`(→`getClipboard`/`setClipboard`)는 중복으로 판정해 카탈로그에서 숨김. `date`↔`dateFormatter`, `dialog`↔`getConfirmation`은 의미가 달라 유지 |
| 테스트 | `ActionCatalogIntegrityTests` 기대치 갱신, 승격 7종 매핑·엔진 배선·중복 숨김 테스트, 메타데이터 표시 키 유일성 테스트 |

**결과**: 구현 **52→59**, planned **99→92**(중복 숨김 제외 planned 노출 90 · 스텁 3 포함 UI "준비 중" 93). unit 614건 0실패(2 skip).
사용자가 보는 "준비 중" 목록이 실제와 가까워진다.

### 2-2. T-211 순수 로직 액션 14종 (7d) — **완료 (2026-11-09)**

| 묶음 | 액션 | 방법 | 예상 |
|---|---|---|---:|
| Vision | `recognizeText`, `scanQRCode`, `recognizeAnimal` | Vision OCR·바코드·동물 인식. 입력은 클립보드 이미지/파일 | 2d |
| 언어 | `detectLanguage` | `NLLanguageRecognizer` | 0.25d |
| 수치·날짜 | `measurement`, `adjustDate`, `typeDateTime` | MeasurementFormatter / Calendar / 기존 `KeySender` | 1d |
| UI | `dialog`, `getConfirmation`, `quickLook` | NSAlert / QLPreviewPanel | 1.5d |
| 프로세스 | `preventSleep` | `IOPMAssertion` 전원 어서션(프로세스 종료 시 자동 해제) | 0.5d |
| 데이터·파일 | `getDictionary`, `listActions`, `saveOutput` | plist/JSON 읽기, 카탈로그 목록 반환, FileManager 저장 | 1.5d |

- 공통: 액션당 **설정 UI + en/ko 키 + 단위 테스트** 포함(위 예상에 반영).
- `getDictionary`: JSON/plist를 읽고 `user.name` 점 표기로 중첩 탐색. 키가 비면 정렬 JSON 전체 출력.
- `listActions`: 카탈로그에서 실제 선택 가능한 액션만 `이름 (rawValue)` 줄 목록으로 출력 — 미구현을 섞지 않는다.
- `saveOutput`: 상위 폴더 생성, 경로가 폴더면 `output.txt`, `append`로 덧붙이기(기본 덮어쓰기).
- `typeDateTime`은 `TypingActions`를 재사용해 XCTest에서 실제 전송을 억제한다.
- 제외: `readTable`(의미 불명), `emailData`(Mail 연동은 2차).

**결과**: 구현 **59→73**, planned **92→78**(중복 숨김 제외 planned 노출 76 · 스텁 3 포함 UI "준비 중" 79). unit 651건 0실패(2 skip).

### 2-3. T-212 검증·릴리스 v1.6.0 (1.5d) — **검증 완료, v1.7.0에 통합**

- [x] unit 전체 0실패, 신규 액션 테스트 포함 — **651건 0실패(2 skip)**
- [x] i18n en/ko 키 일치, `check-localizable`·`check-version` 통과 — **1299키 일치**
- [x] `xcodebuild clean build` 경고 0 — **BUILD SUCCEEDED, 신규 코드 경고 0**(잔여 4건은 기존 `CommandPaletteView`·`ConflictPaletteView`·AppIcon)
- [x] `release-notes/v1.6.0.md` — **v0.33 트랙패드 포함**해 작성
- [ ] §8-14 실기 확인 후 태그 `v1.6.0` — **사용자 실기 확인 전 차단**

**1차 완료 기준**: 구현 52 → **73**, 준비 중 99 → **78**(스텁 3 포함 UI "준비 중" 79), 새 권한 0.

---

## 3. 2차 — 파일·Apple 앱·자동화 트리거 (v1.7, 약 16~18일)

### 3-1. T-213 파일 액션 7종 (3d) — **완료 (2026-11-09)**

`getFiles` · `moveFiles` · `renameFiles` · `extractArchive` · `externalStorage` · `fileActions` · `getAttachment`

- FileManager/`ditto`/`unzip` 사용. 앱이 샌드박스가 아니므로 사용자가 고른 경로는 접근 가능.
- **안전장치 필수**: 이동·이름 변경은 미리보기 + 확인 대화상자, 가능하면 직전 1회 실행 취소.
- 테스트는 임시 디렉터리 fixture로 수행(실사용 파일 건드리지 않음).
- **결과**: 7종 모두 `.implemented` + `ExecutionEngine.executeFileAction` 배선. 확인/취소 경로를
  주입 클로저로 검증, 실패 사유 14종 구분. `FileActionsTests` 25건, unit 676건 0실패(2 skip),
  i18n 1360키 일치. 구현 73→80, planned 78→71.

### 3-2. T-214 Apple 앱 연동 1 — Notes·Reminders·Calendar (3d) — **완료 (2026-11-09)**

`createNote` · `noteActions` · `reminders` · `calendar`

- 공개 AppleScript 딕셔너리가 안정적인 앱부터. 자동화 승인은 앱별 1회.
- 실패 시 사유 토스트(권한/앱 미실행/스크립트 오류 구분).
- **결과**: `osascript on run argv`로 인자를 넘겨 인젝션·따옴표 문제를 없앴다. Notes 본문은
  HTML escape 후 `<br>`, 날짜는 로케일 독립적인 분 오프셋. `AppleAppsTests` 21건,
  unit 698건 0실패(2 skip), i18n 1399키 일치. 구현 80→84, planned 71→67.

### 3-3. T-215 Apple 앱 연동 2 — Mail·Music·Podcasts·Photos (5d + 스파이크 1d) — **완료 (2026-11-09)**

`mail` · `setMailBody` · `setMailRecipients` · `emailData` · `playMusic` · `playPodcast` · `podcasts` · `photos` · `viewPhotos` · `album` · `randomPhoto` · `getLastPhoto`

- **선행 스파이크**: Photos는 AppleScript 지원이 제한적이라 가능한 동작을 먼저 실측한다.
  안 되면 URL scheme/Shortcuts 호출로 대체하거나 제외.
- Music/Podcasts는 재생·검색·현재 항목 정도로 범위를 좁힌다.
- **스파이크 결과**: Mail·Music·Photos는 `sdef` 있음. Photos는 `media item`·`export`·`spotlight`·
  `album`으로 최근 목록·내보내기·앨범이 가능. **Podcasts는 `sdef`가 없어**(-192) URL scheme만
  지원하고 검색 재생은 불가능하다고 실패시킨다.
- **결과**: 12종 구현. 메일은 기본 초안 열기(`sendImmediately`만 발송). `AppleMediaAppsTests` 22건,
  unit 721건 0실패(2 skip), i18n 1441키 일치. 구현 84→96, planned 67→55.

### 3-4. T-216 문서 앱 연동 (2d) — **완료 (2026-11-09)**

`newDocument` · `viewDocument` · `editDocument` · `setParagraphStyle`

- Pages/Numbers/TextEdit 대상. iWork가 없으면 "앱 미설치" 사유를 명확히 표시.
- **실측**: 이 기기에는 Pages·Numbers가 없다(`sdef` -43). TextEdit은 문서·본문·글꼴 속성을 제공.
  그래서 설치 여부를 먼저 확인하고, Pages·Numbers는 표준 `open`/`make new document`만 쓴다.
  본문 편집·글꼴 지정은 TextEdit 전용으로 제한(`unsupportedApp`).
- **결과**: 4종 구현, `DocumentAppsTests` 20건, unit 742건 0실패(2 skip), i18n 1467키 일치.
  구현 96→100, planned 55→51.

### 3-5. T-217 자동화 트리거 4종 (3d) — **완료 (2026-11-09)**

`file` · `externalDrive` · `display` · `app`

- `file`: 기존 FSEvents(폴더 트리거) 인프라 재사용 — **가장 먼저**
- `externalDrive`: `NSWorkspace.didMount/didUnmountNotification`
- `display`: `NSApplication.didChangeScreenParametersNotification`
- `app`: `NSWorkspace.didLaunch/didTerminateApplicationNotification`
- `AutomationSettingsView`에서 지원 카테고리만 노출. Wi-Fi·블루투스·집중모드·스테이지매니저는 3차.
- **결과**: `isWatcherSupported` 4→8종. 파일은 부모 폴더 FSEvents + 정확 경로 매칭, 드라이브·앱은
  `NSWorkspace` 알림, 디스플레이는 화면 수 변화로 판정(해상도 변경 무시). 설정 UI에 경로·드라이브·
  번들 ID·이벤트 편집 추가. 옵저버·스트림은 재구축 시 함께 해제. `AutomationTriggersTests` 13건,
  unit 755건 0실패(2 skip), i18n 1477키 일치.

### 3-6. T-218 검증·릴리스 v1.7.0 (1.5d) — **완료 (2026-11-09, `v1.7.0` 태그 생성)**

- 데이터 변경 액션은 실패 경로·취소 경로 테스트를 반드시 포함
- 실기 확인 항목을 `FUNCTIONAL_CHECKLIST.md`에 새 절로 추가(사용자 손 필요)
- 릴리스 노트·버전 범프·태그
- **결과**: `release-notes/v1.7.0.md`(v1.5.0 이후 전체 통합), `v1.6.0.md`에 미배포 표시,
  `MARKETING_VERSION` 1.7.0. §8-15(20항목)·§8-16(7항목) 실기 확인 대기 추가.
  unit 755건 0실패(2 skip), 버전 가드 1.7.0 통과. **`v1.7.0` 태그 생성(로컬), push 안 함.**

**2차 완료 기준**: 구현 약 73 → **100**(예상 93 초과), 자동화 트리거 4 → **8**, 데이터 변경 액션은
확인/취소 경로 테스트 100%.

---

## 4. 3차 — 미디어·시스템·App Intents + 백로그 (v1.8, 약 20일)

### 4-1. T-219 시스템 액션 6종 (4d, 일부 보류 가능)

`focusMode` · `preventSleep`(1차 완료) · `clearRecents` · `airDrop` · `bluetooth` · `network`

| 항목 | 판단 |
|---|---|
| 집중 모드 | Shortcuts/AppleScript 의존 → 사용자가 만든 단축어 호출 방식이면 가능 |
| 최근 항목 지우기 | UI 자동화 필요 → 실패 경로가 많으면 **영구 제외** |
| AirDrop | UI 자동화 필요 → **보류 권장** |
| Wi-Fi | 공개 CLI(`networksetup`) 가능성 있음 → 실측 후 결정 |
| 블루투스 | 공개 API 없음 → **영구 제외 권장** |

### 4-2. T-220 미디어 편집·캡처 (5d)

`camera` · `rotateImage` · `cropImage` · `trimVideo` · `slideshow` · `takeScreenshot` · `setVolumeMedia` · `moveMedia` · `bookmark` · `musicAndVideo`

- 카메라는 **카메라 권한**이 새로 필요 → 사용자 승인 필수.
- 이미지/비디오 편집은 CoreImage/AVFoundation. 실패 시 원본 보존.
- `videoDownloader`는 **영구 제외 권장**(서비스 약관·법적 문제, 네트워크 의존).
- `news`·`stocks`·`radio`·`tuneStation`은 공개 API가 없어 URL scheme 수준만 가능.

### 4-3. T-221 콘텐츠·위치·웹 (3d)

`message` · `email` · `map` · `transportation` · `webContent` · `presentation` · `webIntegration` · `documentsAndFiles` · `devicesAndSheet` · `createShortcutIcon`

- 대부분 URL scheme/AppleScript. 대상 앱 미설치·미로그인 사유를 명시.
- `presentation`은 Keynote 연동(2차 문서 앱과 중복 확인).

### 4-4. T-222 App Intents·자동화 카탈로그 (4d + 스파이크)

`appIntent` · `appAction` · `findApp` · `automation` · `findAutomation` · `automationRun` · `trigger`

- App Intents는 런타임 발견 API가 제한적 → **스파이크 후 가능한 범위만**.
- `automation*`은 이미 있는 내부 모델을 카탈로그에 노출하는 작업이라 상대적으로 쉬움.

### 4-5. T-223 플랫폼 백로그 (2d)

- macOS 14 런타임 실기 검증(환경 대기)
- Developer ID 서명·공증(Apple Program 가입 대기)
- 사용자 변수 이름 토큰 `{name}` 지원
- `error_message_ko.json` 규칙 조율 결정

### 4-6. T-224 검증·릴리스 v1.8.0 (2d)

**3차 완료 기준**: 구현 약 93 → **약 115**, 영구 제외 항목을 문서에 명시.

---

## 5. 영구 제외 / 하지 않을 것 — **2026-11-09 확정**

| 항목 | 이유 |
|---|---|
| AI 3종 (`useModel`·`writingTool`·`imagePlayground`) | 2026-10-06 무효화. 제품 방향 밖 |
| `videoDownloader` | 서비스 약관·법적 위험, 네트워크 의존 |
| `airDrop`·`clearRecents`·`bluetooth` | 공개 API 없음. UI 자동화는 유지보수 비용이 큼 |
| 트랙패드 §8-14 및 P1(밝기·회전 다이얼 등) | 사용자가 2026-11-09 보류 결정 |
| 카탈로그 중복 항목 | 1차에서 정리. 별도 구현하지 않음 |

> 위 4종(`videoDownloader`·`airDrop`·`clearRecents`·`bluetooth`)은 **"다음 버전" 목록에서
> 제거하고 영구 제외로 표기**한다. 카탈로그에는 "지원하지 않음"으로만 남기거나 숨긴다.

---

## 6. 일정과 릴리스

| 단계 | 기간 | 릴리스 | 누적 구현 |
|---|---:|---|---:|
| 1차 | 9~10일 | **v1.6.0** (v0.33 포함) | 약 73 / 154 |
| 2차 | 16~18일 | **v1.7.0** | 약 93 / 154 |
| 3차 | 20일 | **v1.8.0** | 약 115 / 154 |

- 각 단계는 **독립 릴리스**로 끝낸다. 다음 단계 착수 전에 사용자 실기 확인을 받는다.
- 예상의 2배를 넘기면 중단하고 현재 상태·남은 일을 보고한다(`rules/workflow.md` §8).

---

## 7. 위험과 검증 전략

| 위험 | 대응 |
|---|---|
| AppleScript 앱별 TCC 프롬프트 | 앱별 1회 승인. CI는 권한이 없으므로 `XCTSkipUnless`+실측 probe |
| 파일 이동·삭제 사고 | 확인 대화상자 + 1회 실행 취소 + 임시 디렉터리 테스트 |
| Vision 정확도 | 고정 이미지 fixture로 결과 형식만 검증(정확도는 실기) |
| 사설 API 유혹 | 원칙적으로 금지. 필요하면 별도 승인 + 경계 가드 |
| 동결 예외 확산 | 3차 범위를 이 문서로 고정. 추가 요청은 다음 계획으로 |
| v0.33 미검증 상태 릴리스 | §8-14 완료 전 태그 금지 |

---

## 8. 결정 기록 (2026-11-09)

1. **범위: 1차만 승인.** 2차는 v1.6.0 결과·실기 확인 후 재승인. 3차는 그 다음.
2. **영구 제외 확정**: `videoDownloader`·`airDrop`·`clearRecents`·`bluetooth`.
3. v1.6.0에 v0.33 포함 — **§8-14 실기 확인 후 태그** 조건 유지.
4. `getDictionary`·`listActions`는 착수 전 0.5d 사양 확정(불명확하면 1차에서 제외하고 2차로 이동).

---

## 9. 3차 완료 기록 (2026-11-09)

**결과: 완료 — 구현 124 / 154** (계획 "약 115" 초과 달성)

| 작업 | 결과 | 커밋 |
|---|---|---|
| T-219 시스템 액션 | `network`(networksetup Wi-Fi 상태/켜기/끄기) · `focusMode`(사용자가 만든 Shortcuts 단축어 실행). 나머지 4종은 영구 제외 | `9f6fd1b` |
| T-220 미디어 편집·캡처 | `rotateImage` · `cropImage`(CoreImage, 원본 보존) · `trimVideo`(`avconvert`) · `camera`(AVFoundation + 카메라 권한) · `setVolumeMedia` · `moveMedia`(확인 후 이동) · `musicAndVideo`(AppleScript) | `9a782fd` |
| T-221 콘텐츠·위치·웹 | `message` · `email` · `map` · `transportation` · `webContent` · `webIntegration` · `presentation` · `createShortcutIcon`. `documentsAndFiles`·`devicesAndSheet`는 공개 경로 부재로 planned 유지 | `d1f796f` |
| T-222 App Intents·자동화 | `findApp` · `appIntent`(Shortcuts 경유) · `appAction`(URL scheme) · `automation` · `findAutomation` · `automationRun` · `trigger` | `c49b534` |
| T-223 플랫폼 백로그 | `{이름}` manual 변수 토큰 구현. macOS 14 실기·서명·`error_message_ko.json`은 대기 — `BACKLOG_v1.8_platform_macos.md` | `d3db1eb` |
| T-224 검증·릴리스 | `release-notes/v1.8.0.md`, `FUNCTIONAL_CHECKLIST.md` §8-17·§8-18, `STATUS.md`·`TODO.md` 갱신. **v1.8.0 범프·태그는 사용자 승인 대기** | — |

**계획 대비 변경**
- T-221은 10종 계획 → 공개 경로가 확인된 **8종 구현**, 2종(`documentsAndFiles`·`devicesAndSheet`)은 planned로 남겼다.
- T-220의 `slideshow`·`bookmark`는 공개 API 부재로 planned, `takeScreenshot`은 `screenshot`과 중복이라 숨김 유지.
- T-219의 Wi-Fi·집중 모드는 "트리거"가 아니라 **액션**으로 구현했다. 자동화 트리거 4종(Wi-Fi·블루투스·집중 모드·스테이지 매니저)은 감시자 미지원 상태를 유지한다.
- App Intent를 이름으로 직접 호출하는 공개 런타임 API가 없어 **Shortcuts 단축어 경유**로 구현하고 한계를 UI 힌트·릴리스 노트에 명시했다.

**검증**
- unit **848건 0실패**(2 skip) · i18n **ko/en 1610키 일치**
- 카탈로그: 전체 154 · 구현 124 · AI 스텁 3 · planned 27 (이 중 `takeScreenshot`·`clipText`·`videoDownloader`·`airDrop`·`clearRecents`·`bluetooth` 6종은 카탈로그 숨김)
- 사용자 실기 확인 대기: `FUNCTIONAL_CHECKLIST.md` §8-17(25항목)·§8-18(5항목)

**영구 제외 재확인**: `videoDownloader` · `airDrop` · `clearRecents` · `bluetooth` — 구현하지 않는다. AI 3종(`useModel`·`writingTool`·`imagePlayground`)은 2026-10-06 무효화 유지.

**릴리스 상태**: `MARKETING_VERSION` **1.8.0** 범프·버전 가드 통과. **`v1.8.0` 태그 생성(로컬)** — push 안 함.
