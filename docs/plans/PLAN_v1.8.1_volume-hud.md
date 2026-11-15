# PLAN v1.8.1 — 시스템 볼륨 HUD (macOS)

> status: **구현·실기 확인 완료** (2026-11-15)
> 승인: 2026-11-15 사용자 — "A안으로 하고 mute도 동일하게 적용. 시스템 HUD가 나온다면 앱 볼륨 표시는 필요 없음"

## 1. 문제

워크플로/단축키의 **시스템 → 볼륨 올리기·내리기**는 볼륨이 바뀌지만 macOS의 볼륨 HUD(상단 우측 애니메이션)가 뜨지 않는다.

원인: `SystemActionExecutor`가 `SystemVolume`(CoreAudio `AudioObjectSetPropertyData`)로 값을 직접 바꾼다.
macOS의 볼륨 HUD는 **볼륨 값 변경이 아니라 하드웨어 미디어 키 이벤트**에 반응해 `MenuBarAgent`가 그린다.
AppleScript `set volume`, 참고 스크립트의 `display notification`도 같은 이유로 시스템 HUD를 띄우지 못한다.

## 2. 실측 (2026-11-15, macOS 27.2.1)

| 시도 | 볼륨 | HUD |
|---|---|---|
| CoreAudio +5% | 18→23 | **없음** |
| `NX_SYSDEFINED`(subtype 8) 볼륨 업 키 주입 | 12→18 (1/16) | **표시** — `MenuBarAgent` 367×160, 상단 우측 |
| 볼륨 다운 키 | 1스텝 | **표시** |
| 뮤트 키 | 음소거 토글 | **표시** |

- 백그라운드(앱 번들 없는) 프로세스에서도 동작, 프론트 앱과 무관
- `OSD.framework`는 이 OS에서 바이너리 없는 스텁 → 과거 비공개 `OSDManager` 경로는 사용하지 않는다

## 3. 구현

- **`Services/SystemMediaKey.swift` (신규)** — `NX_KEYTYPE_SOUND_UP(0)`·`SOUND_DOWN(1)`·`MUTE(7)`를
  `NSEvent.otherEvent(.systemDefined, subtype: 8)` → `cgEvent.post(.cghidEventTap)`로 주입.
  접근성 권한(`AXIsProcessTrusted`)이 없으면 주입하지 않고 false를 돌려준다.
- **`SystemActionExecutor`**
  - `.volumeUp`/`.volumeDown` → 미디어 키 주입 (스텝 1/16, 기존 CoreAudio 경로와 동일). 실패 시 CoreAudio 폴백.
  - `.mute` → 미디어 키 주입. 실패 시 기존 AppleScript(0 ↔ 60) 폴백.
  - mute 의미 변경: "볼륨 0 ↔ 60 토글" → **실제 음소거 플래그**(볼륨 값 보존). 레이블("음소거 토글")과 일치.
- **앱 자체 HUD는 추가하지 않는다** — 시스템 HUD가 뜨므로 중복 표시가 된다.
  트랙패드 에지 슬라이더(연속 제어)는 기존 `TrackpadHUD` 유지(네이티브 OSD를 연속으로 띄우면 깜빡임).

## 4. 적용 범위

`SystemActionExecutor.execute`를 쓰는 모든 경로: 워크플로 단계 · 단축키 직접 바인딩 · 트랙패드 제스처의 시스템 액션.

## 5. 리스크 / 롤백

- 문서화되지 않은 시스템 동작 → macOS 업데이트로 막힐 수 있음. **폴백(CoreAudio/AppleScript)으로 기능은 유지**.
- 접근성 권한 필요(이미 메뉴 실행에 사용 중). 권한이 없으면 폴백 경로로 동작(HUD 없음).
- Karabiner 등 볼륨 키를 리매핑한 환경에서는 체감이 달라질 수 있다.
- 절대값 설정(`setVolumeMedia`)은 키 이벤트로 표현할 수 없어 이번 범위에서 제외(기존 CoreAudio 유지).
- 롤백: `SystemActionExecutor`의 두 분기와 `SystemMediaKey.swift` 제거.

## 6. 검증

- 단위: `SystemMediaKeyTests` — data1 인코딩(키/상태 분리, IOKit 상수 일치)
- 빌드: `./build_and_run.sh test macos unit` (게이트 3종 포함)
- 실기: 사용자 단축키로 볼륨 올리기/내리기/음소거 → **시스템 HUD 표시 + 볼륨 1스텝** 확인
