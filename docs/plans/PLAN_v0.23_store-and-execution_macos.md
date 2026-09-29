# PLAN_v0.23 — 저장 계층 안전 + 실행 엔진 백그라운드화 (macOS)

> status: **done** · 2026-09-29 · 착수 계기: `docs/plans/SESSION_2026-09-27_handoff.md` §3 2·3·4순위

## 착수 범위

인계 문서의 2·3·4순위를 한 번에 처리했다. 사용자 지정 순서는 3 → 4 → 2였고,
3·4가 2의 선행 조건이었다(저장 계층을 안전하게 만든 뒤 스레드 모델을 바꾸는 편이
합리적 — 2는 MainActor 경계가 많아 저장소 상태가 추가로 흔들리면 원인이 섞인다).

테스트 247 → **294건 0실패**(2 skip). 새 테스트 38건. 빌드 경고 0.

---

## T-167 — 스키마 버전 관리 도입

`ConfigSchemaV1`(`VersionedSchema`) + `ConfigMigrationPlan`(`SchemaMigrationPlan`) 추가,
`ConfigStore`가 `ConfigMigrationPlan.currentSchema`를 쓰도록 연결. stage는 비어 있다.

**마이그레이션 stage가 비어 있는 게 안전한 이유**: 무버전 store를 v1로 여는 경로를
그대로 허용해야 한다. stage를 미리 채우면 어떤 버전을 건너뛴 store가 생긴다.

**도입이 위험한 이유**: 무버전 store를 새 계획으로 못 열면 `ConfigStore.init()`의
컨테이너 생성 실패 → `quarantineStore` → **전 사용자 설정이 격리**된다.
`ConfigSchemaMigrationTests`가 이 경로(8건)를 고정한다.

**함정 2개 (모두 실수로 밟았다)**:
1. `Schema(ConfigMigrationPlan.schemas)`는 컴파일되지 않는다 — `Schema.init`은
   `[any PersistentModel.Type]`을 받는다
2. `Schema(models)`만 쓰면 `version`이 기본값 `1.0.0`으로 들어가, 버전을 명시하지
   않은 새 스키마가 과거와 구분되지 않는다

→ 둘을 `ConfigMigrationPlan.currentSchema` 한곳에 묶어 잘못된 생성 지점을 막았다.

---

## T-168 — 저장 blob의 키 누락 내성 (T-167이 놓친 진짜 원인)

인계 문서의 경고("필드 추가 = 데이터 소실")를 파고들었다. **원인은 두 개였고,
`VersionedSchema`는 그중 하나만 해결한다.**

blob(`stepsData`·`permissionsData`)은 불투명한 `Data`라 SwiftData 마이그레이션이
무관하다. 그리고 Swift의 합성 `Decodable`은 **프로퍼티 기본값을 무시한다** —
`var requiresConfirmation: Bool = false` 여도 JSON에 키가 없으면 `keyNotFound`.

→ `ShortcutStep`(19필드)·`ShortcutPermissions`(6)·`Variable`(7)에 관대
`init(from:)` 추가. 전 필드 `decodeIfPresent ?? 기본값`. 새 필드 추가는
컴파일 에러로 감지된다.

`StoreBlobToleranceTests`(9건)의 핵심은 **"키 하나씩 제거 → 여전히 디코딩" 스윕**이다.
필드가 늘어나면 스윕도 같이 늘어나므로 새 필드의 회귀를 사람이 기억할 필요 없이 잡는다.
관대 디코딩이 **진짜 손상까지 놓치면 안 된다**는 반대 방향 테스트도 함께 둔다.

**검증**: `requiresConfirmation`을 `decode`로 되돌리면 4개 테스트가 동시에 실패하고
`undecodableBlobColumns()`에 `["permissions"]` **영구 쓰기 잠금이 재현**된다.

---

## T-169 — `ConfigStore()` 인스턴스 테스트 23건

`init()`이 `storeURL`을 하드코딩해 인스턴스화가 불가능했고, 그 결과 모든 뮤테이션
경로가 검증되지 않았다.

