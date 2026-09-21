# 동작 실동작 검증 체크리스트 v2 (macOS)

> 생성: 2026-09-21 / 대상: 앱 실행·스크립트 중심 전수 점검
> 이전 문서(`ACTION_AUDIT_v1_macos.md`)의 P0 영역을 [자동]/[수동]으로 분리·계승한 것.
> 이 문서는 계속 업데이트하면서 사용한다 — [자동] 행은 스크립트가 덮어쓰고, [수동] 행은 사람이 직접 체크한다.

## 사용법

- **자동 반영**: `python3 scripts/update-verify-checklist.py` — unit 테스트를 실행하고,
  `[자동]` 행의 체크박스를 결과에 따라 갱신한다 (`[x]` 통과 / `[ ]` + `FAIL` 실패).
  `[수동]` 행은 절대 건드리지 않는다.
- **수동 체크**: 시나리오대로 직접 해보고 `[ ]` → `[x]`로 바꾼다. 실패하면 행 뒤에 `FAIL: 증상` 메모.
- **마지막 자동 반영**: 2026-09-21 — [자동] 행 24통과 0실패 1스킵

## 자동화 가능/불가 경계 (확인済)

- **자동 가능**: 실패 경로(오타 번들ID·빈 입력·문법 오류), 파싱/인코딩 왕복, 읽기 전용 실실행
  (셸 echo·Finder 이름 조회 AppleScript/JXA), 기기 없을 때의 조용한 실패.
  → `Sources/ApexKeyTests/ApexKeyActionVerifyTests.swift` (18건)
- **자동 불가(수동)**: 실제 앱 띄우기·숨기기 (작업공간 침범), 실제 키 전송 (전면 앱에 입력 전달),
  기기 연결 시 scrcpy 실행, SwiftUI 레이아웃 깨짐 여부. → 아래 [수동] 행.

## LAUNCH — 앱 실행/토글

| 체크 | ID | 시나리오 | 구분 |
|---|---|---|---|
| [x] | V-LAUNCH-01 | 오타 번들ID(`com.example.Nope`) → 실패 반환, 크래시 없음 | [자동] `ApexKeyActionVerifyTests.testVerifyLaunchBogusBundleIDFails` <!-- auto:ApexKeyActionVerifyTests.testVerifyLaunchBogusBundleIDFails --> |
| [x] | V-LAUNCH-02 | 번들ID+경로 비움 → 실패 반환 + 안내 | [자동] `ApexKeyActionVerifyTests.testVerifyLaunchEmptyConfigFails` <!-- auto:ApexKeyActionVerifyTests.testVerifyLaunchEmptyConfigFails --> |
| [x] | V-LAUNCH-03 | 엔진 경로: 오타 번들ID 단계 → success=false, 크래시 없음 | [자동] `ApexKeyActionVerifyTests.testVerifyLaunchEngineReportsFailure` <!-- auto:ApexKeyActionVerifyTests.testVerifyLaunchEngineReportsFailure --> |
| [x] | V-LAUNCH-04 | 인자 파싱: 따옴표 그룹 유지 | [자동] `ApexKeyActionVerifyTests.testVerifyLaunchArgsParsing` <!-- auto:ApexKeyActionVerifyTests.testVerifyLaunchArgsParsing --> |
| [x] | V-LAUNCH-05 | 모드 3종(toggle/activate/launch) 설정 보존·영속 왕복 | [자동] `ApexKeyActionVerifyTests.testVerifyLaunchModesRoundTrip` <!-- auto:ApexKeyActionVerifyTests.testVerifyLaunchModesRoundTrip --> |
| [x] | V-LAUNCH-06 | Safari/TextEdit 번들ID → LaunchServices URL 해석됨 | [자동] `ApexKeyStoreTests.testRegisteredAppURLResolvedByBundleID` <!-- auto:ApexKeyStoreTests.testRegisteredAppURLResolvedByBundleID --> |
| [ ] | M-LAUNCH-01 | Safari 지정 → 실행→전면이면 숨김→다시 활성화 (토글 실동작) | [수동] |
| [ ] | M-LAUNCH-02 | URL스킴(`obsidian://open`) 입력 → 해당 앱 열림 (미설치 시 OS 경고, 크래시 없음) | [수동] |
| [ ] | M-LAUNCH-03 | 인자 실실행 (`--incognito` 등으로 Safari 새 창) | [수동] |
| [ ] | M-LAUNCH-04 | 앱 검색 결과 클릭 → 번들ID+경로 채움+검색어 초기화+목록 접기+선택 요약행 (재선택 시 잔재 없음) | [수동] |
| [ ] | M-LAUNCH-05 | 목록 높이 제한으로 내부 스크롤, 아래 필드 항상 가시, 개수 캡션 | [수동] |
| [ ] | M-LAUNCH-06 | 초성 검색 (예: ㅅㅍㄹ → Safari) | [수동] |
| [ ] | M-LAUNCH-07 | 변수 토큰 해석 (bundleID에 `{clipboard}` 등 → 해석 후 실행) | [수동] |
| [ ] | M-LAUNCH-08 | 레거시 호환: 기존 `target=com.apple.Safari` 단계 → 그대로 토글 동작 | [수동] |

