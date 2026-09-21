# ACTION 전수 점검표 v1 (macOS) — P0 착수

> 생성: 2026-09-20 / 범위: `ActionType.allCases` 152종
> 판정 기준 — 성공: 정상+실패(오입력)+권한거부 케이스 모두 의도대로 / 실패: 크래시·무응답·성공 둔갑 / 개선: 문구·UI·대체안내 필요
> P0에서 `launchApp / appleScript / javaScriptForAutomation` 구현. 나머지는 P1~P4 예정.

## P0 — 앱 실행/스크립트 (이번 배치)

| 액션 | 상태 | 시나리오 | 성공 | 실패 | 개선 |
|---|---|---|---|---|---|
| launchApp 토글(Safari) | 구현됨 | Safari 지정 → 실행→전면이면 숨김→다시 활성화 | [ ] | [ ] | [ ] |
| launchApp 오타 bundleID | 구현됨 | `com.example.Nope` → `E-MAC-APP-4001` 실패 반환, 크래시 없음 | [ ] | [ ] | [ ] |
| launchApp 앱 미지정 | 구현됨 | bundleID+path 비움 → 실패 반환 + 안내 | [ ] | [ ] | [ ] |
| launchApp URL스킴 | 구현됨 | `obsidian://open` 입력 → 해당 앱 열림 (미설치 시 OS 경고, 크래시 없음) | [ ] | [ ] | [ ] |
| launchApp 인자 전달 | 구현됨 | `parsedArgs` 따옴표 케이스 (`--a "hello world"`) 단위테스트 + 실실행 | [ ] | [ ] | [ ] |
| launchApp 모드 3종 | 구현됨 | toggle/activate/launch 각 모드 동작 확인 | [ ] | [ ] | [ ] |
| launchApp 레거시 호환 | 구현됨 | 기존 `target=com.apple.Safari` 단계 → 그대로 토글 동작 | [ ] | [ ] | [ ] |
| launchApp 행 클릭 반영 | 구현됨 | 검색 결과 클릭 → 번들ID+경로 채움+검색어 초기화+목록 접기+선택 요약행 (재선택 시 잔재 없음) | [ ] | [ ] | [ ] |
| launchApp 목록 스크롤 | 구현됨 | 목록 높이 제한으로 내부 스크롤, 아래 필드 항상 가시, 개수 캡션 | [ ] | [ ] | [ ] |
| launchApp 초성 검색 | 구현됨 | PaletteMatch 적용 (초성·공백무시) | [ ] | [ ] | [ ] |
| keyCombo 전송 (⌥⌘L) | 구현됨 | 기록 버튼으로 ⌥⌘L 캡처 → 테스트 전송 → 활성 앱에 전달 | [ ] | [ ] | [ ] |
| keyCombo 잘못된 형식 | 구현됨 | 빈/잘못된 target → 실패 반환, 전송 없음 | [ ] | [ ] | [ ] |
| appleScript 정상 | 구현됨 | `tell application "Finder" to get name` → 성공+출력 변수 저장 | [ ] | [ ] | [ ] |
| appleScript 문법오류 | 구현됨 | 오류 스크립트 → 실패 반환+에러 메시지, 단계 중단 아님(후속 계속, success=false) | [ ] | [ ] | [ ] |
| appleScript 빈 입력 | 구현됨 | 빈 문자열 → 건너뜀+실패 반환 | [ ] | [ ] | [ ] |
| JXA 정상 | 구현됨 | `Application('Finder').name()` → 성공 | [ ] | [ ] | [ ] |
| JXA 오류 | 구현됨 | 오류 코드 → 실패 반환+stderr | [ ] | [ ] | [ ] |
| 변수 토큰 해석 | 구현됨 | bundleID에 `{clipboard}` 등 토큰 → 해석 후 실행 | [ ] | [ ] | [ ] |

## 명령 팔레트 (⌘⌥K, Quick Launcher 대체)

