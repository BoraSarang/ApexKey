# 세션 인계 — 2026-09-27 (PLAN_v0.21 완료)

> 새 세션이 이 파일만 읽으면 바로 이어 갈 수 있다. 읽는 순서:
> `docs/plans/ACTION_AUDIT_v3_macos.md`(현실) → `docs/plans/PLAN_v0.21_audit-fix_macos.md`(완료분) → 아래

---

## 1. 현재 상태

| 항목 | 값 |
|---|---|
| 브랜치 | `fix/macos-audit-p0` (main보다 **37커밋 앞**) |
| 마지막 커밋 | `863cbbc docs(macos): v0.21 마무리` |
| 미커밋 | **없음** (작업 트리 clean) |
| 테스트 | `unit` **247건 0실패** (2 skip, 2.4초) / `smoke` 69건 0실패 (6초) |
| 빌드 | 경고 0 (`appintentsmetadataprocessor` metadata 1건 제외) |
| 게이트 | `check-localizable.py` 통과 · `check-version.py` 통과 (1.3.0) |
| i18n | ko 802키 / en 802키 **완전 일치** |
| 버전 | 1.3.0 (`project.yml` `MARKETING_VERSION`) |
| 이번 세션 | 감사 5개 계층 → **25건 수정** → 커밋 17개 |