## SCRIPT — 셸 스크립트

| 체크 | ID | 시나리오 | 구분 |
|---|---|---|---|
| [x] | V-SCRIPT-01 | 셸 정상: echo 출력·종료코드 0 | [자동] `ApexKeyActionVerifyTests.testVerifyShellSuccess` <!-- auto:ApexKeyActionVerifyTests.testVerifyShellSuccess --> |
| [x] | V-SCRIPT-02 | 셸 문법 오류 → 실패 반환 + 에러 메시지, 크래시 없음 | [자동] `ApexKeyActionVerifyTests.testVerifyShellSyntaxErrorFails` <!-- auto:ApexKeyActionVerifyTests.testVerifyShellSyntaxErrorFails --> |
| [x] | V-SCRIPT-03 | 셸 빈 입력 → 실행 없음 + 실패 반환 | [자동] `ApexKeyActionVerifyTests.testVerifyShellEmptyFails` <!-- auto:ApexKeyActionVerifyTests.testVerifyShellEmptyFails --> |
| [x] | V-SCRIPT-04 | 엔진 경로: 실패해도 단계 중단 아님 (success=false) | [자동] `ApexKeyActionVerifyTests.testVerifyShellEngineFailure` <!-- auto:ApexKeyActionVerifyTests.testVerifyShellEngineFailure --> |
| [ ] | M-SCRIPT-01 | 스크립트 입력창 높이 고정 + 내부 스크롤 (창 전체 스크롤 유발 없음, 긴 스크립트) | [수동] |
| [ ] | M-SCRIPT-02 | 하단 푸터 한 줄 고정 (테스트 실행+상태만, 입력 길이에 무관하게 항상 가시) | [수동] |
| [ ] | M-SCRIPT-03 | 테스트 실행 → 별도 결과 창 자동 팝업 (600×460, 리사이즈 가능) | [수동] |
| [ ] | M-SCRIPT-04 | 결과 창: 종료 코드·출력 표시 + 복사 버튼 + 닫기 + 푸터 `결과 보기` 재오픈 | [수동] |
| [ ] | M-SCRIPT-05 | 단계 설정 창 빨간 X로 닫아도 저장 유실 없음 | [수동] |

## APPLESCRIPT / JXA

