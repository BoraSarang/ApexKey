---
id: PLAN_v0.21
title: v0.21 — 감사 결함 수정 (P0 데이터/정지 + 카탈로그 정합)
status: in_progress
platform: macos
priority: P0
budget: M
created: 2026-09-27
branches: fix/macos-audit-p0
---

# PLAN v0.21 — 감사 결함 수정 (macOS)

> M 경로: workflow + quality + platforms/macos. **문서 우선**: 본 PLAN → TODO T-141+ 등록 → 코드 → 빌드/테스트 게이트 → CHANGELOG → 세션 로그.
> 근거 문서: `docs/plans/ACTION_AUDIT_v3_macos.md` (현실 매핑), `docs/FUNCTIONAL_CHECKLIST.md` (갱신본)

---

## Scope

### Phase A — P0 (앱 정지 · 크래시 · 거짓 성공 · 데이터 소실)

| ID | 항목 | 근거 | 규모 |
|---|---|---|:-:|
| **A-01** | **파이프 교착 제거 (앱 영구 정지)** — `waitUntilExit()` 후 `readDataToEndOfFile()` 순서로 64KiB 초과 시 메인스레드 교착. 동시 드레인으로 전환 | `ActionExecutor.swift:225-227`, `:184-186`, `ScriptExecutor.swift:56-58`, `MenuEnumerator.swift:210` (4곳 동일 패턴) | S |
| **A-02** | **`String(Int(v))` 크래시 가드** — `inf`/`NaN`에서 `Double→Int` fatalError. `v.isFinite && v.magnitude <= Double(Int.max)` 가드 | `VariableResolver.swift:30` (실측 fatalError 재현 확인) | XS |
| **A-03** | **AI 3종 스텁 → 실패 반환** — FoundationModels 미연동 상태에서 `return true` 금지. `AIAvailabilityManager` 무조건 `.available` 제거 | `UseModelExecutor.swift:139-147`, `WritingToolExecutor.swift:63-68`, `ImagePlaygroundExecutor.swift:55-76`, `AIAvailabilityManager.swift:38-47` | S |
| **A-04** | **`setLaunchBinding` 파괴-후-검증 제거** — 삭제 **전** 중복 사전 검증. `addBinding`을 `Bool` 반환으로 | `ConfigStore+Bindings.swift:26-37, 48-53` | S |
| **A-05** | **셸 인젝션 방어** — `ShellEnvironment.quoted(_:)` 단일 인용 헬퍼 도입, `runShellScriptResult`에 적용 | `ExecutionEngine.swift:422-423` → `ActionExecutor.swift:211-214` (AppleScript 경로만 이스케이프 존재하는 비대칭) | S |
| **A-06** | **Info.plist 버전 단일 출처화** — `project.yml`에 `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION`을 두고 Info.plist의 `CFBundleShortVersionString` 하드코딩 제거. xcodegen이 plist를 덮어써 되돌아오던 구조 자체를 없앰 | `project.yml:47-49`(`info.properties`), `Sources/ApexKey/Info.plist:19-21`, `release.yml:41-45`(태그 대조 후 `exit 1`) | S |
| **A-07** | **테스트 격리** — 싱글턴을 오염시키던 테스트(`HotKeyService.shared`에 ⌘H 실제 등록·미해제) 제거 | `ApexKeyModelTests.swift:64-70` | XS |

### Phase B — P1 (오동작 · 무음 실패)

