# PLAN_v0.13_codec-path_macos.md
> 생성일: 2026-09-22 | 플랫폼: macos | 작성자: AI

## 1. 목표 (1줄)
LaunchConfig 코덱·PATH 폴백 단일 출처화 (DRY).

## 2. 범위
- 플랫폼: macos
- 기술 스택: Swift + SwiftData
- design_profile: native

## 3. 문서 위치
- PLAN: 본 문서
- TODO: docs/TODO.md v0.13 (C-01~02) 등록
- DESIGN: 해당 없음

## 4. 성능 예산
- budgets.json macos 기준 준수. 초과 시 WARN.
- 테스트: unit ≤60s

## 5. 에러 코드
- 기존 E-MAC-APP-4003 재사용. 신규 코드 없음.

## 6. 빌드 & 검증 계획
- ./build_and_run.sh build macos
- ./build_and_run.sh test macos unit (Launch·Refactor·ActionVerify 회귀)
- `json:` 포맷 불변 (기존 테스트가 고정)

## 7. 예외 규칙 (있으면)
- 없음. `ActionExecutor.decode/encodeLaunchConfig`는 테스트 참조 중이라 thin wrapper로 유지.
