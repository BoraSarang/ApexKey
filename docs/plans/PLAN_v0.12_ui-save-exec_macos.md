# PLAN_v0.12_ui-save-exec_macos.md
> 생성일: 2026-09-22 | 플랫폼: macos | 작성자: AI

## 1. 목표 (1줄)
편집기 저장 유실 2건 + 실행 분기 중복 80줄 제거.

## 2. 범위
- 플랫폼: macos
- 기술 스택: SwiftUI + AppKit + SwiftData
- design_profile: native

## 3. 문서 위치
- PLAN: 본 문서
- TODO: docs/TODO.md v0.12 (U-01~03) 등록
- DESIGN: 해당 없음

## 4. 성능 예산
- budgets.json macos 기준 준수. 초과 시 WARN.
- 테스트: unit ≤60s

## 5. 에러 코드
- 기존 E-MAC-APP-4003(URL), E-MAC-ACT 계열 재사용. 신규 코드 없음.

## 6. 빌드 & 검증 계획
- ./build_and_run.sh build macos
- ./build_and_run.sh test macos unit (ActionVerify·Refactor·Script 회귀)
- scripts/check-localizable.py 게이트

## 7. 예외 규칙 (있으면)
- 없음. 고정프레임 전수 교체·접근성 일괄은 시각 회귀 위험이라 후속 과제로 분리.
