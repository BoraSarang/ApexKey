# PLAN_v0.33_trackpad-gestures — 트랙패드 제스처 (에지 슬라이더 + 제스처→액션)

> status: **계획 (2026-11-08)** — 스파이크 완료, 사용자 승인 대기
> 근거: `docs/plans/SPIKE_v0.33_trackpad.md` (실측 7항목 통과)
> 사용자 요청: "트랙패드 오른쪽에서 두 손가락으로 볼륨", "특정 동작을 단축키/행위와 연결"
> 제약(사용자 확정): **서명·공증 없음(영구)**, **무료 + MIT**, **GitHub Releases 배포**

## 0. 결론 — 범위

ApexKey에 **입력 소스 하나**를 추가한다. 액션·워크플로우·설정·릴리스 체계는 기존 것을 그대로 쓴다.

| 구분 | 포함 | 제외 |
|---|---|---|
| **P0 (v0.33)** | 에지 슬라이더(볼륨), 제스처→액션(탭·스와이프), 스크롤 억제, 트랙패드 스테이션, 라이브 미리보기, HUD | — |
| **P1 (v0.34)** | 밝기 슬라이더, 회전 다이얼, TipTap, 앱별 프로필, 프리셋 내보내기 | — |
| **영구 제외** | Magic Mouse 제스처, 키보드 리매핑 확대, 그리기 제스처, 제스처 통계, App Store | — |

**핵심 결정 3개**
1. **새 권한 없음** — 읽기는 비공개 프레임워크(TCC 불필요), 억제·합성은 기존 Accessibility 재사용. Input Monitoring 요구 금지.
2. **기본 꺼짐** — 사용자가 켜야 권한·기능이 활성. 꺼진 상태에서 유휴 비용 0.
3. **폴더 격리 + 경계 검사** — `Sources/ApexKey/Trackpad/`만 비공개 API를 만진다. 코어는 `GestureEvent` 프로토콜만 안다. `scripts/check-trackpad-boundary.py`로 강제.

## 1. 사용자 시나리오 (P0 완료 기준)

1. 설정 → **트랙패드** 탭 → 마스터 스위치 ON (이미 Accessibility 승인돼 있으면 추가 승인 없음)
2. 기본 규칙이 자동 생성된다: `오른쪽 에지 · 두 손가락 · 세로 · 볼륨`
3. 트랙패드 오른쪽 끝에서 두 손가락을 위로 → 볼륨 상승 + HUD, 아래로 → 하강
4. 같은 순간 문서는 **스크롤되지 않는다**(억제)
5. "세 손가락 탭" 규칙 추가 → 기존 워크플로우(예: 터미널에서 열기) 선택 → 탭하면 실행
6. 앱을 껐다 켜도 설정 유지. 기능을 끄면 트랙패드는 원래대로.

## 2. 아키텍처

```
┌─ Sources/ApexKey/Trackpad/ ────────────────────────────┐
│  MultitouchSource   (dlopen, 디바이스, 프레임 콜백)      │
│  TouchNormalizer    (좌표·압력·손가락 ID)                │
│  EdgeZone           (에지 영역 판정)                     │
│  GestureRecognizer  (상태머신: tap/swipe/edgeSlide)      │
│  ScrollSuppressor   (CGEventTap, 타임아웃 복구)          │
└───────────────┬────────────────────────────────────────┘
                │  GestureEvent (enum, 순수 값)
┌───────────────▼────────────────────────────────────────┐
│  GestureRouter (Services/)                              │
│    ├ EdgeSliderAction  → SystemVolume / (P1) Brightness│
│    └ ShortcutAction    → ExecutionEngine.execute(...)   │
└─────────────────────────────────────────────────────────┘
```

- **의존 방향**: Trackpad → (없음). Router → Trackpad + Engine. **Engine은 Trackpad를 모른다.**
- 비공개 API는 `MultitouchSource.swift` **한 파일**에만 존재한다. 다른 파일에서 `dlopen` 금지.
- 로드 실패·심볼 부재 시 `isAvailable = false` → 트랙패드 스테이션에 "이 macOS에서 사용할 수 없음" 카드, 앱은 정상.

### 파일 계획

