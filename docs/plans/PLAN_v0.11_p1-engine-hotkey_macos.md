# PLAN_v0.11_p1-engine-hotkey_macos.md
> 생성일: 2026-09-22 | 플랫폼: macos | 작성자: AI

## 1. 목표 (1줄)
P1 엔진 실패전파 3건 + 핫키 미등록 가시화 1건 수정.

## 2. 범위
- 플랫폼: macos
- 기술 스택: SwiftUI + AppKit + Carbon + SwiftData + xcodegen
- design_profile: native

## 3. 문서 위치
- PLAN: 본 문서
- TODO: docs/TODO.md v0.11 (G-01~04) 등록
- DESIGN: 해당 없음 (동작 정합화, 스펙 변경 없음)

## 4. 성능 예산
- budgets.json macos 기준 준수. 초과 시 WARN.
- 테스트: unit ≤60s

## 5. 에러 코드
- 기존 E-MAC-FLOW-7009(재귀), E-MAC-HTKEY-1001(핫키) 재사용. 신규 코드 없음.

## 6. 빌드 & 검증 계획
- ./build_and_run.sh build macos
- ./build_and_run.sh test macos unit
- scripts/check-localizable.py 게이트

## 7. 예외 규칙 (있으면)
- 없음. RunShortcut 입출력 전달·자동화 미구현 8종·전체 비동기화는 API 변경 규모라 후속 과제로 분리.
