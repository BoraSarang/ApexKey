# AGENTS.local.md — ApexKey

> 공통 가이드: `/Users/lee/.config/opencode/AGENTS.md` 참조 (복사 금지)
> 프로젝트 특화 예외만 기술.

## 적용 플랫폼
- **macOS 전용** (SwiftUI + AppKit, xcodegen)

## 프로젝트 특화 규칙

### 빌드/테스트
- `./build_and_run.sh debug macos` — 빌드 + `~/Applications/ApexKey.app` 설치
- `xcodebuild` 사용 필수 (`swift build/test` 금지)
- xcodegen으로 `project.yml` → `.xcodeproj` 생성

### 구조
- `Sources/ApexKey/` — 앱 소스 (Views/Models/Services/Utils)
- `Sources/ApexKeyTests/` — unit 테스트
- `Resources/Assets.xcassets/` — AppIcon + MenuBarIcon

### 핵심 기술 제약
- **글로벌 핫키**: Carbon `RegisterEventHotKey` 사용 (CGEventTap은 확장 시에만)
- **타 앱 메뉴 실행**: ApplicationServices `AXUIElement` 사용
- **설정 저장**: SwiftData
- **MenuBar 앱**: Dock 미표시 (`LSUIElement`)

### 앱명 현지화
- 영문: ApexKey / 한글: 애펙스키
- `LSHasLocalizedDisplayName=true` + `ko.lproj/InfoPlist.strings` (UTF-16) 유지 필수
- 참고: `/Users/lee/Documents/AGENTS/misc/macos-localization.md`

### 번들ID
- `com.borasarang.ApexKey`

### 금지사항
- 다른 플랫폼 타깃 추가 금지 (macOS 전용)
- BundleIdentifier 변경 금지 (파괴적 변경 가드)
