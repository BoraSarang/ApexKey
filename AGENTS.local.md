# AGENTS.local.md — ApexKey

> 공통 가이드: `/Users/lee/.config/opencode/AGENTS.md` 참조 (복사 금지)
> 프로젝트 특화 예외만 기술. (2026-10-06: 루트 `AGENTS.md`는 전역 규칙 "프로젝트 루트 생성 금지"에 따라 본 파일로 병합 후 삭제)

## 적용 플랫폼
- **macOS 전용** (SwiftUI + AppKit, Swift 5.9, macOS 14+, xcodegen)

## 빌드/테스트 (이것만 사용)
- `xcodegen generate --spec project.yml` — `.xcodeproj`는 gitignore, 항상 먼저 재생성
- `./build_and_run.sh debug macos` — 빌드 + `~/Applications` 설치 + 재시작
- `./build_and_run.sh test macos unit` — smoke(빠른 부분집합) | unit(기본, 전체) | full
- `xcodebuild`만 사용 (`swift build/test` 금지)
- 단일 테스트: `xcodebuild test -project ApexKey.xcodeproj -scheme ApexKey -destination 'platform=macOS' -only-testing:ApexKeyTests/<Suite>/<test>`
- 로컬 서명 `DEVELOPMENT_TEAM=6GPJQ7BQC9` 유지 (ad-hoc은 TCC/접근성 권한 초기화). CI는 `CODE_SIGNING_ALLOWED=NO`라 권한 의존 테스트는 로컬 통과≠CI 통과 (`MenuActionPathTests`는 `XCTSkipUnless`로 스킵)
- 새 코드는 클린 빌드로 경고 확인 — 점진 빌드는 경고를 숨김

## 게이트 (build_and_run.sh 자동 실행, 실패 시 빌드 중단)
- `scripts/check-localizable.py` — UI 문자열은 `.localized` 필수. `Sources/ApexKey/`만 스캔(테스트 제외). 허용목록은 스크립트 헤더 참조
- **가드는 키 존재를 검사하지 않음.** `Localizable.strings` 누락 키는 통과 후 UI에 원문 노출. 신규 문구는 en+ko 동시 추가
- `scripts/check-version.py` — 버전 단일 출처 `project.yml` `MARKETING_VERSION`. `Info.plist` 직접 편집 금지 (`$(MARKETING_VERSION)` 참조 유지)

## 릴리스
- 태그 `vX.Y.Z` == `MARKETING_VERSION` (다르면 `release.yml` 실패). 절차: 버전 수정 → 커밋 → 태그
- 본문: `release-notes/<tag>.md`, 없으면 자동 생성. 산출물 `ApexKey-<버전>-macOS.dmg` 단일
- 릴리스는 미서명/미공증: 첫 실행 우클릭→열기, 버전업마다 접근성 재승인 (결함 아님)

## 구조
- 진입: `Sources/ApexKey/main.swift` → `AppDelegate` (`AppDelegate+*.swift` 분리). `LSUIElement=true`, Dock 미표시
- `Sources/ApexKey/`: `Views/` (SwiftUI 패널/HUD), `Models/`, `Services/` (`HotKeyService`, `MenuEnumerator`, `ExecutionEngine`, `ActionExecutor`, `ConfigStore/`), `Utils/`
- `Sources/ApexKeyTests/` — `ApexKey` 타겟 의존 unit 테스트

## 핵심 기술 제약
- **글로벌 핫키**: Carbon `RegisterEventHotKey` (CGEventTap은 확장 시에만)
- **타 앱 메뉴 실행**: AppleScript/System Events + `AXUIElement` 열거 (접근성 권한 필요)
- **설정 저장**: SwiftData, 전용 경로 `~/Library/Application Support/com.borasarang.ApexKey/` (기본 공유 경로 충돌 회피)
- **메뉴바 앱**: Dock 미표시 (`LSUIElement`)

## 앱명 현지화
- 영문: ApexKey / 한글: 애펙스키
- `LSHasLocalizedDisplayName=true` + `ko.lproj/InfoPlist.strings` (UTF-16) 유지 필수
- 참고: `/Users/lee/Documents/AGENTS/misc/macos-localization.md`

## 제품 방향 (v1.4 이후)
- 신규 기능 동결. 버그 수정 + 실사용 마찰 개선만. 메뉴바 상주 가벼움 유지는 기능과 동급

## 문서
- `docs/README.md`(색인) → `docs/STATUS.md`(현황) → `docs/OPEN_ITEMS.md`(에이전트 불가 목록). `FUNCTIONAL_CHECKLIST.md`는 낡은 감사 스냅샷이라 코드와 대조 필수. `T-` 추적은 `docs/TODO.md` (`[~]` = 폐기, 되살리기 금지)

## 번들ID
- `com.borasarang.ApexKey`

## 금지사항
- 다른 플랫폼 타깃 추가 금지 (macOS 전용)
- BundleIdentifier 변경 금지 (파괴적 변경 가드)
- 디버그 패널(`showDebugPanel`/우클릭 메뉴/토스트 탭)은 `#if DEBUG` 게이트 — 릴리스 노출 금지
