# PLAN_v0.16_store-p0_macos.md
> 생성일: 2026-09-22 | 플랫폼: macos | 작성자: AI

## 1. 목표 (1줄)
저장소 데이터 소실 P0 3건 차단 — blob 쓰기 가드, 레거시 경로 1회 이관, 컨테이너 실패 격리·재생성.

## 2. 범위
- 플랫폼: macos
- 기술 스택: SwiftData + Foundation
- design_profile: native
- 수정 대상:
  - P0-3 `StoreCoding` encode 실패 시 빈 `Data()` 반환 → `syncShortcut`이 원본 blob 영구 덮어쓰기. 디코딩 실패 컬럼 쓰기 가드 + `encodeKeeping`
  - P0-1 `Application Support/default.store` → `com.borasarang.ApexKey/default.store` 이관 코드 부재 → 1회 마이그레이션 (store + `-wal`/`-shm`)
  - P0-2 `ModelContainer` 생성 실패 시 무음 no-op → 손상 파일 격리(`.corrupt-{stamp}`) 후 재시도 + `storeRecoveryBackupPath` 게시

## 3. 문서 위치
- PLAN: 본 문서
- TODO: docs/TODO.md v0.16 (S-01~S-03) 등록
- DESIGN: 해당 없음

## 4. 성능 예산
- budgets.json macos 기준 준수. 초과 시 WARN.
- 테스트: unit ≤60s

## 5. 에러 코드
- `E-MAC-STORE-5005`: 레거시 저장소 이관 실패
- `E-MAC-STORE-5006`: 저장소 손상 격리 후 재생성
- 기존: 5001(컨테이너·저장), 5002(인코딩), 5003(디코딩·쓰기가드), 5004(조회)

## 6. 빌드 & 검증 계획
- ./build_and_run.sh build macos
- ./build_and_run.sh test macos unit
- 회귀: encodeKeeping 실패 시 previous 유지, undecodableBlobColumns 판정, 레거시 이관 파일 이동
