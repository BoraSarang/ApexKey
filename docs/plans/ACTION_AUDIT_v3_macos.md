# ACTION 현실 매핑 v3 (macOS) — 카탈로그 153종 vs 구현 28종

> 생성: 2026-09-27 / supersedes: `ACTION_AUDIT_v1_macos.md`(P1~P4 예정 목록), `ACTION_VERIFY_v2_macos.md`(자동/수동 검증표)
> 근거: `ExecutionEngine.executeStep` + `ActionExecutor.executeWithDetail`의 `case` 분기를 소스에서 프로그램 추출
> 목적: **"이건 되나요?"라는 질문에 문서만 보고 답할 수 있게 한다.**

---

## 0. 한 줄 요약

`ActionType` **153종**이 카탈로그·`ActionMetadata`에 모두 노출되지만, 실제로 실행되는 것은 **28종(18%)**이다.
나머지 **125종(82%)**은 `ActionExecutor.executeWithDetail`의 `default:` 분기(`E-MAC-ACT-3005`)에 떨어져 **"미구현" 토스트와 함께 실패**한다.

**선택 시점에 이 사실이 어떤 형태로든 드러나지 않는다.** 단계 설정 창에는 빈 폼만 열린다.

---

## 1. 카탈로그 노출 대 구현 현실 (카테고리별)

| 카테고리 | 구현/전체 | 미구현 액션 |
|---|:-:|---|
| **essential** | 11/35 | `script`(→`runScriptInShell` 경유로 실행), `dialog`, `text`, `clipText`, `moveToFront`, `wakeDisplay`, `clearRecents`, `preventSleep`, `wallpaper`, `darkMode`, `focusMode`, `screenshot`, `pdf`, `network`, `bluetooth`, `timer`, `stopwatch`, `location`, `airDrop`, `newQuickNote`, `newNote`, `readTable`, `emailData`, `date` |
| **scripting** | **2/2** | — (완전) |
| **media** | 0/25 | `quickLook`, `photos`, `musicAndVideo`, `playMusic`, `playPodcast`, `tuneStation`, `radio`, `viewPhotos`, `album`, `randomPhoto`, `slideshow`, `getLastPhoto`, `camera`, `rotateImage`, `cropImage`, `trimVideo`, `takeScreenshot`, `saveOutput`, `setVolumeMedia`, `moveMedia`, `bookmark`, `podcasts`, `news`, `stocks`, `videoDownloader` |
| **documents** | 0/55 | `editDocument`, `translate`, `textEditShortcut`, `noteActions`, `createNote`, `setParagraphStyle`, `newDocument`, `viewDocument`, `mail`, `setMailBody`, `setMailRecipients`, `drive`, `oneDrive`, `box`, `getFiles`, `moveFiles`, `renameFiles`, `extractArchive`, `externalStorage`, `fileActions`, `getConfirmation`, `getAttachment`, `getDictionary`, `dateFormatter`, `listActions`, `adjustDate`, `formatNumber`, `math`, `hash`, `uuid`, `outputDifference`, `typeNumber`, `typeText`, `getClipboard`, `setClipboard`, `regex`, `typeDateTime`, `sort`, `changeCase`, `replaceText`, `combineText`, `matchText`, `splitText`, `trimWhitespace`, `surroundText`, `count`, `wordCount`, `calculate`, `base64Encode`, `htmlToMarkdown`, `measurement`, `scanQRCode`, `recognizeText`, `recognizeAnimal`, `detectLanguage` |
| **location** | 0/2 | `map`, `transportation` |
| **content** | 0/6 | `message`, `email`, `calendar`, `reminders`, `webContent`, `presentation` |
| **accessories** | 0/4 | `webIntegration`, `documentsAndFiles`, `devicesAndSheet`, `createShortcutIcon` |
| **flowControl** | **9/9** | — (완전) |
| **variables** | 2/5 | `variableDetail`, `clipboardAction`, `number` |
| **ai** | 3/3 ⚠️ | — **구현은 있으나 전부 스텁** (§3) |
| **appIntents** | 0/3 | `appIntent`, `appAction`, `findApp` |
| **automation** | 0/4 | `automation`, `findAutomation`, `automationRun`, `trigger` |

> `script` / `runScriptInShell`은 `case .script, .runScriptInShell:` 묶음으로 분기하므로 위 표에서 essential/flowControl 양쪽으로 세어진다. 유니크 구현 수는 **28종**.

---

## 2. 미구현 액션의 실제 사용자 경험

```
사용자가 카탈로그에서 "정규식" 선택
  → ActionCatalogView.actionRow → ShortcutEditorView.addStepOfType(.regex)
  → createDefaultStep의 default: → ShortcutStep(type: .regex, target: "", title: "정규식")
  → saveSteps() → 정상 저장 (사용자는 "추가됐다"고 belief)
  → 단계 클릭 → StepSettingsView.typeSpecificSection의 default: → DefaultSettingsView (제목/스킵/노트만)
  → 실행 → ExecutionEngine.executeStep의 default: → ActionExecutor.executeWithDetail의 default:
  → Logger.error("E-MAC-ACT-3005", "미구현 액션 타입: regex")
  → 토스트 "미구현" (실행 시점에야 드러남)
```

