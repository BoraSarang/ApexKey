# PLAN_v0.22 — 무서명 릴리스 고지 정직화 (macOS)

> status: **done** · 2026-09-29 · 착수 계기: `docs/plans/SESSION_2026-09-27_handoff.md` §3 1순위

## 배경

1순위는 "무서명 릴리스"였다. 3가지 선택지가 있었고 사용자가 **(b) 릴리스 노트 문구를 정직하게
유지하고 무서명 사실을 명시**를 선택했다. (a) Developer ID 서명·공증은 Apple Developer
Program(연 $99) 가입이 선행이라 코드만으로 진행 불가, (c)는 (b)의 하위 집합이었다.

그래서 이번 세션의 범위는 **"무서명이라는 사실과 그것이 일으키는 사용자-visible한 불편을
정직하게 문서화한다"** 로 확정했다. 코드 변경 없음.

## 문제의 정확한 형태

T-029는 "ad-hoc 서명이 리빌드마다 다른 코드 identity를 만들어 TCC 권한이 유지되지 않는다"를
고쳐서 **고정 TeamID 자동 서명**으로 전환했다. 이 수정은 잘 작동한다 — **개발 빌드에서.**

문제는 배포본이다. `release.yml`이 `CODE_SIGNING_ALLOWED=NO`로 빌드하므로 릴리스.app는
서명이 없다. macOS TCC는 접근성 권한을 **코드 서명(CDHash)** 에 묶는데, 서명이 없는 앱은
버전마다 이 값이 새로 만들어진다. 따라서:

> **릴리스 사용자는 버전업할 때마다 손쉬운 사용 권한을 재승인해야 한다.**

그리고 `release-notes/_template.md`는 Gatekeeper 차단은 안내하면서 **이 더 큰 불편을
아무것도 쓰지 않았다.** 사용자는 "버그"라고 생각했을 것이다. 실제로는 배포 방식의 귀결이다.

## 수행 항목

| # | 항목 | 파일 |
|:-:|---|---|
| 1 | "⚠️ 서명 상태" 절 신설 — 증상 2종 표·대응·CDHash 원인·소스 빌드 안내. 설치 단계에 "첫 실행 우클릭→열기" 추가 | `README.ko.md`, `README.md` |
| 2 | "알려진 제약" 절 신설 — **릴리스마다 복사해 넣으라고 명시**(서명 도입 시 삭제). 작성 규칙에 누락 금지 조항 추가 | `release-notes/_template.md` |
| 3 | 다운로드 절에 고지 1문단. `.download-warn` 스타일 신설(`download-note`는 가운데 정렬 1줄용이라 4줄 경고에 부적합) | `website/ko/index.html`, `website/index.html`, `website/styles.css` |
| 4 | §6 감사 스냅샷 갱신 — **이미 해결된 T-146/T-147/T-164/T-165가 아직 🔴·⚠️로 표시**돼 있어 다음 세션이 중복 착수할 뻔했다. 커밋 해시와 함께 ✅로 갱신. §8-7도 상태 변경 | `docs/FUNCTIONAL_CHECKLIST.md` |
| 5 | v0.22 절 신규 — T-166 `[x]` + Developer ID 서명 후속을 **보류**로 명시 | `docs/TODO.md` |
| 6 | 변경 이력 기록 | `docs/CHANGELOG.md` |

## DoD

- [x] 릴리스 노트 템플릿에 "업데이트마다 권한 재승인"이 포함
- [x] README ko/en 설치 절에 Gatekeeper 우회법이 포함
- [x] 랜딩 ko/en에 고지 표시
- [x] HTML well-formed 검증 통과 (`download-warn` 2곳, 태그 불일치 0)
- [x] `build macos` 경고 0 · `test macos unit` **247건 0실패** (2 skip)
- [x] 코드 변경 0 — 리스크 없음

## 남는 것 (보류, T-166 후속)

Developer ID 서명 + notarization. Apple Developer Program 가입이 선행 조건이다.
가입 시 `release.yml`의 `CODE_SIGNING_ALLOWED=NO` 해제 → `CODE_SIGN_IDENTITY=Developer ID
Application` → `notarytool` → 이번에 만든 고지 4곳 정리, 그리고
`FUNCTIONAL_CHECKLIST.md` §6 "CI 서명 경로"도 함께 해결된다.
