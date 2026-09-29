# 릴리스 노트 작성 규칙 (ApexKey)

> `release.yml`이 `release-notes/<tag>.md` 파일을 찾으면 그 내용을
> GitHub Release 본문으로 사용합니다. 없으면 자동 생성 노트가 쓰입니다.
> 파일명: 태그 그대로 (예: `release-notes/v1.2.1.md`).
> `_template.md`(이 파일)는 본문에 포함되지 않습니다.

## 템플릿

```markdown
# ApexKey vX.Y.Z

## 새로운 기능

- ...

## 수정

- ...

## 설치 방법

1. 아래 `ApexKey-X.Y.Z-macOS.dmg`를 다운로드합니다.
2. DMG를 열어 ApexKey를 응용 프로그램 폴더로 드래그합니다.
3. 첫 실행 시 **우클릭 → 열기**로 실행하세요.
   (공증되지 않은 앱이라 Gatekeeper가 첫 실행을 차단합니다.)

## How to install

1. Download `ApexKey-X.Y.Z-macOS.dmg` below.
2. Drag ApexKey to Applications.
3. On first launch, **right-click → Open**.
   (Gatekeeper blocks unsigned apps on first launch.)

## 알려진 제약 (릴리스마다 포함)

> 배포본이 코드 서명·공증되지 않은 상태라 사용자가 반드시 겪는 동작입니다.
> 매번 복사해 넣으세요. 서명 도입 시 이 절을 삭제합니다.

### ⚠️ 릴리스는 코드 서명·공증되지 않았습니다

- **첫 실행 차단** — Gatekeeper가 앱을 막습니다. **우클릭 → 열기**로 우회하세요.
- **업데이트마다 접근성 권한 재승인** — 새 버전 설치 후에는
  시스템 설정 → 개인정보 보호 → 손쉬운 사용에서 ApexKey를 다시 켜야 합니다.
  macOS가 접근성 권한을 앱의 코드 서명(CDHash)에 묶어 두는데, 무서명 앱은 버전마다 이 값이
  바뀌어 권한이 자동 해제되기 때문입니다. Developer ID 서명·공증으로 해결됩니다.
```

## 주의

- 제목·목록·굵기·코드는 앱 내 업데이트 시트에서 렌더링됩니다.
  (`###` 이하 제목, `-` 목록, `**굵게**`, `` `코드` ``, `>` 인용, ``` 코드블록 지원)
- 버전 번호 3곳(제목·DMG 파일명 2곳)을 빠뜨리지 마세요.
- **서명 상태를 사실대로 적어야 합니다.** Gatekeeper 안내만 넣고 "권한 재승인"을
  누락하면 사용자가 버전업 후 메뉴가 동작하지 않는 이유를 알 수 없습니다.
