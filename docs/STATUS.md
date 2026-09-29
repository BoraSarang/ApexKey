# ApexKey — 현황 (STATUS)

> 최종 갱신: **2026-09-29**
> 이 문서가 "지금 어디까지 왔고, 무엇이 막혔고, 무엇을 안 했는지"의 단일 출처다.
> 작업 목록은 [`TODO.md`](TODO.md), 문서 색인은 [`README.md`](README.md).

---

## 1. 한 줄 요약

macOS 메뉴바 핫키 런처. **기능·저장 안전성·테스트는 healthy**하지만
**배포 서명이 없어 릴리스 사용자가 버전업마다 권한을 재승인해야 하고**,
카탈로그 162종 중 103종은 아직 "준비 중"이다.

---

## 2. 수치

| 지표 | 값 | 출처 |
|---|---|---|
| 테스트 | **451건 0실패** (2 skip, ~23초) | `./build_and_run.sh test macos unit` |
| 스모크 | 69건 0실패 | `test macos smoke` |
| 빌드 | **클린 빌드 경고 0** | `xcodebuild clean build` — 점진 빌드는 경고를 숨긴다. T-183으로 13건 제거 |
| 액션 구현 | **59 / 162** (스텁 4, 미구현 100) | `ActionType.implementationCounts()` |
| i18n | ko/en **891키 일치** | `*.lproj/Localizable.strings` |
| 버전 | 1.3.0 (`project.yml`이 유일한 출처) | `scripts/check-version.py` |
| 미해결 작업 | **7건** (+ 무효화 5건) | `TODO.md` |
| 미완료 항목 | **6개** (체크박스 57개) | `OPEN_ITEMS.md` |
| user 실동작 대기 | **61건** (8-1~8-10) | `FUNCTIONAL_CHECKLIST.md` §8 |
| 브랜치 | `fix/macos-audit-p0` — **main에 병합됨**(PR #7, `3664d99`) | — |
| 릴리스 | **없음** — PR #7은 main에 병합됐지만 `release.yml`은 **태그 트리거**라 배포 없음 | — |

---

## 3. 최근 완료분 (2026-09-27 ~ 29)

| 작업 | 결과 |
|---|---|
| **PLAN_v0.21** 5개 계층 정밀 감사 | 25건 수정 (P0 5·P1 11·정리 9) |
| **PLAN_v0.22** 무서명 릴리스 고지 정직화 | README·노트 템플릿·랜딩 4곳에 사실 명시 |
| **PLAN_v0.23** 저장 계층 안전 | 스키마 버전 관리(T-167) + **blob 키 누락 내성(T-168)** + `ConfigStore()` 테스트 23건(T-169) + **실행 엔진 백그라운드화(T-170)** |
| **PLAN_v0.24** 텍스트 액션 11종 | 카탈로그 "준비 중" → 실제 동작 |
| **T-172** 수치·날짜·목록 액션 12종 | 위와 동일 |

### 특히 중요한 발견

**1. ★ `JSONEncoder`의 키 순서는 프로세스마다 다르다 (E-MAC-STORE-5012).**
`outputFormatting`을 지정하지 않으면 내부 딕셔너리를 거치는데, **Swift의 `Hasher`
시드는 프로세스마다 무작위**라 같은 값도 프로세스를 넘기면 바이트가 달라진다.
(실측: `ShortcutPermissions`를 두 번 인코딩해 165바이트로 길이는 같은데 내용이 달랐다)

`StoreCoding`을 `.sortedKeys`로 고정했다. 이게 안 고쳐졌으면 T-175의 복구 가드가
**간헐적으로 열려 사용자 원본 데이터를 조용히 덮어썼을 것**이다. 원래부터 있던
잠재 결함이 비교가 필요한 코드가 생기면서 드러났다.
`StoreBlobRecoveryTests`가 고립 실행에서는 통과하고 전체 스위트에서만 실패했다 —
**비결정적 결함의 전형적 징후이니 같은 증상이 보이면 원인을 재현 데이터로 좁힐 것.**

**2. `VersionedSchema`만으로는 데이터 소실을 막지 못한다.**
`stepsData`·`permissionsData`는 불투명한 `Data`라 SwiftData 마이그레이션이 무관하고,
Swift의 합성 `Decodable`은 **프로퍼티 기본값을 무시한다**(`= false`여도 키 없으면
`keyNotFound`). 필드 하나 추가 → 레코드 전체 디코딩 실패 → **영구 쓰기 잠금**.
T-168이 이걸 닫았다. (`PLAN_v0.23`)

**3. 왕복 검증만으로는 "값이 안 바뀌었는지"를 알 수 없다 (E-MAC-STORE-5010).**
fallback인 `[]`도 인코딩 후 디코딩하면 그대로 `[]`이 돌아온다. 즉 원본 보호를
목적으로 한 가드가 **자기 목적을 무력화**한다. 값의 **출처**를 추적해야 한다.

**4. `FUNCTIONAL_CHECKLIST.md` §6이 이미 고친 항목을 미해결로 보여줬다.**
감사 스냅샷이라 시간이 지나면 낡아진다. 실제로 그랬다. **착수 전 현재 코드와 대조할 것.**

**5. 릴리스의 T-029 수정은 배포본에서 무효다.**
T-029는 "고정 TeamID → CDHash 유지 → 접근성 권한 유지"로 권한 초기화를 고쳤는데,
배포본이 `CODE_SIGNING_ALLOWED=NO`로 무서명이라 **사용자는 버전업마다 권한을 재승인한다.**
코드로는 해결 불가 — Program 가입이 선행이다.

**6. 로컬 테스트 통과가 CI 통과를 보장하지 않는다 (T-184).**
PR #7의 첫 CI에서 `MenuActionPathTests.testMissingMenuItemProduces1728` 1건이
실패했다. 로컬에서는 항상 통과한다. **GitHub Actions 러너에는 접근성 권한이 없어**
없는 메뉴 항목이 -1728이 아니라 권한 오류로 실패한다 — 즉 그 테스트는
**분류 로직이 아니라 러너의 권한 상태를 측정**하고 있었다.
`AXIsProcessTrusted()` 대신 **실측 probe**로 "이 호스트에서 해볼 수 있는가"를
먼저 확인하고, 없으면 `XCTSkip`으로 사유를 남기도록 고쳤다.
> 같은 실패 모드: `/Applications/Notes.app`이 없는 기기에서 픽스처가 prune된다.

**7. "빌드 경고 0"은 과장이었다 — T-183으로 해결.**
클린 빌드에 **경고 13건(7종)**이 있었다. 캐시된 빌드는 재컴파일 때만 경고를
보여주므로 점진 빌드로 확인하면 0처럼 보인다. **이제 클린 빌드 경고 0이다.**
다시 같은 착각을 하지 않으려면 `xcodebuild clean build`로만 확인할 것.

---

## 4. 막혀 있는 것

| 항목 | 막힌 이유 | 해결 조건 |
|---|---|---|
| **Developer ID 서명 + notarization** | Apple Developer Program(연 $99) 가입이 선행 | 사용자 가입. 코드(`release.yml`)는 그 다음 |
| **`saveContext` → `Bool`** | **검증 수단이 없음.** chmod는 소유자에게 통하지 않고, SQLite 배타 락은 저장 실패가 아니라 **무한 대기**를 유발 | SwiftData 저장 실패를 결정적으로 재현하는 수단 (예: 읽기 전용 볼륨 위의 store) |
| **AI 3종 FoundationModels 연동** | macOS 26 / Apple Intelligence 가용성, API 리서치 필요 | 리서치 후 착수. 현재는 **정직한 실패**로 동작 중 |
| **미구현 액션 100종** | 대부분 Apple 앱 연동 (`Photos`·`Music`·`Mail`·`Calendar`·`Reminders`·`Podcasts`) | 앱별 API 조사 필요. ScriptingBridge 또는 URL scheme |
| **macOS 14 실기 검증** | 이 세션은 macOS 26에서만 실행 | macOS 14 기기 또는 가상머신 |
| **`error_message_ko.json`** | `rules/quality.md`가 요구하지만 파일이 없고, 현재 `error.user.*`가 en까지 포함해 기능적으로 우월 | `~/.config/opencode/rules/`는 **프로젝트 밖**이라 사용자 지시 없이 건드리지 않음 |

---

## 5. 아직 안 한 것 (착수 시 주의)

**단일 출처는 [`OPEN_ITEMS.md`](OPEN_ITEMS.md)** — 6개 항목이 완료 기준과 함께
체크박스로 남아 있다. 여기서는 요약만 적는다.

| 항목 | 왜 안 했나 |
|---|---|
| **사용자 실동작 검증 61건** | 에이전트가 대신할 수 없음 (스레드·핫키·권한·UI). `FUNCTIONAL_CHECKLIST.md` §8. **8-7·8-9·8-10(17건)이 특히 위험** — 스레드 모델을 바꿨다. 이번에 8-9(키 입력)·8-10(debounce)이 추가됐다 |
| **PR #7 병합 후 리뷰** | main에 병합은 됐으나 **커밋 단위 리뷰는 안 됐다.** 59커밋을 한 번에 올렸다 |
| **macOS 14 런타임 실기 검증** | 이 작업은 macOS 26에서만 수행됐다 |
| **`error_message_ko.json`** | `rules/quality.md`가 요구하지만 파일이 없고, 현재 `error.user.*`가 en까지 포함해 기능적으로 우월. `~/.config/opencode/rules/`는 **프로젝트 밖**이라 사용자 지시 없이 건드리지 않음 |
| **`docs/plans/` 28개 정리** | **하지 않기로 판단.** 각 파일에 `status`가 있어 색인만 있으면 된다. 삭제·이동하면 이력 맥락이 사라진다 |
| **`TODO.md` 427줄 재배치** | **하지 않기로 판단.** 요약 인덱스로 탐색 비용만 낮췄다. 재배치하면 "T-036이 왜 superseded됐는지" 같은 맥락이 사라진다 |
| **CI 서명 경로 검증** | 서명 도입의 일부. T-166 후속과 함께 |

---

## 6. 이 프로젝트를 계속할 때의 함정

실제로 밟은 것만 적는다. 추측은 넣지 않는다.

| 함정 | 설명 |
|---|---|
| **`Info.plist` 직접 수정 금지** | `project.yml`이 유일한 출처. 이 사고로 1.3.0이 1.0으로 되돌아가 릴리스가 막혔다 |
| **`check-localizable.py`는 키 존재를 검사하지 않는다** | 없는 키는 게이트를 통과하고 UI에 원문 키로 노출된다. **직접 확인해야 한다** |
| **캐시된 빌드는 경고를 보여주지 않는다** | 세션 로그의 "빌드 경고 0"이 과장이 될 수 있다. `xcodebuild` 전체 재컴파일로 확인 |
| **`xcodebuild`를 직접 쓰면 xcodegen이 안 돈다** | 새 파일이 프로젝트에 포함되지 않아 "타입을 찾을 수 없다"는 헷갈린 에러가 난다. `./build_and_run.sh`를 쓸 것 |
| **XCGen 프로젝트는 커밋에 포함되지 않는다** | `project.yml`을 고쳤으면 `xcodegen generate` 필요 |
| **테스트에서 `HotKeyService.shared` 쓰지 말 것** | 싱글턴 오염 → 다른 테스트 실패. F12 계열 + `defer` 해제 |
| **테스트 픽스처가 호스트에 의존하지 말 것** | `/Applications/Notes.app`이 없는 기기에서 두 앱이 모두 prune되어 실패했다 |
| **호스트 권한에 의존하는 단언은 CI에서 깨진다** | 접근성 권한이 없으면 osascript가 권한 오류를 낸다. **측정 가능 여부를 실측 probe로 먼저 확인**하고 없으면 `XCTSkip`으로 사유를 남긴다 (T-184) |
| **`XCTSkipUnless` 대신 `AXIsProcessTrusted()`를 쓰지 말 것** | osascript는 우리 프로세스와 **별개의 TCC 컨텍스트**에서 실행된다. 우리 프로세스의 권한과 일치하지 않는다 |
| **`RunLoop.main.run` 수동 펌프는 XCTest에서 위험** | 전체 스위트에서 테스트 루프와 충돌 |
| **회귀 테스트는 "언제 측정하는지"를 검증해야 한다** | 실행이 끝난 뒤에 재면 동기/비동기 모두 통과한다 |

---

## 7. 다음 세션이 할 수 있는 것

### 읽는 순서

1. `AGENTS.local.md` → 2. **이 문서** → 3. [`OPEN_ITEMS.md`](OPEN_ITEMS.md) →
4. [`TODO.md`](TODO.md) → 5. `docs/plans/`의 최신 PLAN

`docs/plans/SESSION_2026-09-27_handoff.md`는 **2026-09-27 스냅샷**이고 그 1·2·3·4순위는
모두 처리됐다. 읽지 말고 현재 상태는 이 문서를 본다.

### 착수 순서 제안

**1순위 — 위험이 낮고 완결된다**
- `detectLanguage`(휴리스틱) · `recognizeText`(Vision — 프레임워크 내장이라 조사 부담 낮음)
- Choose from Menu / Use Model 단계 설정값(actionParameters) UI 다듬기
- 단축키 프로필 / 빠른 전환

**2순위 — 규모 있음**
- T-036 (메뉴 명령 단계 실행 불가 + 앱/메뉴 선택 UI)
- 미구현 액션 100종의 Apple 앱 연동 — **앱별 API 조사 선행 필요**

**착수 불가 (조건 대기)**
- Developer ID 서명 — Apple Developer Program 가입 대기
- `saveContext → Bool` — 저장 실패를 결정적으로 재현할 수단이 없음
- AI 3종 FoundationModels — API 리서치 선행

### 이 세션에 처리 완료 (T-175~T-183)

blob 잠금 복구 경로 · 저장 debounce · `JSONEncoder` 키 순서 결정성 ·
키 입력·HTML 3종 · Run Shortcut 설정 UI · T-132/T-135/L-09 무효화 정리 ·
**클린 빌드 경고 13건 제거(경고 0)**

### 새 코드를 쓴 다음 세션이 반드시 지킬 것

- **`xcodebuild clean build`로 경고를 확인한다.** 점진 빌드는 재컴파일하지 않은
  파일의 경고를 숨겨서 0처럼 보인다. 이번에 제거한 13건 중 1건은 **그날 새로 쓴
  코드**였다
- **테스트가 고립 실행에서 통과하면 끝이 아니다.** 비결정적 결함은 전체 스위트에서만
  드러난다 (T-177)
- **실패를 빈 값·0·원문으로 뭉개지 않는다.** 조용한 실패는 조용할수록 오래 남는다
- **비교가 필요하면 인코딩이 결정적인지 먼저 확인한다** (`StoreCoding`만 쓸 것)