`init`를 주입 가능하게 변경 — `storeDirectory`(테스트는 임시 경로),
`defaults`(전용 suite), `seedInstalledApps`, `registerSystemIntegrations`.
**기본값은 전부 기존 동작이라 앱 진입점은 그대로다.**
`UserDefaults.standard` 하드코딩 17곳을 주입된 `defaults`로 교체.

`HotKeyService.shared`는 싱글턴이라 오염시키면 다른 테스트가 깨진다(v0.21 실수).
`registerSystemIntegrations: false`로 시드·예약 핫키 등록을 끄고 `tearDown`에서
`unregisterAll()`.

---

## T-170 — 실행 엔진 백그라운드화

핫키 콜백이 메인 스레드에서 `executeWithDetail`을 동기 호출했다. `wait 60초` 단계면
UI가 60초 정지. `Process.waitUntilExit`·`pauseUntilInput`도 같았다.

`ExecutionEngine.executionQueue`(**직렬**) + `ConfigStore.runOffMainThread`.
실행만 백그라운드, MainActor 상태(통계·토스트·저장)는 메인에서만.

**왜 `.global`이 아니라 직렬인가**: 실행 횟수가 아니라 **상태가 하나뿐인 싱글턴**이 있다.
`pauseSemaphore`(사이보그 모드 대기 세마포어)와 `pauseMonitor`(NSEvent 모니터)가
각각 하나뿐이라 두 실행이 겹치면 나중에 시작한 쪽이 앞선 대기를 깨뜨린다.
메인 동기 실행이 공짜로 보장하던 직렬성을 직접 보존해야 한다.

`shortcutProvider`가 이제 오프메인에서 불리므로 `shortcuts` 접근을 메인으로 한 번 홉한다.
교착 없음 — 실행 큐가 직렬이고 메인이 실행 큐를 기다리지 않는다(메인을 막던 동기
실행을 이번 커밋에서 제거했으므로). 단계 테스트도 같은 큐로 통일.

`ExecutionBackgroundTests` 7건.

---

## 테스트 설계에서 배운 것 (이 세션의 진짜 산출물)

| 교훈 | 사례 |
|---|---|
| **무엇을 측정하는지뿐 아니라 언제 측정하는지**를 검증하라 | 하트비트 테스트가 실행이 **끝난 뒤** 틱을 세어 동기/비동기 모두 통과했다. 실행 구간 *안*을 봐야 한다 |
| 호출부 실행 시간 임계값은 신뢰도가 높다 | 1.5초 단계를 던지고 0.4초 내 반환 확인 → 실측 1.505초 |
| **단일 경로를 가리키는 테스트는 통과해도 무의미** | `setLaunchBinding` 회귀 테스트가 구버그에서 통과했다. 실제 조건은 "자기 바인딩을 겹치는 조합으로 교체" |
| `RunLoop.main.run` 수동 펌프는 XCTest에서 위험 | 단독 실행에선 됐지만 전체 스위트에서 루프 충돌. `await MainActor.run` 왕복 지연으로 대체 |
| 픽스처가 호스트에 의존하면 조용히 무의미해진다 | `/Applications/Notes.app`이 없어 두 앱이 모두 prune되어 실패 |

---

## DoD

- [x] `build macos` 경고 0
- [x] `test macos unit` **294건 0실패** (2 skip)
- [x] `test macos smoke` 69건 0실패
- [x] 현지화 게이트 · 버전 게이트 통과
- [x] **변환 테스트로 회귀 감지 실증** — 각 커밋마다 구버그 구현을 되돌려
      실패하는 테스트를 확인했다 (스키마 1건·blob 4건·바인딩 4건·실행 3건)

## 남는 것

- **사용자 실동작 확인 대기** — `wait 60초` 실행 중 메뉴바·패널이 살아있는지,
  사이보그 모드(⌘⇧↩)가 정상 해제되는지, 자동화 트리거가 잘 도는지는
  자동 검증이 불가하다. `docs/FUNCTIONAL_CHECKLIST.md` §8에 추가함
- Developer ID 서명+공증(T-166 후속) — Apple Developer Program 가입 선행
- `ConfigSchemaV1`은 **현재 `@Model` 정의의 복사본**이라, 모델이 갈라지면
  그대로 따라가지 않는다. 그 시점에 타입을 분리(`PersistedShortcutV1` 등)해야 한다