| 파일 | 역할 | 신규/수정 |
|---|---|---|
| `Trackpad/MultitouchSource.swift` | dlopen·디바이스·콜백 | 신규 |
| `Trackpad/TouchFrame.swift` | 프레임 값 타입, 정규화 | 신규 |
| `Trackpad/EdgeZone.swift` | 에지·엄지 무시 영역 | 신규 |
| `Trackpad/GestureRecognizer.swift` | 상태머신 | 신규 |
| `Trackpad/ScrollSuppressor.swift` | 이벤트 탭 | 신규 |
| `Trackpad/TrackpadEngine.swift` | 조립·수명주기·실패 격리 | 신규 |
| `Services/GestureRouter.swift` | 이벤트 → 액션 | 신규 |
| `Services/SystemVolume.swift` | CoreAudio 증분 | 신규 |
| `Models/GestureConfig.swift` | 규칙 모델 | 신규 |
| `Views/TrackpadView.swift` | 트랙패드 스테이션(목록·미리보기·권한) | 신규 |
| `Views/TrackpadRuleSheets.swift` | 슬라이더/제스처 편집 시트 | 신규 |
| `Views/TrackpadPreviewView.swift` | 라이브 미리보기 | 신규 |
| `Services/ConfigStore.swift` | 규칙 저장 | 수정 |
| `AppDelegate+*.swift` | 엔진 시작/중지 | 수정 |
| `project.yml` | 프레임워크 3종 링크 | 수정 |
| `scripts/check-trackpad-boundary.py` | 경계 검사 | 신규 |

## 3. 데이터 모델

```swift
struct GestureConfig: Codable {
    var isEnabled: Bool          // 기본 false
    var edgeSliders: [EdgeSliderRule]
    var gestures: [GestureRule]
    var advanced: Advanced       // 임계값·쿨다운·엄지 무시
}

struct EdgeSliderRule: Codable, Identifiable {
    var id: UUID
    var edge: Edge               // .left .right .top .bottom
    var fingerCount: Int         // 1...3
    var axis: Axis               // .vertical .horizontal
    var target: SliderTarget     // .volume | .brightness(P1) | .shortcut(UUID)
    var sensitivity: Double      // 0.5...2.0
    var isInverted: Bool
    var isEnabled: Bool
}

struct GestureRule: Codable, Identifiable {
    var id: UUID
    var gesture: GestureKind     // .tap(fingers) .swipe(fingers, direction) .tipTap(P1) .dial(P1)
    var action: GestureAction    // .shortcut(UUID) | .system(SystemActionType)
    var scope: Scope             // .global | .apps([String])
    var isEnabled: Bool
}
```

저장은 기존 `ConfigStore` 경로(`~/Library/Application Support/com.borasarang.ApexKey/`)에 JSON 1파일.
**`ShortcutStep` 필드 추가 금지**(E-MAC-STORE-5008) — 제스처는 별도 모델로 두고 `Shortcut`을 **참조**만 한다.

## 4. 인식 규칙 (P0)

| 규칙 | 값 | 이유 |
|---|---|---|
| 에지 폭 | 기본 12% (조절 가능) | 실측 정규화 좌표 기준, 오탐/미탐 균형 |
| 에지 진입 | 손가락 **전부**가 에지 안 | 일부만 걸치면 스크롤로 오인 |
| 활성화 | 세로 이동 누적 **> 6%** | 미세 떨림 무시 |
| 방향 확정 | 첫 3프레임 이동 부호 | 시작 떨림 방지 |
| 재트리거 | 연속 모드, 12%마다 1스텝 | "한 번 스와이프 = 한 단계" 문제 해결 |
| 쿨다운 | 250ms | 중복 실행 방지 |
| 엄지 무시 | 하단 15% 기본 ON | 팜 리젝트 |
| 손가락 수 변경 | 제스처 중 변경 시 즉시 종료 | 상태 오염 방지 |

상태머신: `idle → tracking(n) → edgeActive → (slider) → ended → cooldown → idle`
- `tracking`에서 3프레임 내 조건 불충족 시 `idle` 복귀
- 앱 전환·화면 잠금·디바이스 분리 시 강제 `idle`

## 5. 억제(Suppression)

- `CGEventTap(.cgSessionEventTap, .headInsertEventTap, .defaultTap)` — 스크롤 이벤트만
- 에지 슬라이더 **활성 중에만** 이벤트를 `nil` 반환으로 소비
- 탭 비활성(`kCGEventTapDisabledByTimeout`) 수신 시 **즉시 재활성**, 3회 연속 실패 시 기능 OFF + 토스트
- 앱 종료·잠자기 진입 시 탭 해제. 해제 실패 대비 `applicationWillTerminate`에서 명시적 정리
- **억제는 에지 슬라이더에만 적용**한다. 일반 제스처(탭·스와이프)는 억제하지 않는다(오작동 반경 최소화)

## 6. 액션 연결