| ID | 항목 | 근거 | 규모 |
|---|---|---|:-:|
| **B-01** | **반복 내부 실패 전파** — `executeRepeatCount`/`executeRepeatEach`가 내부 `success:false`를 버리고 성공 반환 | `ExecutionEngine.swift:213-234`, `:269-290` | S |
| **B-02** | **에러 메시지 보존** — `execute(steps:)`가 `error` 문자열을 버림 → 토스트에 실제 원인 미노출 | `ExecutionEngine.swift:63, 79` | S |
| **B-03** | **스크립트 출력이 소스코드로 기록되는 결함** — `runShellScript`가 stdout을 버림. `runShellScriptResult`로 전환해 실제 출력 저장 | `ExecutionEngine.swift:423-424` | XS |
| **B-04** | **일반 액션 `setOutput` 누락** — `default:` 분기가 출력을 남기지 않아 `{lastResult}`가 과거 잔여값을 읽음 | `ExecutionEngine.swift:158-166` | S |
| **B-05** | **핫키 저장 실패 전달** — `onRecord`를 `Bool` 반환으로 변경해 스토어 거부/등록 실패를 "적용됨"이 아닌 실제 결과로 표시 | `HotKeyRecorderView.swift:20, 211-212` + 스토어 거부 5곳 | M |
| **B-06** | **`removeApp` 연관 바인딩 정리** — 앱 제거 시 해당 `target`의 바인딩 + 등록 핫키 해제. `pruneRemovedApps()`가 매 실행 호출하므로 **외장드라이브 뽑으면 고아 핫키가 매번 재등록**되는 문제 해결 | `ConfigStore+Apps.swift:59-67` + `ConfigStore.swift:292` | S |
| **B-07** | **`showHiddenApps` 영속화** — `didSet` + `PrefKeys` + `init()` 복원. 같은 파일의 다른 9개 설정과 동일 패턴 | `ConfigStore.swift:13` (대조 `:21-76`) | XS |
| **B-08** | **테마 활성 ID 키 이중 정의 해소** — `ThemeConfigurationStore.activeThemeKey`를 `ConfigStore.PrefKeys.activeThemeId`로 통합 + 기존 값 1회 이관 | `ConfigStore+Preferences.swift:25` vs `ThemeConfigurationStore.swift:13, 110, 175` | M |
| **B-09** | **FSEventStream 해제 전 콜백 큐 동기화** — use-after-free 창 제거 | `AutomationManager.swift:90-99` | S |
| **B-10** | **osascript 오류 분류 정정** — 실측 기준 프로세스/항목 미발견은 `-1728`(현재 기본 분기). `-1743`은 **Automation TCC** 거부이므로 "손쉬운 사용 권한 없음" 문구 오류. `appNotRunning` 판정 근거 재정립 | `MenuEnumerator.swift:174-185` (실측: 미실행 앱·없는 메뉴 전부 `-1728`) | M |
| **B-11** | **`menuPath` count==1 처리** — 단일 세그먼트는 `menu bar item` 클릭 또는 명시적 실패. **관련 테스트 갱신 필수** | `MenuEnumerator.swift:130, 153, 159` / `ApexKeyStoreTests.swift:99-103` | S |

### Phase C — 카탈로그 정합 (ACTION_AUDIT_v3 §8)

| ID | 항목 | 규모 |
|---|---|:-:|
| **C-01** | 미구현 125종 카탈로그 노출 정리 + "준비 중" 배지. `ActionType` ↔ 핸들러 **컴파일 타임 정합성 검사** | M |
| **C-02** | 자동화 트리거 8종 숨김 + `automationTriggerCount`를 실제 등록 수로 + README 정정 | S |
| **C-03** | 하드코 절대경로 제거 — `SystemActionExecutor.swift:70-71`의 `preferred` 우선순위를 Application Support로 | XS |
| **C-04** | 죽은 코드 정리 — `resolveToken`(호출 0), `ControlFlow.breakLoop/.continueLoop`(생산자 0), `RunShortcutAction`(미인스턴스화), `Variable.tokenString`(미사용), `runsInBackground`(전부 true), `isUsableKeyCode`(호출 0), `moveBinding`(호출 0), `conditionDetailManuallySet` | M |
| **C-05** | 죽은 자산 정리 — 미사용 스크립트 6개(`build_strings`/`comprehensive_replace`/`localize_all`/`replace_strings`×3), 죽은 i18n 키 23개 | S |
| **C-06** | `build_and_run.sh test`의 smoke/unit/full 3분기가 완전 동일 → 실제 분리 | S |
| **C-07** | `release.yml`에 현지화 가드 스텝 추가 (`check-localizable.py`가 ci/build에는 있으나 release에 없음) | XS |

---

