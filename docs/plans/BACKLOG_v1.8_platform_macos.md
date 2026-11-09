# v1.8 플랫폼 백로그 (T-223)

> 작성: 2026-11-09 · 상태: **1건 완료 / 3건 사용자·환경 대기**
> 이 문서는 "지금 코드로 할 수 있는 것"과 "할 수 없는 것"을 분리해 기록한다.
> 대기 항목은 완료 기준과 재개 조건을 함께 적어, 다음 세션이 같은 조사를 반복하지 않게 한다.

## 1. 현황

| 항목 | 상태 | 막는 것 | 다음 행동 |
|---|---|---|---|
| 사용자 변수 이름 토큰 `{이름}` | **완료** | — | 없음 |
| macOS 14 런타임 실기 검증 | **대기** | macOS 14 실행 환경 없음 | 환경 확보 시 §2 절차 |
| Developer ID 서명·공증 | **대기** | Apple Developer Program 미가입 | 가입 후 §3 절차 |
| `error_message_ko.json` 규칙 조율 | **대기** | 프로젝트 밖 규칙 파일 결정 | 사용자 선택 §4 |

## 2. `{이름}` 사용자 변수 토큰 — 완료

**변경**: `VariableResolver`·`UseModelExecutor`의 해석 컨텍스트에 `variableNames: [String: UUID]`를 두고,
`ExecutionEngine.execute(shortcut:)`이 단축어의 **manual** 변수 이름을 실행 동안 등록한다.

| 동작 | 결과 |
|---|---|
| `{인사}` (manual 변수, 값 있음) | 값으로 치환 |
| 값이 아직 없음 | 빈 문자열 (토큰이 남지 않음) |
| 숨김 변수(`isHidden`) | 등록하지 않음 — `{이름}`은 그대로 남음 |
| `{clipboard}` 등 특수 변수와 이름이 같음 | **특수 변수 우선** |
| 등록되지 않은 이름 | 원문 유지 |
| 중첩 단축어(`runShortcut`) | 안쪽 이름 표는 실행 후 되돌림 — 바깥으로 새지 않음 |
| 셸 스크립트 경로 | 기존 `escaping` 규칙 그대로 적용 |

**한계(의도)**
- magic·special 변수는 이름 토큰 대상이 아니다. 각자의 토큰(`{마법변수:...}`, `{clipboard}`)을 쓴다.
- 같은 이름의 manual 변수가 둘이면 **나중에 정의된 변수**가 이긴다. 현재 UI는 이름 중복을 막지 않는다.
- `resolveText`는 `{UUID}` 형태의 bare UUID 토큰을 치환하지 않는다(기존 동작). UUID 해석은 `resolveToken` 경로다.

**검증**: `Sources/ApexKeyTests/VariableNameTokenTests.swift` — 해석 9건 + 엔진 배선 3건.

## 3. macOS 14 런타임 실기 검증 — 대기

**막는 것**: 이 저장소의 빌드 환경은 최신 SDK이고, macOS 14 런타임 기기가 없다.
배포 타깃은 `project.yml`의 `MACOSX_DEPLOYMENT_TARGET: 14.0`이다.

**환경 확보 후 절차**

1. macOS 14 기기(또는 14 VM)에 Debug 빌드를 설치한다.
2. 아래 경로를 순서대로 확인하고 `docs/FUNCTIONAL_CHECKLIST.md` §8에 체크한다.
   - 전역 핫키 등록·충돌 표시·메뉴바 HUD
   - 트랙패드 모듈(기본 꺼짐 · 켠 뒤 제스처 · 경계 가드)
   - 자동화 트리거: 시간·폴더(FSEvent)·파일·외장 드라이브·디스플레이·배터리
   - 새 권한: 카메라(T-220), 자동화(T-195). 거부 시 사유 문구 확인
   - T-219 Wi-Fi 상태/켜기·끄기, 집중 모드 단축어
   - T-221 메시지·메일 초안·지도·Keynote·아이콘 생성
   - T-222 Shortcuts 실행·자동화 목록·즉시 실행
3. 14에서만 실패하는 API가 있으면 `Available:` 가드로 감싸고, **미지원 사유를 사용자 문구로** 돌려준다.
4. 결과를 `docs/STATUS.md`의 "지원 범위"에 반영한다.

**완료 기준**: 위 체크리스트 전 항목 확인, 실패 항목은 가드 + 사유 문구 + 문서 기록.

## 4. Developer ID 서명·공증 — 대기

**막는 것**: Apple Developer Program 가입이 선행돼야 한다(계정·결제는 사용자만 가능).

**가입 후 절차**

1. `release.yml`의 `CODE_SIGNING_ALLOWED=NO`를 해제한다.
2. `CODE_SIGN_IDENTITY="Developer ID Application"`, `DEVELOPMENT_TEAM`을 CI 시크릿으로 주입한다.
3. `notarytool submit --wait` → `stapler staple` 순서로 공증·스테이플한다.
4. Gatekeeper 통과를 새 macOS 사용자 계정에서 확인한다(quarantine 포함).

**완료 기준**: GitHub Releases의 zip/dmg가 서명·공증되고, 첫 실행 경고가 없다.

## 5. `error_message_ko.json` 규칙 조율 — 대기

**막는 것**: `~/.config/opencode/rules/quality.md`는 프로젝트 밖 파일이라 사용자 지시 없이 수정하지 않는다.
현재 앱은 `Localizable.strings`의 `error.user.*`(ko/en)를 쓴다.

**선택지** (상세: `docs/OPEN_ITEMS.md` §4)
- (a) 규칙에 "ko/en 통합 strings를 쓴다" 예외 조항 추가 ← 권장
- (b) `error_message_ko.json` 신설 후 빌드에서 strings로 변환

**완료 기준**: 사용자가 (a)/(b)를 결정하고, 결정에 맞춰 규칙 또는 생성 스크립트를 반영.

## 6. 영구 제외 재확인

아래 4종은 2026-11-09 확정대로 **구현하지 않는다**. `isCatalogHidden`으로 카탈로그에서 숨기고,
구현 상태는 `planned`로 남겨 "다음 버전" 목록에 다시 뜨지 않게 한다.

`videoDownloader` · `airDrop` · `clearRecents` · `bluetooth`

AI 3종(`useModel`·`writingTool`·`imagePlayground`)은 2026-10-06 무효화 상태를 유지한다.