| 슬라이더 대상 | 구현 |
|---|---|
| 볼륨 | CoreAudio `VirtualMainVolume` 읽기 → 증분 → 쓰기. **0.0~1.0 클램프**, 1% 미만 변화 무시 |
| 밝기 (P1) | `DisplayServices` (비공개) — 별도 dlopen, 실패 시 항목 숨김 |
| 단축키(커스텀) | 임계값당 1회 `ExecutionEngine.execute(shortcut)` |

- 볼륨 HUD: 기존 HUD 스타일 재사용. 0.8초 후 자동 소멸.
- 실행 실패는 **무음 금지** — 기존 토스트 경로로 사유 표시.

### 6.1 제스처 실행 대상 — 기존 자산 재사용

| 대상 | 구현 | 새 코드 |
|---|---|---|
| 워크플로우 | `ExecutionEngine.execute(steps:)` | 없음 |
| 단축키 | `ExecutionEngine.execute(shortcut)` | 없음 |
| **메뉴 항목** | `ShortcutStep(type: .menuCommand, target: 번들ID, title: 항목명, menuPath: [...])` → 기존 `MenuEnumerator.performAction` | **없음** (설정 UI만 추가) |
| 시스템 액션 | `SystemActionExecutor.execute(type)` | 볼륨 ±만 추가 |

- **메뉴 항목이 핵심**: Safari › 보기 › 번역 › 한국어로 번역 같은 메뉴를 **워크플로우/단축키를 만들지 않고** 바로 연결한다.
  `MenuCommandSettingsView`와 같은 UX(앱 피커 → 메뉴 트리)를 시트에 내장한다.
- 실행 전제: 대상 앱 실행 중 + Accessibility. 비활성 메뉴는 실행 실패 → 토스트로 사유 표시.
- **시스템 액션 확장**: `SystemActionType`에 `volumeUp`/`volumeDown` 추가(현재 `mute`만 있음).
  구현은 `SystemVolume`(T-200) 하나로 공유 — 에지 슬라이더와 제스처가 같은 코드를 쓴다.
- 설정이 필요한 액션(URL·파일·스크립트·텍스트)은 제스처에 직접 붙이지 않고 **워크플로우로 감싼다**(입력은 단계에서 받는다).

## 7. 설정 UI (트랙패드 스테이션)

```
[트랙패드]  (사이드바 '도구' 섹션, 워크플로우와 자동화 사이 · 아이콘: rectangle.and.hand.point.up.left)
├ 마스터 토글(헤더 우측) + 상태 배지 (사용 가능 / 권한 필요 / 이 macOS 미지원)
├ 라이브 미리보기 — 트랙패드 그림 + 손가락 점 + 에지 하이라이트
├ 에지 슬라이더  [ + 추가 ] → 시트: 위치 · 손가락 수 · 축(자동) · 대상 · 감도 · 반전 · 인식/억제
├ 제스처  [ + 추가 ] → 시트: 종류 · 손가락 수 · 방향 · 반복 · 실행 대상 · 범위(전역/앱)
└ 고급: 에지 폭 · 임계값 · 쿨다운 · 엄지 무시 · 초기화
```

- 배치 이유: 자동화는 아직 세부 구성을 다시 할 예정이라 **자동화 위**에 둔다. (2026-11-08 사용자 결정)
- `+`는 추가/편집 **시트**로 열고, 저장 전까지 목록을 바꾸지 않는다(취소 = 무변경).
- 슬라이더 시트 상단: 요약 1줄 + 미니 트랙패드(클릭으로 에지 선택, 드래그로 값 데모).
- 규칙 0개면 "기본 규칙 만들기" 버튼 1개(우측 에지·2손가락·볼륨)
- 권한 카드는 **Accessibility만** 표시. Input Monitoring 문구는 넣지 않는다.
- 미리보기는 엔진이 켜져 있을 때만 실시간, 꺼져 있으면 정적 안내.

## 8. 테스트 전략

아날로그 입력은 unit test가 안 된다 → **3층**으로 나눈다.

| 층 | 방법 | 예산 |
|---|---|---|
| 단위 | `EdgeZone` 판정, 상태머신 전이, 설정 인코딩/디코딩, 볼륨 클램프 | ≤10s |
| 리플레이 | 스파이크에서 채집한 터치 프레임을 JSON fixture로 재생 → 기대 이벤트 시퀀스 비교 | ≤30s |
| 통합 | 디버그 훅(`GestureRecognizer.feed(frame:)`)으로 합성 주입 → 액션 호출 스파이 검증 | ≤60s |

