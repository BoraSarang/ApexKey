# PLAN v0.5 — 다국어 지원 (i18n)

> 작성일: 2026-09-16 · 플랫폼: macOS
> 목표: 설정에서 언어 선택(한국어/영어/시스템) → 앱 재시작 시 반영

## 1. 결정 사항 (사용자 확정)

| 항목 | 결정 |
|------|------|
| 언어 변경 반영 방식 | **앱 재시작** (표준, macOS 번들 리소스 제약) |
| 지원 언어 | **ko / en** (2개) — 추후 확장 대비 키 구조만 준비 |
| 번역 범위 | **전체 UI 문자열** (ActionType displayName 포함) — 메타데이터 테이블 연계 |

---

## 2. 아키텍처

```
Bundle.main → Localizable.strings (ko/en) ← LanguageManager.setLanguage(code?)
                                      ↓
                         UserDefaults.standard.set(["ko"], forKey: "AppleLanguages")
                                      ↓
                         앱 재시작 → Bundle.preferredLocalizations 갱신 → strings 반영
```

**핵심**: 런타임 swizzle 없이 `AppleLanguages` 키 + 재시작만으로 표준 준수.

---

## 3. 작업 분해

### Phase A — 인프라 (A-1 ~ A-3)

| ID | 작업 | 산출물 |
|----|------|--------|
| A-1 | `ko.lproj/Localizable.strings`, `en.lproj/Localizable.strings` 생성 (UTF-16) | 2개 파일 |
| A-2 | `LanguageManager` 싱글턴 신설 (`setLanguage(code:)`, `currentLanguageCode`, `supportedLanguages`) | `Sources/ApexKey/Services/LanguageManager.swift` |
| A-3 | `ConfigStore`에 `appLanguage: String?` 추가 (`nil`=시스템, `"ko"`, `"en"`), `setAppLanguage(_:)` → `LanguageManager.setLanguage` 위임 + 저장 | `ConfigStore+Preferences.swift` |

### Phase B — 설정 UI (B-1 ~ B-3)

| ID | 작업 | 산출물 |
|----|------|--------|
| B-1 | `SettingsView`에 "언어" 섹션 추가 — Picker(시스템/한국어/영어) | `SettingsView.swift` 수정 |
| B-2 | 선택 시 `store.setAppLanguage(code)` 호출 + 재시작 필요 배너 표시 | `SettingsView.swift` |
| B-3 | 재시작 버튼(선택) — `NSApp.terminate(nil)` 후 런처가 재실행? → **단순 안내만** (사용자가 직접 재시작) | 동일 파일 |

### Phase C — 문자열 분리 (C-1 ~ C-3)

| ID | 작업 | 범위 | 비고 |
|----|------|------|------|
| C-1 | 하드코딩 문자열 키 도출 스크립트 (`extract_strings.py`) | 전 View/모델 | 1회성 |
| C-2 | `ko.lproj/Localizable.strings` 작성 (기존 한글 매핑) | 설정/액션/알럿/토스트/ActionType 등 | 번역 불필요 |
| C-3 | `en.lproj/Localizable.strings` 작성 (영문 번역) | 동일 키 | 1차 번역 후 검수 |
| C-4 | SwiftUI `Text("key")` → `Text(localized: "key")` 일괄 치환 | 전체 코드베이스 | `sed`/`swift-format` 기반 |
| C-5 | `ActionMetadata` 연계 — `displayName`을 localizable 키로 교체, `systemImage`는 유지 | `ActionMetadata.swift` | 테이블화된 메타데이터와 통합 |

---

## 4. 키 네이밍 규칙 (확장 대비)

```
# 네임스페이스 접두사 + camelCase
settings.title
settings.display.show_in_menubar
settings.language.system
settings.language.korean
settings.language.english
settings.language.restart_required

action.launchApp
action.menuCommand
action.script
action.runScriptInShell
...

alert.menubar_cannot_disable.title
alert.menubar_cannot_disable.message
alert.restart_required

toast.hotkey_duplicate
toast.script_test_success
toast.script_test_failed
...

# ActionType은 action. 접두사 + enum rawValue 소문자
action.launchApp
action.menuCommand
action.dialog
action.text
...
```

---

## 5. 실행 순서 (의존성 순)

```
A-1 (files) → A-2 (LanguageManager) → A-3 (ConfigStore)
    ↓
B-1 (SettingsView 언어 섹션) → B-2/B-3 (저장+안내)
    ↓
C-1 (키 도출) → C-2 (ko 작성) → C-3 (en 작성) → C-4 (치환) → C-5 (ActionMetadata 연계)
```

**병렬 가능**: A-2/A-3는 독립, B-1은 A-3 이후, C-2/C-3는 독립.

---

## 6. 검증 게이트

| 단계 | 검증 |
|------|------|
| Phase A | `LanguageManager.currentLanguageCode`가 `nil/ko/en` 정확히 반환, 재시작 후 `Bundle.main.preferredLocalizations` 일치 |
| Phase B | 설정에서 언어 변경 → `UserDefaults AppleLanguages` 갱신 확인, 재시작 안내 배너 표시 |
| Phase C | `rg "Text\(\"[^\"]*[가-힣]"` 0건 (하드코딩 한글 제거), `rg "Text\(localized:"` 전수 사용, ko/en 양쪽 키 동일 개수 |
| 통합 | 언어 3회 전환(시스템→ko→en→시스템) 후 UI 전체 문자열 정확히 반영, 앱 재시작 1회만 필요 |

---

## 7. 리스크/대응

| 리스크 | 대응 |
|--------|------|
| 키 누락/오타로 빈 문자열 표시 | `extract_strings.py`가 Swift 소스에서 `Text("...")` 패턴 전수 추출 → 키 리스트와 대조 |
| ActionType 152개 displayName 번역 누락 | `ActionMetadata.displayName`을 `"action.\(rawValue)"` 키로 통일, C-5에서 자동 검증 |
| 재시작 안내 UX 누락 | B-2에서 변경 시 즉시 노란 배너 + "지금 재시작" 버튼(선택) 제공 |
| 시스템 언어(자동) 선택 시 OS 언어 따름 | `LanguageManager.currentLanguageCode`가 `nil`이면 `Bundle.main.preferredLocalizations.first` 사용 |

---

## 8. 예상 작업량

| 분류 | 파일 수 | 예상 라인 |
|------|--------|-----------|
| 신규 (LanguageManager, Localizable×2) | 4 | ~400 |
| 수정 (ConfigStore, SettingsView, ActionMetadata, 전체 View) | ~25 | ~3,000 치환 |
| 스크립트/도구 | 2 | ~200 |
| **합계** | **~31** | **~3,600** |

---

## 9. 다음 세션 시작 전 체크리스트

- [ ] `docs/plans/PLAN_v0.5_i18n.md` 저장됨
- [ ] `docs/TODO.md`에 Phase A~C T-번호 등록
- [ ] `extract_strings.py` 초안 준비 (키 추출 자동화용)

---

**준비되면 "진행" 한 마디로 Phase A부터 실행합니다.**