| 항목 | 상태 | 시나리오 | 성공 | 실패 | 개선 |
|---|---|---|---|---|---|
| 최근 실행 섹션 | 구현됨 | 동작 실행 후 빈 입력 팔레트 → 상위 5건 표시 | [ ] | [ ] | [ ] |
| 명령 6종 | 구현됨 | 새 동작·설정·패널·HUD·반복·중료 실행 확인 | [ ] | [ ] | [ ] |
| 동작/단축키 검색 | 구현됨 | 이름·초성 매칭, Enter 실행 | [ ] | [ ] | [ ] |
| 앱 검색·실행 | 구현됨 | 앱 이름 입력 → 매칭 앱 활성화 실행 | [ ] | [ ] | [ ] |
| 단축키 변경 | 구현됨 | 설정에서 팔레트 단축키 변경·되돌리기 | [ ] | [ ] | [ ] |
| 빈 입력 폴백 | 구현됨 | 실행 기록 없으면 고정 6종 표시 (빈 패널 방지) | [ ] | [ ] | [ ] |
| 단계 내용 검색 | 구현됨 | 2자 이상 → 단계 제목/대상/메모 매칭, 최대 8건, 선택 시 편집기 점프 | [ ] | [ ] | [ ] |
| 초성 하이라이트 | 구현됨 | 범위 기반 굵게 표시 (초성 질의 포함) | [ ] | [ ] | [ ] |

## P1 — 순수 로직 (예정, 38종)

| 액션 | 상태 | 시나리오 | 성공 | 실패 | 개선 |
|---|---|---|---|---|---|
| text / clipText / number | 미구현 | 입출력 변수 전달 | [ ] | [ ] | [ ] |
| dialog / getConfirmation | 미구현 | 확인/취소 분기 | [ ] | [ ] | [ ] |
| getClipboard / setClipboard / clipboardAction / variableDetail | 미구현 | 클립보드 왕복 | [ ] | [ ] | [ ] |
| dateFormatter / adjustDate / typeDateTime / date | 미구현 | 서식·연산 | [ ] | [ ] | [ ] |
| formatNumber / math / calculate / typeNumber / count / wordCount / measurement | 미구현 | 숫자 연산 | [ ] | [ ] | [ ] |
| hash / uuid / base64Encode / htmlToMarkdown | 미구현 | 인코딩 | [ ] | [ ] | [ ] |
| regex / matchText / replaceText / combineText / splitText / trimWhitespace / surroundText / changeCase / sort | 미구현 | 텍스트 연산 (빈 입력·잘못된 정규식 포함) | [ ] | [ ] | [ ] |
| getDictionary / listActions / outputDifference | 미구현 | 컬렉션 연산 | [ ] | [ ] | [ ] |
| translate / detectLanguage | 미구현 | 대체안내 포함 | [ ] | [ ] | [ ] |
| scanQRCode / recognizeText / recognizeAnimal | 미구현 | Vision + 이미지 없음 케이스 | [ ] | [ ] | [ ] |

## P2 — 파일/문서/출력 (예정, 30종)

`getFiles/moveFiles/renameFiles/extractArchive/externalStorage/fileActions/getAttachment/editDocument/textEditShortcut/setParagraphStyle/newDocument/viewDocument/drive/oneDrive/box/noteActions/createNote/newNote/newQuickNote/pdf/readTable/emailData/saveOutput/quickLook/wallpaper/screenshot/takeScreenshot/camera/rotateImage/cropImage/trimVideo/presentation` — 존재/미존재/덮어쓰기/권한거부 3종씩. `[ ]/[ ]/[ ]` (상세는 P2 착수 시 행 분리)

## P3 — 시스템/미디어/네트워크 (예정, 40종)

`moveToFront/wakeDisplay/clearRecents/preventSleep/darkMode/focusMode/network/bluetooth/timer/stopwatch/location/airDrop/setVolumeMedia/playMusic/playPodcast/tuneStation/radio/musicAndVideo/podcasts/viewPhotos/album/randomPhoto/slideshow/getLastPhoto/photos/moveMedia/bookmark/news/stocks/videoDownloader/map/transportation/webContent/webIntegration/documentsAndFiles/devicesAndSheet/createShortcutIcon/system 8종 회귀` — 정상/권한거부/외부도구 미설치 3종씩.

## P4 — 콘텐츠/AI/앱/자동화 (예정, 20종)

`mail/setMailBody/setMailRecipients/message/email/calendar/reminders/useModel/writingTool/imagePlayground/appIntent/appAction/findApp/automation/findAutomation/automationRun/trigger` + 흐름 회귀 — 계정없음/권한거부/모델불가 케이스 포함.

## 회귀 (기존 동작 보장)

`menuCommand/url/file/script/runScriptInShell/system/paste/wait/coordinateClick/pauseUntilInput/macro/ifElse/repeat/chooseFromMenu/runShortcut` — 기존 테스트 + 수동 스모크 유지.