- 실기 확인은 사용자 1회(에지 스와이프 + 스크롤 억제 체감) — `FUNCTIONAL_CHECKLIST`에 항목 추가
- 573건 기존 테스트는 **건드리지 않는다**. 신규는 `ApexKeyTests/Trackpad*`로 분리

## 9. 성능 예산 (회귀 = 버그)

| 지표 | 목표 | 측정 |
|---|---|---|
| 유휴 CPU | **0.0%** (터치 없을 때 콜백 없음) | Activity Monitor 10초 샘플 |
| 유휴 wakeups | 증가 0 | `powermetrics` 또는 `top -o cpu` |
| 메모리 | +15MB 이내 | Instruments |
| 제스처 반응 | < 30ms (프레임→HUD) | 로그 타임스탬프 |
| 앱 크기 | +0.5MB 이내 | dmg 비교 |

## 10. 작업 목록

| # | 작업 | 예상 |
|:-:|---|---|
| T-196 | 스파이크 재현 + 터치 fixture 채집 | 0.5d |
| T-197 | `Trackpad/` 뼈대: 소스·프레임·실패 격리 | 1d |
| T-198 | `EdgeZone` + `GestureRecognizer` 상태머신 | 2d |
| T-199 | `ScrollSuppressor` (탭 수명주기·타임아웃 복구) | 1d |
| T-200 | `SystemVolume` (CoreAudio 증분) + `SystemActionType.volumeUp/volumeDown` | 0.75d |
| T-201 | `GestureRouter` → `ExecutionEngine` 연결 (메뉴 명령 포함) | 1.25d |
| T-202 | `GestureConfig` + `ConfigStore` 저장 | 0.5d |
| T-203 | 트랙패드 스테이션 UI (미리보기·목록·권한 카드) | 2d |
| T-203b | 슬라이더·제스처 편집 시트 (+ 상세 옵션) | 1.5d |
| T-204 | 라이브 미리보기 | 1d |
| T-205 | 볼륨 HUD | 0.5d |
| T-206 | 경계 검사 스크립트 + 빌드 게이트 연결 | 0.5d |
| T-207 | fixture 리플레이 + 단위 테스트 | 1d |
| T-208 | 성능 예산 측정 + 문서화 | 0.5d |
| | **합계** | **약 13.5일 (2.8주)** |

P1(v0.34): 밝기·다이얼·TipTap·앱별 프로필·프리셋 — 약 7일.

## 11. 리스크

| 리스크 | 확률 | 완화 |
|---|---|---|
| macOS 업데이트로 심볼/레이아웃 변경 | 중 | 화이트리스트 심볼, 실패 시 기능 OFF, 시작 시 자가진단 |
| 스크롤 억제가 특정 앱에서 안 먹음 | 중 | 훅이 아닌 탭 방식 유지, 앱별 예외 목록(고급) |
| 권한 재승인 후 기능 조용히 죽음 | 높음(미서명) | 스테이션에 상태 배지 + 시작 시 `AXIsProcessTrusted` 검사 + 토스트 |
| 에지 오탐으로 일상 스크롤 방해 | 중 | 기본 폭 12%, 엄지 무시 ON, "잠시 끄기" 메뉴 |
| 억제 중 앱 멈춤 체감 | 낮 | 에지 슬라이더에만 적용, 3회 실패 시 자동 OFF |

## 12. DoD

- [ ] 새 권한 요구 0건 (Accessibility만)
- [ ] 기능 OFF 상태 유휴 CPU 0.0%, 메모리 +15MB 이내
- [ ] 에지 슬라이더 실기 1회 + 스크롤 억제 체감 확인(사용자)
- [ ] fixture 리플레이·단위 테스트 통과, 기존 573건 무회귀
- [ ] `check-trackpad-boundary.py` 통과 (코어가 Trackpad를 참조하지 않음)
- [ ] i18n en/ko 동시 추가, `check-localizable` 통과
- [ ] 트랙패드 스테이션 도움말(뭐고·언제·이렇게) 3줄 포함
- [ ] CHANGELOG·STATUS·TODO·README 수치 갱신
- [ ] 기능 실패 시 사유 토스트(무음 실패 금지)

## 13. 이번에 하지 않는 것 (명시)

- Magic Mouse 제스처 — 다른 하드웨어, P1에서도 제외
- 키보드 리매핑 확대 — 기존 Carbon 핫키 범위 유지
- 그리기 제스처 — P2 이후, 별도 승인 필요
- 제스처 통계·자동 업데이트 — 제품 방향 밖
- 서명·공증 — 사용자 확정으로 영구 제외