## 문서 작업 (코드 착수 전 완료)

- [x] `docs/plans/ACTION_AUDIT_v3_macos.md` 신규 — 153종 현실 매핑 + 거짓 `[x]` 7건
- [x] `docs/plans/PLAN_v0.21_audit-fix-macos.md` 신규 (본 문서)
- [x] `docs/FUNCTIONAL_CHECKLIST.md` 전면 갱신 (v0.2.1-era 8개월 방치 해소)
- [x] `docs/TODO.md` v0.21 등록 + 거짓 `[x]` 6건 정정
- [ ] `docs/CHANGELOG.md` v0.21 기록 (코드 완료 후)
- [ ] `docs/DESIGN.md` 갱신 (63줄, 상태 체크박스 전부 미갱신)

## DoD

- [ ] 빌드 통과: `./build_and_run.sh build macos`
- [ ] 테스트 통과: `./build_and_run.sh test macos unit` (기존 171건 0실패 유지 + 회귀 추가)
- [ ] 현지화 게이트 통과: `python3 scripts/check-localizable.py`
- [ ] 신규 회귀 테스트: A-01(파이프 64KiB), A-02(inf/NaN), A-04(핫키 교체 보존), B-01(반복 실패 전파), B-03(스크립트 출력), B-11(단일 세그먼트)
- [ ] TODO/CHANGELOG 동기화
- [ ] `.agent/session-2026-09-27-macos.md`

## 비고 — 하지 않는 것 (YAGNI)

- **125종 액션 추가 구현 안 함.** C-01로 표면 정합만 맞춘다.
- **AI 3종 실제 FoundationModels 연동 안 함.** A-03은 "정직한 실패"로 바꾼다. 실제 연동은 별도 과제로 분리(리서치 필요).
- **`error_message_ko.json` 신설 안 함.** 현재 `Localizable.strings`의 `error.user.*` 5키가 en까지 포함해 더 낫다. 규칙 예외를 문서화하는 방향으로 정리.
- **테마 키 이관(B-08)은 데이터 이관이 필요** → 사용자 데이터 손상 위험이 있어 B-08만 별도 커밋으로 분리.

## 커밋 계획 (1커밋 1관심사)

1. `docs(macos): 감사 결과 문서화 (ACTION_AUDIT_v3 + PLAN_v0.21 + FUNCTIONAL_CHECKLIST 갱신)`
2. `fix(macos): 파이프 교착 제거 — waitUntilExit 동시 드레인 (4곳)`
3. `fix(macos): inf/NaN Int 변환 크래시 가드 (E-MAC-VAR-1002)`
4. `fix(macos): AI 3종 스텁 거짓 성공 제거 (E-MAC-AI-9013)`
5. `fix(macos): setLaunchBinding 파괴-후-검증 제거 (E-MAC-HTKEY-1003)`
6. `fix(macos): 셸 인용부호 방어 (E-MAC-SCRIPT-6004)`
7. `fix(macos): 버전 단일 출처화 — project.yml MARKETING_VERSION (E-MAC-REL-9301)`
8. `fix(macos): 실행 결과 전파 정합 — 반복 실패·에러 보존·스크립트 출력 (E-MAC-FLOW-7009)`
9. `fix(macos): 핫키 저장 실패 전달 (E-MAC-UX-9010)`
10. `fix(macos): removeApp 연관 바인딩 정리 + showHiddenApps 영속 (E-MAC-STORE-5007)`
11. `fix(macos): 테마 활성 ID 키 통합 (E-MAC-UX-9011)`
12. `fix(macos): FSEventStream 해제 동기화 (E-MAC-AUTO-8002)`
13. `fix(macos): osascript 오류 분류 정정 (E-MAC-MENU-7007)`
14. `fix(macos): menuPath 단일 세그먼트 처리 (E-MAC-MENU-7008)`
15. `feat(macos): 미구현 액션 카탈로그 정합 + 컴파일 타임 검사 (E-MAC-CAT-9401)`
16. `chore(macos): 죽은 코드·자산 정리`
17. `docs(macos): CHANGELOG v0.21 + 세션 로그`
