<div align="center">

# ⌨️ ApexKey

**전역 핫키 기반 macOS 메뉴바 런처 — 어떤 앱의 메뉴 명령도 단축키로.**

[English](README.en.md) · [랜딩 페이지](https://borasarang.github.io/ApexKey/)

![macOS](https://img.shields.io/badge/macOS-14.0+-333333?logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white)
[![release](https://img.shields.io/github/v/release/BoraSarang/ApexKey)](https://github.com/BoraSarang/ApexKey/releases)

</div>

---

## 소개

ApexKey는 **메뉴바에 상주**하며, 화면 어디에서나 전역 단축키로 다른 앱의 **메뉴 명령을 바로 실행**할 수 있게 해주는 macOS 유틸리티입니다.

- 실행 중인 앱의 **메뉴를 열거**해 그중 원하는 명령에 **글로벌 핫키를 지정**
- 앱 실행·토글, **URL scheme 열기**, 나만의 **동작(단계 조합)**, **시스템 액션**, 스크립트 실행 지원
- **메뉴 단축키 HUD** — 현재 앱의 모든 단축키를 한눈에 표시
- 8가지 내장 테마 + 라이트/다크/시스템 + 외형 모드 자동 전환

## 주요 기능

| 영역 | 기능 |
|------|------|
| **메뉴 명령 단축키** | 실행 중인 앱의 메뉴 항목에 전역 단축키 할당 → 어디서든 실행 |
| **앱 실행/토글** | 특정 앱을 실행·포커스·토글하는 단축키 |
| **URL Scheme** | `scheme://` 열기 단축키 |
| **동작(Shortcut) 스테이션** | 앱 열기·키 입력·스크립트·붙여넣기·대기·클릭 등을 **단계**로 쌓아 하나의 동작으로 |
| **흐름 제어** | If/반복/메뉴 선택, 변수, 출력-변수 연결 |
| **자동화** | 시간·폴더·전원 등 조건 기반 트리거 |
| **AI 실행** | 모델 사용, 라이팅 툴, 이미지 생성 단계 |
| **시스템 액션** | 잠금, 볼륨, 다크 모드 등 |
| **메뉴 단축키 HUD** | 전체화면/플로팅으로 현재 앱 단축키 표시 |
| **테마** | 라이트·다크·네온·노드·페이퍼·터미널·오사우루스 등 8종 내장 + 폰트 크기 조절 |

## 설치

### Homebrew (준비 중)

```bash
brew install --cask borasarang/tap/apexkey   # 예정
```

### 수동 설치

1. [Releases](https://github.com/BoraSarang/ApexKey/releases)에서 최신 `.dmg` 또는 `.zip` 다운로드
2. 다운로드한 `ApexKey` 앱을 `응용 프로그램` 폴더로 이동
3. **시스템 설정 → 개인정보 보호 → 손쉬운 사용**에서 ApexKey 허용 (메뉴 열거·실행에 필요)

> **요구사항**: macOS 14(Sonoma) 이상 · Apple Silicon 또는 Intel

## 사용법

- 메뉴바의 ApexKey 아이콘으로 패널 열기 (기본 단축키 `⇧⌥A`)
- 앱 상세에서 **메뉴 명령에 `+`** 를 눌러 글로벌 단축키 녹음
- **메뉴 단축키 HUD** (`⇧⌥S`)로 현재 앱의 단축키 목록 확인
- **동작** 탭에서 여러 단계를 조합해 나만의 동작 생성

## 빌드 (개발자)

```bash
# 1. xcodegen 설치 (필요시)
brew install xcodegen

# 2. 프로젝트 생성
xcodegen generate --spec project.yml

# 3. 빌드 + 테스트 (build_and_run.sh)
./build_and_run.sh debug macos
./build_and_run.sh test macos unit
```

> `.xcodeproj`는 커밋에 포함되지 않으며 `xcodegen`으로 생성합니다. `build_and_run.sh test`는 smoke/unit/full 스코프를 지원합니다.

## 문서

- [변경 이력](docs/CHANGELOG.md)
- [할 일(TODO)](docs/TODO.md)
- [기능 점검 리스트](docs/FUNCTIONAL_CHECKLIST.md)
- [디자인 명세](docs/DESIGN.md)

## 라이선스

이 프로젝트의 코드는 [MIT](LICENSE) 라이선스로 배포됩니다.

## 감사의 말

- 테마 디자인 시스템 아이디어는 **Osaurus** 오픈소스에서 영감을 받았습니다.
- 셉터 아이콘은 SF Symbols(`command`, `bolt.fill`, `square.stack.3d.up.fill` 등)를 사용합니다.

---

<div align="center">
  <sub>Built with SwiftUI · AppKit · Carbon · XcodeGen</sub><br>
  <sub>© 2026 BoraSarang</sub>
</div>
