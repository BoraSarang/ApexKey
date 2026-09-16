# PLAN v0.4 — 깊은 리팩터 (R1)

> 작성일: 2026-09-16 · 플랫폼: macOS · 기준: 3방향 병렬 감사
> 원칙: 동작 보존 + 버그 수정만. 제품 결정(127개 액션 실행 구현, B12, B7 전체)은 백로그.

## R1 범위 (이번 세션)

| ID | 내용 | 근거 |
|---|---|---|
| R-01 | 엔진 `default` 실패 전파 — `ActionExecutor=false`면 `Result(success:false)` 반환, 변수 토큰 치환 추가 | P1 #2, B7 부분 |
| R-02 | `wait` 순서 버그 — 호출 스레드에서 동기 sleep + 메인 스레드 경고 | P1 #3 |
| R-03 | `pauseUntilInput` 메인 교착 가드 — 메인 호출 시 백그라운드 실행 | P1 #4 |
| R-04 | `MenuEnumerator` 강제 캐스트 제거 (`as!`→`as?`+에러 로그) | P1 #5 |
| R-05 | 저장 실패 묵살 해소 — `saveContext(_:tag:)` 헬퍼로 18곳 `try? save()` 교체 + DataModels JSON 실패 로그 | P1 #6/#7 |
| R-06 | 죽은 코드 삭제 — `runScript` 래퍼, `debugInfo`, `toModelContext`, `value(forName:)`, `executeFollowUp`(호출 확인 후) | P2 #11~15 |
| R-07 | PATH 상수 단일화 — `ShellEnvironment` 신설, ActionExecutor·테스트가 공유 | P2 #17 |
| R-08 | 카테고리 매핑 정합 — 5종 `.variables` 귀속(중복 등록 해소), `automationRun`/`trigger`를 `.automation` 목록에 추가 | P2 #9, 감사 5a/5b |
| R-09 | ActionType 메타데이터 테이블화 — displayName/systemImage/category 3스위치→테이블 + 정합성 테스트 | 감사 2 |
| R-10 | ConfigStore 파일 분할 — 동일 클래스 extension을 영역별 파일로 분리 (public API 동결, 동작 변경 0) | P2 #8 |
| R-11 | summary 표시/실행 불일치 — 반복 nil "0회"→"반복" | 감사 4 |

## 명시적 비범위 (백로그)

- 127개 액션 실행 구현 (dialog/text/미디어/문서/…) — 제품 결정 필요
- B7 전체 (Binding 스키마에 outputVariables/actionParameters 추가)
- B12 RepeatRule weekly/monthly 모델 확장
- ConfigStore 완전 분할 S0~S7 (Facade+View 주입 변경) — R1의 extension 분할이 전 단계
- AI 스텁 연동 표시, 버튼 테마 프리셋, sectionCard/ThemedCard 통합
- `executeFollowUp` 실행 연결 (Follow-Up 토글 UI는 있으나 대화 이력 plumbing 미완 — 함수 유지됨)

## 게이트

각 단계 후 `./build_and_run.sh build macos` + `./build_and_run.sh test macos unit`.
전체 70건 중 기존 환경 실패 1건(MovistPro) 제외 전원 통과 필수.
재설치·재실행 후 저장소 무손실 + 프리셋 2종 정상 확인.
