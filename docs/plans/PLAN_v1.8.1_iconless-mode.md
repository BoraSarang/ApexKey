# PLAN_v1.8.1_iconless-mode.md
> 생성일: 2026-11-19 | 플랫폼: macOS | 작성자: agent

## 1. 목표 (1줄)
메뉴바·Dock 아이콘을 **모두 꺼도** 전역 단축키가 계속 동작하고, `.app` 재실행으로 설정 창에 도달하는 "무아이콘 모드"를 제공한다.

## 2. 범위
- 플랫폼: macOS 14+ (SwiftUI + AppKit)
- 기술 스택: 기존 스택 유지 — 재실행 이벤트는 `NSApplicationDelegate.applicationShouldHandleReopen`, 로그인 시작 구분은 `kAEOpenApplication` + `keyAELaunchedAsLogInItem`
- design_profile: native
- 지원 언어: en(기본) + ko — `Sources/ApexKey/{en,ko}.lproj/Localizable.strings` (UTF-16)
- 이번에 하지 않는 것:
  - 다른 앱의 메뉴바 아이콘을 숨기는 기능(Bartender/Ice류) — 제품 동결 범위 밖
  - 메뉴바 아이콘 자동 숨김·정리, 새 전역 단축키 추가
  - 상태 아이템을 재실행 시 임시로 복원하는 방식 (PopClip 2021 방식 — 채택하지 않음)

## 3. 문서 위치
- PLAN: 본 문서
- TODO: `docs/TODO.md` T-226 등록
- DESIGN: `docs/DESIGN.md` §3-1 "메뉴바·Dock 표시 정책" 1절 추가
- 목업: 생략 — 신규 화면·리디자인이 아니라 기존 설정 창의 행/알림 추가 (사유 기록)
- API: 해당 없음

## 4. 성능 예산
- `budgets.json` macOS cold start 1.5s 유지. 변경은 실행/재실행 시 분기 1회뿐이며 상시 비용 없음
- 메뉴바 상주 가벼움: 새 타이머·폴링 없음

## 5. 에러 코드
- 신규 에러 코드 없음. 분기 결과는 `Logger.info("AppDelegate", "[LAUNCH]/[REOPEN] ...")`로 기록
- 기존 코드 범위: `E-MAC-*` (변경 없음)

## 6. 빌드 & 검증 계획
- 빌드: `xcodegen generate --spec project.yml` → `./build_and_run.sh debug macos`
- 테스트: `./build_and_run.sh test macos unit` (예산 60초)
- 자동 검증:
  - `ReopenRoutingTests` — 재실행 라우팅 2분기 + 실행 시 설정 창 조건 4케이스
  - `ConfigStoreMutationTests` — 메뉴바·Dock 둘 다 끄기 허용, 기존 구멍 회귀 방지
  - 게이트 3종(`check-localizable.py`·`check-version.py`·`check-trackpad-boundary.py`)
- 실측 매트릭스 (사용자 확인):
  1. 아이콘 둘 다 끔 → 앱 종료 → Finder에서 `.app` 실행 → 설정 창 표시
  2. 설정 창 닫기 → `.app` 재실행 → 설정 창 다시 표시
  3. 설정 창에서 종료 → `.app` 실행 → 설정 창 표시
  4. 메뉴바 아이콘만 켬 → `.app` 재실행 → 설정 창 표시 + 아이콘 유지
  5. 로그인 자동 시작(켠 경우) → 로그인 시 설정 창이 뜨지 않고 숨김 유지

## 7. 리스크 & 롤백
| 리스크 | 영향 | 대응 |
|---|---|---|
| 로그인 자동 시작을 수동 실행으로 오판 | 로그인 때마다 설정 창 표시 | `keyAELaunchedAsLogInItem` 확인 + 판정 결과 로그. 실패 시 사용자 보고 후 보정 |
| SwiftUI 바인딩이 확인 알림 중 원위치로 스냅 | 토글이 잠깐 되돌아 보임 | 확인 후 저장값 변경 → 최종 상태 일치. 실기 확인 항목에 포함 |
| 기존에 이미 둘 다 꺼진 사용자 | 업데이트 후 첫 실행에서 설정 창 표시 | 의도된 복구 동작. 데이터 마이그레이션 불필요 |
| 롤백 시 둘 다 꺼진 상태 잠김 | 가드만 되돌리면 접근 불가 | 롤백 커밋에는 "둘 다 꺼져 있으면 메뉴바 강제 복원"을 포함 |

- 롤백: 착수 전 커밋 `9154022` 기준. 문제 시 revert 1커밋 + 위 마이그레이션 추가

## 8. 완료 기준 (Acceptance)
- [ ] 메뉴바·Dock 아이콘을 모두 꺼도 전역 단축키(⌥A·⌥'·⌥S·⌥])가 동작한다
- [ ] 아이콘이 모두 꺼진 상태에서 `.app`을 다시 열면 설정 창이 열린다
- [ ] 아이콘이 하나라도 켜져 있으면 재실행 시 기존처럼 보이는 창을 앞으로 가져온다
- [ ] 설정 창에서 ApexKey를 종료할 수 있다
- [ ] 마지막 아이콘을 끌 때 1회 확인 알림이 뜨고, 취소하면 상태가 유지된다
- [ ] 로그인 자동 시작에서는 설정 창이 자동으로 뜨지 않는다
- [ ] smoke+unit 통과, 빌드 성공, `[ERROR]` 0건
- [ ] i18n 키 누락 0 (en=ko)

## 9. 실측 근거
- PopClip 공식 가이드: "Open the Settings window at any time by relaunching PopClip (from Finder, Spotlight, etc.)"
- PopClip 2025.9 릴리스: 메뉴바 아이콘을 영구히 숨기고 설정 창이 모든 기능(종료 포함)을 대체
- 로컬 프로브(2026-11-19): `LSUIElement=1` + `.accessory` + 상태 아이템/창 없음 → 두 번째 `open`에서 같은 pid로 `applicationShouldHandleReopen(flag=false)` 수신, 창이 key/active가 됨(policy는 accessory 유지)
- ApexKey 코드: `HotKeyService`는 `NSStatusItem`을 참조하지 않음 → 아이콘 제거와 단축키 등록은 독립

## 10. 예외 규칙
- 없음. 제품 동결 기준 "실사용 마찰 개선"으로 분류한다(신규 기능 아님).
