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
| 테스트 | **381건 0실패** (2 skip, ~13초) | `./build_and_run.sh test macos unit` |
| 스모크 | 69건 0실패 | `test macos smoke` |
| 빌드 | 경고 0 | `xcodebuild` 전체 재컴파일 기준 |
| 액션 구현 | **55 / 162** (스텁 4, 미구현 103) | `ActionType.implementationCounts()` |
| i18n | ko/en **876키 일치** | `*.lproj/Localizable.strings` |
| 버전 | 1.3.0 (`project.yml`이 유일한 출처) | `scripts/check-version.py` |
| 미해결 작업 | **14건** | `TODO.md` |
| 미완료 항목 | **6개** (체크박스 57개) | `OPEN_ITEMS.md` |
| user 실동작 대기 | **52건** (8-1~8-8) | `FUNCTIONAL_CHECKLIST.md` §8 |
| 브랜치 | `fix/macos-audit-p0` — main보다 49커밋 앞 | — |
| 릴리스 | **없음** (PR 없음, 브랜치 push만 됨) | — |

---

## 3. 최근 완료분 (2026-09-27 ~ 29)

| 작업 | 결과 |
|---|---|
| **PLAN_v0.21** 5개 계층 정밀 감사 | 25건 수정 (P0 5·P1 11·정리 9) |
| **PLAN_v0.22** 무서명 릴리스 고지 정직화 | README·노트 템플릿·랜딩 4곳에 사실 명시 |
| **PLAN_v0.23** 저장 계층 안전 | 스키마 버전 관리(T-167) + **blob 키 누락 내성(T-168)** + `ConfigStore()` 테스트 23건(T-169) + **실행 엔진 백그라운드화(T-170)** |
| **PLAN_v0.24** 텍스트 액션 11종 | 카탈로그 "준비 중" → 실제 동작 |
| **T-172** 수치·날짜·목록 액션 12종 | 위와 동일 |

### 특히 중요한 발견 3가지

**1. `VersionedSchema`만으로는 데이터 소실을 막지 못한다.**
`stepsData`·`permissionsData`는 불투명한 `Data`라 SwiftData 마이그레이션이 무관하고,
Swift의 합성 `Decodable`은 **프로퍼티 기본값을 무시한다**(`= false`여도 키 없으면
`keyNotFound`). 필드 하나 추가 → 레코드 전체 디코딩 실패 → **영구 쓰기 잠금**.
T-168이 이걸 닫았다. (`PLAN_v0.23`)

**2. `FUNCTIONAL_CHECKLIST.md` §6이 이미 고친 항목을 미해결로 보여줬다.**
감사 스냅샷이라 시간이 지나면 낡아진다. 실제로 그랬다. **착수 전 현재 코드와 대조할 것.**

**3. 릴리스의 T-029 수정은 배포본에서 무효다.**
T-029는 "고정 TeamID → CDHash 유지 → 접근성 권한 유지"로 권한 초기화를 고쳤는데,
배포본이 `CODE_SIGNING_ALLOWED=NO`로 무서명이라 **사용자는 버전업마다 권한을 재승인한다.**
코드로는 해결 불가 — Program 가입이 선행이다.

---

## 4. 막혀 있는 것

| 항목 | 막힌 이유 | 해결 조건 |
|---|---|---|
| **Developer ID 서명 + notarization** | Apple Developer Program(연 $99) 가입이 선행 | 사용자 가입. 코드(`release.yml`)는 그 다음 |
| **`saveContext` → `Bool`** | **검증 수단이 없음.** chmod는 소유자에게 통하지 않고, SQLite 배타 락은 저장 실패가 아니라 **무한 대기**를 유발 | SwiftData 저장 실패를 결정적으로 재현하는 수단 (예: 읽기 전용 볼륨 위의 store) |
| **AI 3종 FoundationModels 연동** | macOS 26 / Apple Intelligence 가용성, API 리서치 필요 | 리서치 후 착수. 현재는 **정직한 실패**로 동작 중 |
| **미구현 액션 103종** | 대부분 Apple 앱 연동 (`Photos`·`Music`·`Mail`·`Calendar`·`Reminders`·`Podcasts`) | 앱별 API 조사 필요. ScriptingBridge 또는 URL scheme |
| **macOS 14 실기 검증** | 이 세션은 macOS 26에서만 실행 | macOS 14 기기 또는 가상머신 |
| **`error_message_ko.json`** | `rules/quality.md`가 요구하지만 파일이 없고, 현재 `error.user.*`가 en까지 포함해 기능적으로 우월 | `~/.config/opencode/rules/`는 **프로젝트 밖**이라 사용자 지시 없이 건드리지 않음 |

---

## 5. 아직 안 한 것 (착수 시 주의)

**단일 출처는 [`OPEN_ITEMS.md`](OPEN_ITEMS.md)** — 6개 항목이 완료 기준과 함께
체크박스로 남아 있다. 여기서는 요약만 적는다.

| 항목 | 왜 안 했나 |
|---|---|
| **사용자 실동작 검증 52건** | 에이전트가 대신할 수 없음 (스레드·핫키·권한·UI). `FUNCTIONAL_CHECKLIST.md` §8. **8-7(8건)이 특히 위험** — 스레드 모델을 바꿨다 |
| **PR 생성 / main 병합** | 브랜치는 push됐지만 PR 없음. v0.4~v0.25가 한 번에 들어가 리뷰 범위가 크다 |
| **macOS 14 런타임 실기 검증** | 이 작업은 macOS 26에서만 수행됐다 |
| **`error_message_ko.json`** | `rules/quality.md`가 요구하지만 파일이 없고, 현재 `error.user.*`가 en까지 포함해 기능적으로 우월. `~/.config/opencode/rules/`는 **프로젝트 밖**이라 사용자 지시 없이 건드리지 않음 |
| **`docs/plans/` 27개 정리** | **하지 않기로 판단.** 각 파일에 `status`가 있어 색인만 있으면 된다. 삭제·이동하면 이력 맥락이 사라진다 |
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
| **`RunLoop.main.run` 수동 펌프는 XCTest에서 위험** | 전체 스위트에서 테스트 루프와 충돌 |
| **회귀 테스트는 "언제 측정하는지"를 검증해야 한다** | 실행이 끝난 뒤에 재면 동기/비동기 모두 통과한다 |

---

## 7. 다음 세션이 할 수 있는 것

**바로 착수 가능** (위험 낮음):
- 저장 debounce
- blob 손상 컬럼 영구 쓰기 잠금 해제 경로
- Run Shortcut ↔ 자동화 UI 연결
- T-132 / T-135 / L-09 문서 정리

**착수 가능하나 규모 있음**:
- T-036 (메뉴 명령 단계 + 선택 UI)
- 미구현 액션 103종의 Apple 앱 연동 (앱별 조사 선행)

**착수 불가**:
- 서명 (Program 가입 대기)
- `saveContext → Bool` (검증 수단 대기)
- AI 3종 (리서치 대기)