| 체크 | ID | 시나리오 | 구분 |
|---|---|---|---|
| [x] | V-AS-01 | AppleScript 정상 (`Finder` 이름 조회 → 성공+출력) | [자동] `ApexKeyActionVerifyTests.testVerifyAppleScriptSuccess` <!-- auto:ApexKeyActionVerifyTests.testVerifyAppleScriptSuccess --> |
| [x] | V-AS-02 | AppleScript 문법 오류 → 실패 반환 + 에러 메시지 | [자동] `ApexKeyActionVerifyTests.testVerifyAppleScriptSyntaxErrorFails` <!-- auto:ApexKeyActionVerifyTests.testVerifyAppleScriptSyntaxErrorFails --> |
| [x] | V-AS-03 | AppleScript 빈 입력 → 건너뜀 + 실패 반환 | [자동] `ApexKeyActionVerifyTests.testVerifyAppleScriptEmptyFails` <!-- auto:ApexKeyActionVerifyTests.testVerifyAppleScriptEmptyFails --> |
| [x] | V-JXA-01 | JXA 정상 (`Application('Finder').name()` → 성공) | [자동] `ApexKeyActionVerifyTests.testVerifyJXASuccess` <!-- auto:ApexKeyActionVerifyTests.testVerifyJXASuccess --> |
| [x] | V-JXA-02 | JXA 오류 → 실패 반환 + stderr | [자동] `ApexKeyActionVerifyTests.testVerifyJXAErrorFails` <!-- auto:ApexKeyActionVerifyTests.testVerifyJXAErrorFails --> |
| [ ] | M-AS-01 | 스크립트 단계 실행 후 출력이 변수에 저장되어 다음 단계에서 사용 가능 | [수동] |

## SYSTEM — 시스템 탭 (Android 미러 포함)

| 체크 | ID | 시나리오 | 구분 |
|---|---|---|---|
| [ ] | V-SYS-01 | Android 미러: 기기 없음 → 조용히 실패(false), 크래시 없음 (기기 연결 시 스킵) | [자동] `ApexKeyActionVerifyTests.testVerifyAndroidMirrorNoDeviceFailsGracefully` <!-- auto:ApexKeyActionVerifyTests.testVerifyAndroidMirrorNoDeviceFailsGracefully --> **SKIP**|
| [x] | V-SYS-02 | 시스템 액션 9종 타입·이름·아이콘 완비 (목록 누락 방지) | [자동] `ApexKeyActionVerifyTests.testVerifySystemActionCatalogComplete` <!-- auto:ApexKeyActionVerifyTests.testVerifySystemActionCatalogComplete --> |
| [x] | M-SYS-01 | 시스템 탭에 `Android Remote Mirror (scrcpy)` 표시 + 실행 버튼 동작 (기기 연결 시 scrcpy 뜸) | [수동] 2026-09-21 확인: 단축키 실동작으로 scrcpy 정상 표시 (동일 execute 경로). USB+무선 중복 연결 시 기기 미지정 실패 → `-s` 시리얼 명시로 수정済. 이후 외부 파일 `scrcpy_run.sh` 단일 소스로 전환 (재빌드 없이 파일 수정 즉시 반영) |
| [x] | M-SYS-02 | 미러에 단축키 지정 → 글로벌 핫키로 실행됨 | [수동] 2026-09-21 확인: 지정 단축키로 scrcpy 뜸 |
| [ ] | M-SYS-03 | 과거 고정 3건(Untether/Mirror/Remote) 삭제됨 + 예시 동작 재생성 없음 | [수동] |

## KEYCOMBO — 키 조합 보내기

| 체크 | ID | 시나리오 | 구분 |
|---|---|---|---|
| [x] | V-KEY-01 | 잘못된 형식 → 엔진 실패 반환, 전송 없음 | [자동] `ApexKeyActionVerifyTests.testVerifyKeyComboInvalidFails` <!-- auto:ApexKeyActionVerifyTests.testVerifyKeyComboInvalidFails --> |
| [x] | V-KEY-02 | 빈 조합 전송 → 부작용 없이 실패 | [자동] `ApexKeyActionVerifyTests.testVerifyKeyComboEmptyFails` <!-- auto:ApexKeyActionVerifyTests.testVerifyKeyComboEmptyFails --> |
| [ ] | M-KEY-01 | 기록 버튼으로 ⌥⌘L 캡처 → Finder 전면 + 등록 단축어 실행 → 실제 전달됨 | [수동] |
| [ ] | M-KEY-02 | 기록 중 Esc → 취소, 수식키 없는 단독 키 → 삼키고 대기 계속 | [수동] |

## TOAST — 실행 결과 알림 (OS 알림센터 미사용)

