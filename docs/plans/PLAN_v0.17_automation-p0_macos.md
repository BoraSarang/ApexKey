# PLAN_v0.17_automation-p0_macos.md
> 생성일: 2026-09-22 | 플랫폼: macos | 작성자: AI

## 1. 목표 (1줄)
자동화·핫키 P0/P1 수정 — activeTimers 날짜 키, ⌘⇧↩ 사이보그 교착, RepeatRule 실구현, 미구현 트리거 차단, ignorePatterns·FSEvent 복합 flags.

## 2. 범위
- 플랫폼: macos
- 기술 스택: Foundation + FSEvents + Carbon
- design_profile: native
- 수정 대상:
  - P0-4 `activeTimers` 값이 `"H:M"`만 → `yyyy-MM-dd-HH:mm` 날짜 키 + unregister 시 정리 + `.none`은 UserDefaults 1회 영속
  - P0-5 ⌘⇧↩ Carbon 등록 ↔ `pauseUntilInput` 로컬 모니터 교착 → `ActionExecutor.resumePauseUntilInput()` Carbon 경로 병행 해제, 대기 중에는 반복 실행 안 함
  - P1 RepeatRule `weekly/monthly/custom` 전부 true → `TimeOfDayTrigger`에 기준 요일/날짜 필드 + 실제 shouldRun + 설정 UI
  - P1 미구현 트리거 8종 + UI에 노출된 `file` → `isWatcherSupported` 가드 + 등록 로그 + UI 비활성
  - P1 `ignorePatterns` 미적용 → glob 매치 스킵
  - P1 FSEvent 복합 flags 단일 매핑 → 전 타입 산출 후 교집합 판정
  - P1 핫키 프로브 고정 시그니처 → 일회성 signature, `beginTest` 선행 `endTest`

## 3. 문서 위치
- PLAN: 본 문서
- TODO: docs/TODO.md v0.17 (A-01~A-07) 등록
- DESIGN: 해당 없음

## 4. 성능 예산
- budgets.json macos 기준 준수. 초과 시 WARN.
- 테스트: unit ≤60s

## 5. 에러 코드
- `E-MAC-AUTO-6001`: 미구현 트리거 등록 거부
- 기존 AutomationManager info 로그 유지

## 6. 빌드 & 검증 계획
- ./build_and_run.sh build macos
- ./build_and_run.sh test macos unit
- 회귀: RepeatRule weekdays/weekdays 기존 테스트 유지, 신규 weekly/monthly/custom·dedupKey·ignorePatterns·복합flags 테스트
