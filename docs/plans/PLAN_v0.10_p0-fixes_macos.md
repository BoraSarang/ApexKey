# PLAN_v0.10_p0-fixes_macos.md
> 생성일: 2026-09-22 | 플랫폼: macos | 작성자: AI

## 1. 목표 (1줄)
P0 크리티컬 5건(교착·크래시·언랩·중복키·메인블로킹) 수정.

## 2. 범위
- 플랫폼: macos
- 기술 스택: SwiftUI + AppKit + Carbon + SwiftData + xcodegen
- design_profile: native

## 3. 문서 위치
- PLAN: 본 문서
- TODO: docs/TODO.md v0.10 (F-01~05) 등록
- DESIGN: 해당 없음 (동작 변경 없음)
- API: 해당 없음

## 4. 성능 예산
- budgets.json macos cold start 1.5s, 메모리 300MB 준수. 초과 시 WARN.
- 테스트: unit ≤60s (smoke+unit 기본 루프)

## 5. 에러 코드
- 기존 E-MAC-FLOW-7008(반복), E-MAC-MENU-3002(메뉴), E-MAC-ACT-3006(대기) 재사용. 신규 코드 없음.

## 6. 빌드 & 검증 계획
- ./build_and_run.sh build macos
- ./build_and_run.sh test macos unit
- scripts/check-localizable.py 게이트
- DebugPanel ERROR 0 확인

## 7. 예외 규칙 (있으면)
- 없음.