**PR 없음.** `git push -u origin fix/macos-audit-p0` 후 PR 생성이 필요하면 base는 `feat/macos-p0-critical-fixes`(기존 PR #6)가 자연스럽고, `main`에 바로 여는 경우 v0.4~v0.20이 한 번에 들어간다.

---

## 2. 이미 끝난 것 (다시 하지 말 것)

PLAN_v0.21의 T-141~T-165가 **전부 `[x]`**다. 요약:

- **P0 5건** — 파이프 교착(앱 영구 정지) · `String(Int(inf))` 크래시 · AI 3종 거짓 성공+공개 광고 · 핫키 무음 소실 · 릴리스 태그-버전 대조 실패
- **P1 11건** — 셸 인젝션 · 반복 실패 전파 · 에러 메시지 보존 · 스크립트 출력 · `setOutput` 누락 · 고아 핫키 · `showHiddenApps` · 테마 키 이중 정의 · FSEvent use-after-free · osascript 분류 · 단일 세그먼트 메뉴
- **C-01 카탈로그 정합** — `ActionType` 153종 중 구현 28종. 미구현 125종은 "준비 중"/"연동 미구현" 배지 + 선택 차단
- **정리 9건** — 죽은 코드 6종·자산 2건·문서 정정

상세는 `docs/CHANGELOG.md` 2026-09-27 항목.

---

## 3. 다음에 할 것 (우선순위 순)

### 🥇 1순위 — 무서명 릴리스 (사용자 결정 필요)

**지금 상태**: `release.yml`이 `CODE_SIGNING_ALLOWED=NO`로 빌드한다. 릴리스 노트 템플릿에도
"공증되지 않은 앱이라 Gatekeeper가 첫 실행을 차단합니다"라고 적혀 있다.

**왜 최우선**: T-029의 핵심 수정은 "고정 TeamID 서명 → CDHash 유지 → 접근성 권한 유지"인데,
**배포본이 무서명이면 이 수정이 아무 효과가 없다.** 사용자가 버전업할 때마다
손쉬운 사용 권한을 다시 승인해야 한다. 개발 중에는 CI가 서명 경로를 아예 검증하지 않아
눈에 안 보였다.

**선택지**
- (a) Apple Developer Program($99/년) + Developer ID 서명 + notarization → 최선
- (b) 당장은 릴리스 노트 문구를 정직하게 유지하고 무서명 사실을 명시 → 최소
- **(c) 서명 없이 진행하되, 이 사실을 README/랜딩에 명시** ← 지금 바로 가능한 것

→ **사용자에게 (a) 여부를 확인하고 결정받은 뒤 착수.** 코드만으로 해결 못 함.

### 🥈 2순위 — 실행 엔진 백그라운드화

**왜**: 핫키 실행 경로가 메인 스레드에서 동기 실행된다. `wait 60초` 액션 하나면
UI가 60초 정지하고, `pauseUntilInput`·`Process.waitUntilExit`도 같다.
v0.20에서 추가한 로그(`E-MAC-ACT-3006` "호출부 백그라운드화는 후속 과제")가 남아 있던 항목.

**주의**: 스레드 모델 변경이라 회귀 위험이 가장 높은 작업. 핫키/자동화 콜백 →
`DispatchQueue.global` → 완료 시 `MainActor`로 토스트. `AutomationManager.onTriggerFired`가
이미 `DispatchQueue.main.async`로 홉하므로 그 지점을 따르면 된다.

**DoD**: `wait 60초` 액션 실행 중 메뉴바/패널이 살아있음을 **사용자가 실동작 확인**.

### 🥉 3순위 — `VersionedSchema` 도입

**왜**: `rg 'VersionedSchema|SchemaMigrationPlan'` → 0건. `ConfigSchema`를 하드코딩하고 있다.
`ShortcutPermissions`에 기본값 없는 필드가 추가되면 JSONDecoder가 전 레코드에 실패 →
v0.16의 `corruptedShortcutBlobColumns`가 4컬럼 전부 **영구 쓰기 잠금**이 되고,
복구 경로는 `removeShortcut` 뿐이다. 즉 **모델 필드 추가 = 사용자 데이터 소실 위험**.

**주의**: 데이터 이관이라 별도 커밋. 먼저 현재 스키마를 `VersionedSchema`로 래핑만 하고
마이그레이션은 비워 두는 게 안전.

### 4순위 — 저장 계층 테스트 보강

`ConfigStore()`를 인스턴스화하는 테스트가 **0건**이다. 모든 뮤테이션 경로
(바인딩 추가/교체/삭제, 앱 제거 시 고아 핫키, 워크플로우 저장)가 검증되지 않는다.
`init()`이 `storeURL`을 하드코딩하므로 컨테이너 경로를 주입 가능하게 바꾸면 시작된다.

---

## 4. 절대 함정 (모르면 또 밟는다)

| 함정 | 설명 |
|---|---|
| **`Info.plist`를 직접 수정하지 말 것** | project.yml `MARKETING_VERSION`이 유일한 출처. 직접 쓰면 xcodegen이 다음 빌드에서 덮어쓴다 — 이 사고로 1.3.0이 1.0으로 되돌아가 릴리스가 막혔다. `scripts/check-version.py`가 잡아준다 |
| **bash 3.2 빈 배열** | `set -u` 상태에서 `"${ARR[@]}"` 전개 시 `unbound variable`. `${ARR[@]+"${ARR[@]}"}` 사용 |
| **`ActionType`에 case 추가** | `ActionType+Implementation.swift`의 전수 switch가 **컴파일 에러**를 낸다. 의도된 동작 — `.implemented`로 분류하면 실제 `case` 분기를 `ExecutionEngine.executeStep` 또는 `ActionExecutor.executeWithDetail`에 추가해야 빌드가 통과한다 |
| **테스트에서 `HotKeyService.shared` 쓰기** | 싱글턴을 오염시켜 다른 테스트를 깨뜨린다. F12 계열로 쓰고 `defer`로 해제할 것 (v0.21에서 실수 1건 수정함) |
| **osascript 없는 프로세스는 5.5초** | 데드라인 5초면 `-1728` 진단이 "시간 초과"로 덮인다. `MenuEnumerator.osaScriptTimeout`(10초)을 낮추지 말 것 |
| **i18n 키 추출 규칙** | `check-localizable.py`는 **한글 리터럴만** 본다. 키 존재 검사는 없다 — `NSLocalizedString`이 키를 그대로 반환하므로 없는 키는 UI에 원문으로 노출되고 게이트를 통과한다 |
| **스크립트 한 번성 도구 삭제됨** | `scripts/`에 남은 것은 `check-localizable.py`·`check-version.py`·`update-verify-checklist.py`·`extract_strings.py`뿐. 나머지 i18n 일회용 도구는 지웠다 |

---

## 5. 사용자 실동작 확인 대기 (에이전트 대체 불가)

`docs/FUNCTIONAL_CHECKLIST.md` §8에 30항목. 특히 이번 변경과 직결된 것만:

- [ ] 핫키 저장 시 **"준비 중"인 조합 선택 → 거부 사유 표시**되는지 (기존엔 "적용됨"으로 거짓 표시)
- [ ] 외장드라이브에 있던 앱이 **제거될 때 핫키도 함께 사라지는지**
- [ ] 숨김 앱 표시 토글 → **재시작 후에도 유지되는지**
- [ ] 스크립트 출력 64KiB 초과(`yes | head -c 200000`) → **앱이 정지하지 않는지**
- [ ] 커스텀 테마를 활성 상태로 **삭제 → 재시작 → 테마 선택이 유지되는지**
- [ ] 자동화 카드/사이드바 배지 수가 **실제 등록 수와 일치하는지**
- [ ] 카탈로그에 **"준비 중" 배지**가 붙고 선택이 막히는지
- [ ] `wait 60초` 단계 실행 중 **UI가 정지하는지** (2순위 착수 전 확인)
- [ ] 설정 창에서 **현재 버전이 1.3.0으로 표시되는지**

---

## 6. 규칙 문서 갱신 필요 (아직 안 함)

`rules/quality.md`는 사용자 메시지를 `error_message_ko.json`에 두라고 요구하지만
**그 파일이 존재하지 않는다.** 현재는 `Localizable.strings`의 `error.user.*` 5키가
en까지 포함해 있어 기능적으로 우월하다. 두 선택지:

- (a) `rules/quality.md`에 "ko/en 통합 strings를 쓴다"는 예외 조항 추가 ← **권장**
- (b) `error_message_ko.json` 신설 (en 분리가 필요해지지는 않지만 규칙 문자열은 맞음)

→ `~/.config/opencode/rules/`는 프로젝트 밖이라 이번 세션에서 건드리지 않았다.
사용자 지시 없이 수정하지 않는다.

---

## 7. 커밋 규칙

main 직접 push 금지. 이 브랜치 작업은 1관심사 17커밋으로 이미 분리돼 있으니
Squash하지 말고 **그대로 리뷰**하는 게 낫다(각 커밋에 회귀 테스트가 붙어 있다).