**문제 3가지**
1. **선택 시점에 경고 없음** — 카탈로그가 미구현/구현을 구분하지 않음
2. **단계 설정 창이 정상 откры힘** — 빈 폼이라 "설정 중"으로 오인
3. **저장 자체는 성공** — 미구현 단계가 워크플로우에 정상적으로 누적

---

## 3. AI 3종 — "구현"이지만 실제로는 스텁 (성공 둔갑)

`ActionCategory.ai`는 3/3 구현으로 분류되나, 3개 모두 FoundationModels를 호출하지 않는다.

| 액션 | 실제 동작 | 근거 |
|---|---|---|
| `useModel` | **입력 프롬프트를 그대로 출력 변수로 저장**하고 `return true` | `UseModelExecutor.swift:139-147` (`// TODO: FoundationModels 프레임워크 실제 연동`) |
| `writingTool` | `proofread`/`rewrite`는 문자열 래핑(`"[Proofread] %@"`). `summarize`/`keyPoints`는 앞 3~5문장 절단 | `WritingToolExecutor.swift:56-68` (`processLocally`) |
| `imagePlayground` | 512×512 단색 사각형에 프롬프트 글자를 그린 **플레이스홀더 이미지** 생성 | `ImagePlaygroundExecutor.swift:48-76` (`createPlaceholderImage`) |

**추가로**: `AIAvailabilityManager.checkAvailability_macOS26()`는 `canImportFoundationModels` 확인 후 **무조건 `.available` 반환**(`.appleIntelligenceDisabled` / `.unknown` 케이스는 선언만 있고 생성자 없음). Apple Intelligence가 꺼진 기기에서도 "사용 가능" → 스텁 실행 → 성공.

**결과**: macOS 26 미만은 정직하게 실패(`E-MAC-AI-9002/9012/9022`), **macOS 26 이상만 거짓 성공**한다.

**공개 광고 상태** (중요):
- `website/ko/index.html:179` — "AI 액션 — 모델 사용, 라이팅 툴, 이미지 생성 — 모두 핫키 하나에 바인딩할 수 있습니다."
- `README.ko.md:38` / `README.md` — "| AI 실행 | 모델 사용, 라이팅 툴, 이미지 생성 단계 |"

→ **PLAN_v0.21 D-02에서 처리** (스텁이므로 실패 반환 + 카탈로그/README/웹 문구 정정).

---

## 4. 자동화 트리거 — 12종 중 4종만

`AutomationModels.swift:104-109`:
```swift
var isWatcherSupported: Bool {
    switch self {
    case .timeOfDay, .folder, .battery, .charger: return true
    default: return false
    }
}
```

| 상태 | 트리거 |
|---|---|
| ✅ 동작 | `timeOfDay`, `folder`, `battery`, `charger` |
| ❌ 등록 거부 (`E-MAC-AUTO-8001`) | `file`, `externalDrive`, `display`, `wifi`, `bluetooth`, `app`, `focus`, `stageManager` |

**README 과대 광고**: `README.ko.md:37` "시간·폴더·**디스플레이·Wi-Fi·블루투스**·배터리·충전기·**앱** 조건 기반 트리거" — 광고한 8종 중 4종이 비작동.

**추가 결함**: `ConfigStore+Automation.swift:9-11`의 `automationTriggerCount`는 `automations.count`를 세지만 `register`는 8종을 거부 → **사이드바 배지 N / 실제 등록 0** 불일치.

**인접 죽은 코드**: `AutomationTrigger.runsInBackground`(`AutomationModels.swift:112-117`)는 12종 **전부 `true`**를 반환 — 판정 로직 없음.

---

## 5. 선언되었으나 구조적으로 실행 불가한 항목 (v1에서 [x]로 기재됨)

