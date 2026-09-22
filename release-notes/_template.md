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
```

## 주의

- 제목·목록·굵기·코드는 앱 내 업데이트 시트에서 렌더링됩니다.
  (`###` 이하 제목, `-` 목록, `**굵게**`, `` `코드` ``, `>` 인용, ``` 코드블록 지원)
- 버전 번호 3곳(제목·DMG 파일명 2곳)을 빠뜨리지 마세요.
