# PLAN_v0.15_split-theme_macos.md
> 생성일: 2026-09-22 | 플랫폼: macos | 작성자: AI

## 1. 목표 (1줄)
Theme.swift 888줄 → Models/Theme/ 4파일 분할 (동작 불변).

## 2. 범위
- 플랫폼: macos
- 기술 스택: SwiftUI
- design_profile: native

## 3. 문서 위치
- PLAN: 본 문서
- TODO: docs/TODO.md v0.15 (D-02) 등록
- DESIGN: 해당 없음

## 4. 성능 예산
- budgets.json macos 기준 준수. 초과 시 WARN.
- 테스트: unit ≤60s

## 5. 에러 코드
- 없음 (이동만).

## 6. 빌드 & 검증 계획
- ./build_and_run.sh build macos
- ./build_and_run.sh test macos unit
- 타입명·public 유지, 동작 불변