| 체크 | ID | 시나리오 | 구분 |
|---|---|---|---|
| [x] | V-TOAST-01 | 잘못된 키 조합 → 실패 + 사유 포함 | [자동] `ApexKeyActionVerifyTests.testVerifyDetailKeyComboInvalid` <!-- auto:ApexKeyActionVerifyTests.testVerifyDetailKeyComboInvalid --> |
| [x] | V-TOAST-02 | 빈 스크립트 → 실패 + 사유 포함 | [자동] `ApexKeyActionVerifyTests.testVerifyDetailEmptyScript` <!-- auto:ApexKeyActionVerifyTests.testVerifyDetailEmptyScript --> |
| [x] | V-TOAST-03 | 알 수 없는 시스템 액션 → 실패 + 사유 포함 | [자동] `ApexKeyActionVerifyTests.testVerifyDetailUnknownSystem` <!-- auto:ApexKeyActionVerifyTests.testVerifyDetailUnknownSystem --> |
| [x] | V-TOAST-04 | 오타 번들ID 실행 → 실패 + 사유 포함 (레거시 성공 둔갑 수정) | [자동] `ApexKeyActionVerifyTests.testVerifyDetailBogusLaunch` <!-- auto:ApexKeyActionVerifyTests.testVerifyDetailBogusLaunch --> |
| [x] | V-TOAST-05 | 성공 시 메시지는 nil | [자동] `ApexKeyActionVerifyTests.testVerifyDetailSuccessHasNoMessage` <!-- auto:ApexKeyActionVerifyTests.testVerifyDetailSuccessHasNoMessage --> |
| [x] | V-TOAST-06 | 동작 실패 → 엔진 에러 메시지 전달 | [자동] `ApexKeyActionVerifyTests.testVerifyDetailShortcutFailure` <!-- auto:ApexKeyActionVerifyTests.testVerifyDetailShortcutFailure --> |
| [ ] | M-TOAST-01 | 단축키 실행 → 우상단 토스트 표시, 성공 1.5초 후 자동 소멸 | [수동] |
| [ ] | M-TOAST-02 | 실패 → 6초 표시 + 사유 노출, 클릭 시 디버그 로그 창 열림 | [수동] |
| [ ] | M-TOAST-03 | 토스트 표시 중 전면 앱 포커스 유지 (입력 포커스 뺏김 없음) | [수동] |
| [ ] | M-TOAST-04 | 설정에서 성공 알림 OFF → 실패할 때만 표시 | [수동] |
| [ ] | M-TOAST-05 | 연속 실행 시 토스트 교체 (쌓이지 않음) | [수동] |

## 명령 팔레트 · 공통 UI 회귀

| 체크 | ID | 시나리오 | 구분 |
|---|---|---|---|
| [ ] | M-PAL-01 | 빈 입력 → 고정 6종 표시 (빈 패널 없음), 최근 실행 상위 5건 | [수동] |
| [ ] | M-PAL-02 | 동작/단축키/앱/단계내용 검색 + 초성 하이라이트 + Enter 실행 | [수동] |
| [ ] | M-PAL-03 | 설정에서 팔레트 단축키 변경·되돌리기 | [수동] |
| [ ] | M-UI-01 | 단계 설정 창 480×680, 헤더/푸터 고정, 본문만 스크롤 | [수동] |
| [ ] | M-UI-02 | Cmd+C/V/X/A/Z 동작 (편집 메뉴), 한글/영문 전환 시 깨짐 없음 | [수동] |

## 기존 회귀 스위트 (자동, 전체)

`ApexKeyFlowTests` (흐름·변수·반복) · `ApexKeyMenuTests` (편집 메뉴) · `ApexKeyMetadataTests` ·
`ApexKeyModelTests` · `CommandPaletteTests` · `KeyComboTests` · `KoreanSearchTests` ·
`LaunchAppSelectionTests` · `PaletteMatchTests` · `ApexKeyScriptTests` · `ApexKeyStoreTests` —
`update-verify-checklist.py` 실행 시 함께 돌고, 실패가 있으면 해당 [자동] 행에 `FAIL` 표시.