| TODO 항목 | 문서 주장 | 실제 코드 | 판정 |
|---|---|---|---|
| **T-036** | "동작의 메뉴 명령 단계 — 앱 피커 + 메뉴 트리에서 실행 항목 선택" | `menuCommandPicker` **소스 0건**. `MenuChoiceNode`(`ShortcutStationView.swift:377`)는 자기 자신 재귀만 참조하는 **dead code**. `ShortcutEditorView.swift:357`는 여전히 `target: ""`로 생성 | **거짓 [x]**. `menuCommand` 단계는 `target:""` → `performAction(in: "")` → 구조적 실패. TODO.md:280이 같은 작업을 `[ ]`로도 기록 중 |
| **T-135** | "`BuiltInShortcutPresets`(Android 2개) 코드 고정 + `ensureBuiltInShortcuts`가 이름 기준 자동 보충" | `BuiltInShortcutPresets.all = []`(`ConfigStore.swift:429`, "호환용 스텁" 주석). `ensureBuiltInShortcuts()`는 `removeLegacyAndroidShortcutsIfNeeded()` **호출뿐** | **거짓 [x]**. v0.8 S-05가 삭제 방향으로 뒤집었으나 `[x]` 잔존 |
| **T-132** | "`ADB Wi-Fi 연결` 샘플 동작 자동 제공 — 기존 사용자도 1회 생성" | `ensureADBWifiSample()`(`ConfigStore.swift:301-304`) → `removeLegacyAndroidShortcutsIfNeeded()` **삭제만** | **거짓 [x]**. "생성"이 아니라 "정리" |
| **T-033-2** / `MenuEnumerator.swift:244` | "실행 `child(named:)`가 빈 AXMenu를 자동 파고들어 호환된다" | `child(named:)` **함수 부재** (CHANGELOG:372 "죽은 코드 정리"). 주석만 잔존 | **죽은 주석**. 검증 불변이 코드에서 사라져 T-033이 보장했던 경로 규칙이 §6 대칭성 깨짐의 원인 |
| **U-17** | "`@objc undo/redo` keyWindow.undoManager 위임 연결" | `AppDelegate.undo/redo`(`:161-171`)는 존재하나 `AppDelegate+Menus.swift:53-54`는 `Selector("undo:")` 문자열 + responder chain으로 등록. **`#selector` 연결 코드 0건** | **과장 기술**. 메서드는 있으나 이 경로로는 불필요(responder chain이 처리). `E-MAC-UI-9108` 코드 부재 |
| **L-09** | "코드 참조 키 526 전수 존재" 검증 | `check-localizable.py`에 **키 존재 검사 로직 0건**(한글 리터럴 검사만). 실제 키 수는 801 | **검증 주장이 거짓**. 게이트가 하는 일과 문서가 말하는 일이 다름 |
| **R-04** | "`androidMirrorScriptPath` 하드코 절대경로 → Application Support 시드 폴백" | 폴백은 추가됐으나 `SystemActionExecutor.swift:70-71`에 `/Users/lee/Documents/AGENTS/...`가 여전히 **preferred(우선)** | **절반만**. 세션 로그의 "절대경로 금지" 규칙 위반 |

---

## 6. 메뉴 실행 경로의 구조적 실패 (테스트가 버그를 가로막고 있음)

`MenuEnumerator.performAction`의 스크립트 조립(`:151-161`):
```swift
script += "    click menu item \(appleScriptQuoted(path[path.count - 1]))"
if path.count > 1 { for seg in path[1..<(path.count - 1)].reversed() { ... } }
script += " of menu 1 of menu bar item \(appleScriptQuoted(path[0])) of menu bar 1\n"
```

`path.count == 1`이면 `path[path.count-1]` == `path[0]`이므로:
```
click menu item "X" of menu 1 of menu bar item "X" of menu bar 1
```
→ **구조적으로 불가능** (같은 이름이 동시에 부모·자식). 실측 `-1728`, 100% 실패.

**도달 경로 (모두 실재)**
- `MenuEnumerator.swift:130` — `if path.isEmpty { path = [item.title] }`
- `ActionExecutor.swift:79` — 레거시 바인딩은 `menuPath`가 비어 있어 **항상** 이 fallback에 걸림
- `AppDetailView.swift:52, 491` — UI가 `[title]`로 직접 기록

**가장 나쁜 점**: `ApexKeyStoreTests.swift:99-103`(`testMenuItemPathDefaultsToTitle`)이 이 fallback을 **의도된 호환 동작으로 green 고정**해 두었다. 테스트는 통과하지만 끝까지 실패하는 경로를 지킨다.

---

## 7. 판정

| # | 결론 |
|---|---|
| 1 | **리서치 선별은 성공** — 이식 가치가 있는 24종을 골라 실제로 전부 구현했다. `scripting`(2/2)·`flowControl`(9/9)은 완전, `essential` 11종·`variables` 2종은 완전 작동 |
| 2 | **치지 못한 것은 "선별"이 아니라 "표시 계층"** — 125종이 카탈로그에 구현과 구분 없이 노출된다 |
| 3 | **AI 3종은 구현이 아니라 스텁 + 거짓 성공 + 공개 광고** — 최우선 처리 대상 |
| 4 | **자동화 트리거 4/12** — README 광고 8종 중 4종 비작동 |
| 5 | **TODO `[x]` 6건이 실제 코드와 불일치** — 문서 신뢰도 문제의 직접 원인 |

---

## 8. 조치 (PLAN_v0.21 참조)

| ID | 조치 | 규모 |
|---|---|---|
| **D-01** | 미구현 125종을 카탈로그에서 숨기고 "준비 중" 배지 + `ActionType` ↔ 핸들러 **컴파일 타임 정합성 검사** 도입 | M |
| **D-02** | AI 3종 스텁 → 실패 반환. 카탈로그/README/웹 문구 정정 | S |
| **D-03** | 자동화 트리거 8종을 카탈로그에서 숨기고 `automationTriggerCount`를 실제 등록 수로 변경. README 정정 | S |
| **D-04** | `menuPath` count==1 처리 + `ApexKeyStoreTests:99-103` 갱신 | S |
| **D-05** | 미구현 문서 항목[T-036/T-132/T-135/U-17/L-09/R-04] `[x]` 정정 및 superseded 표기 | S |

> **비추천**: 125종 추가 구현. D-01로 표면을 정합하게 만든 뒤, 우선순위는 §9 참고.
