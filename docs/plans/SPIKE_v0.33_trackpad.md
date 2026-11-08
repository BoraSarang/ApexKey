# SPIKE_v0.33 — 트랙패드 제스처 선행 검증

> status: **검증 완료 (2026-11-08)** — 정적·합성 검증 전부 통과. 실기 에지 스와이프 1건만 사용자 확인 대기.
> 목적: ApexKey에 트랙패드 입력을 넣기 전에 **"서명 없이, 새 권한 없이"** 가능한지 실측.
> 산출물 코드는 저장소에 넣지 않는다(임시 검증용). 재현 절차만 아래에 남긴다.

## 0. 환경

| 항목 | 값 |
|---|---|
| macOS | 27.2 (26B123) |
| 하드웨어 | MacBookPro18,4 (내장 트랙패드) |
| 툴체인 | Xcode 27.2 / Swift 6.4.2 (`-swift-version 5`) |
| 빌드 | `swiftc -O` → `codesign -s - --options runtime` (ad-hoc + **하드닝 런타임**) |

## 1. 검증 결과

| # | 검증 항목 | 결과 | 근거 |
|:-:|---|---|---|
| 1 | 하드닝 런타임에서 비공개 프레임워크 `dlopen` | **통과** | `flags=0x10002(adhoc,runtime)` 서명 후 로드 성공. 라이브러리 검증 차단 없음 |
| 2 | 디바이스 열거 | **통과** | `devices: 1`, `builtin=1` |
| 3 | 콜백 등록 + 실제 터치 수신 | **통과** | 8초 동안 **187프레임** 수신, 손가락 1→2 |
| 4 | 좌표 정규화 | **통과** | x/y ∈ 0..1, 압력 4~138 (float) — 구조체 레이아웃 일치 |
| 5 | CoreAudio 볼륨 읽기/쓰기 | **통과** | `volume=0.250`, `set status: 0`, 재읽기 동일 |
| 6 | `CGEventTap` 생성(스크롤 억제) | **통과** | `AXIsProcessTrusted: true`, tap 생성 성공 |
| 7 | 에지 판정(우측 2손가락 세로) | **통과(합성)** | 상승 1회/하강 1회 트리거, 중앙 입력 0회 — 오탐 없음 |

### 실측 로그 발췌

```
framework: loaded
symbols: createList=true builtin=true register=true start=true stop=true running=true
devices: 1
  #0 builtin=1

frame=1   fingers=1 avg=(0.585, 0.261) p=36.00
frame=60  fingers=1 avg=(0.542, 0.418) p=28.00
frame=170 fingers=2 avg=(0.538, 0.422) p=25.00
touch frames received: 187, edge triggers: 0

volume before: 0.250 / set status: 0 / volume after: 0.250
AXIsProcessTrusted: true / CGEventTap: created

selftest: edgeUP=1 edgeDOWN=1 center=0
PASS
```

## 2. 이 실측이 바꾼 것

| 당초 가정 | 실측 결과 | 설계 영향 |
|---|---|---|
| Input Monitoring이 추가로 필요 | **불필요** — 기존 Accessibility로 억제·합성 가능 | **새 권한 0개**. 온보딩 부담 없음 |
| 하드닝 런타임이 dlopen을 막을 수 있음 | **막지 않음** | `disable-library-validation` 엔타이틀먼트 불필요 |
| 구조체 레이아웃이 macOS 27에서 다를 수 있음 | **일치** (좌표·압력 정상) | 그대로 사용 가능. 단 버전 취약성은 별도 |
| `MTDeviceGetDeviceID` 등 일부 심볼 | **크래시** | **호출 금지**. 필요한 심볼만 화이트리스트로 쓴다 |

> ⚠️ `MTDeviceGetFamilyID`·`MTDeviceGetDeviceID`는 이 macOS에서 그대로 호출하면 **SIGSEGV**.
> 1차 프로브에서 확인. → 계열 ID가 필요하면 다른 경로를 쓰고, **다시 시도하지 않는다**.

## 3. 남은 미검증 (사용자 30초 확인 필요)

| 항목 | 왜 남았나 | 확인 방법 |
|---|---|---|
| 실기 우측 에지 2손가락 → 볼륨 변화 | 합성 입력으로만 검증 | 스파이크 실행 후 실제로 스와이프 1회 |
| 실행 중인 앱 스크롤 억제 체감 | tap 생성까지만 확인 | 에지 슬라이더 중 문서가 스크롤되지 않는지 |
| 자체 서명 인증서로 TCC 승인 유지 | 인증서·재빌드 사이클 필요 | 선택 실험(안 해도 기능엔 지장 없음) |

## 4. 재현 절차

```bash
cd <임시폴더>
swiftc -swift-version 5 -O -o spike spike.swift \
  -framework CoreAudio -framework AudioToolbox \
  -framework ApplicationServices -framework Cocoa
codesign -s - --options runtime --force spike
./spike enum        # 프레임워크·디바이스
./spike volume      # CoreAudio 읽기/쓰기
./spike tap         # AX 신뢰 + 이벤트 탭
./spike listen 8    # 실제 터치 프레임
./spike selftest    # 에지 판정 로직
```

## 5. 결론

**"ApexKey에 트랙패드 입력을 넣는 것은 서명·공증 없이, 새 권한 없이 가능하다."**

- 읽기: 비공개 프레임워크 (TCC 없음)
- 억제·합성: 기존 Accessibility 재사용
- 리스크는 권한이 아니라 **비공개 API의 버전 취약성** → `TrackpadKit` 모듈로 격리하고 실패 시 기능만 끈다.
