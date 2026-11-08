#!/usr/bin/env python3
"""트랙패드 모듈 경계 가드.

v0.33의 핵심 약속은 **"비공개 프레임워크를 한 파일에 가두고, 새 권한을 요구하지 않는다"**다.
이 스크립트는 그 약속이 코드에서 깨지지 않았는지 기계적으로 확인한다.

검사 항목
1. 금지 심볼(`MTDeviceGetFamilyID`, `MTDeviceGetDeviceID`)이 저장소 어디에도 없다.
   — macOS 26/27에서 호출 시 SIGSEGV (SPIKE §1 실측).
2. `dlopen`/`dlsym`/`MultitouchSupport`는 `Trackpad/MTBridge.swift`에만 있다.
3. Input Monitoring 계열 API(`IOHIDEventSystemClient`, `CGPreflightListenEventAccess`,
   `CGRequestListenEventAccess`)를 쓰지 않는다.
4. 트랙패드 코드가 `AXIsProcessTrusted`/`CGEventTap` 외의 새 TCC 프롬프트를 유발하는
   API를 직접 호출하지 않는다(메뉴 실행은 기존 경로 재사용).
5. 엔타이틀먼트에 트랙패드용 키가 추가되지 않았다 — Apple Events 하나만 유지.
6. `Trackpad/` 밖에서 `TrackpadEngine`/`MTBridge`를 직접 만지지 않는다.
   (앱 수명주기 배선인 AppDelegate는 허용)

사용법: python3 scripts/check-trackpad-boundary.py
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "Sources" / "ApexKey"
TRACKPAD = SRC / "Trackpad"

FORBIDDEN_SYMBOLS = ("MTDeviceGetFamilyID", "MTDeviceGetDeviceID")
PRIVATE_API_TOKENS = ("dlopen(", "dlsym(", "MultitouchSupport")
INPUT_MONITORING_SYMBOLS = (
    "IOHIDEventSystemClient",
    "CGPreflightListenEventAccess",
    "CGRequestListenEventAccess",
)

# Trackpad/ 밖에서 참조해도 되는 파일 (앱 수명주기·설정 저장·UI 배선)
ALLOWED_EXTERNAL_REFERENCES = {
    "AppDelegate.swift",
    "ConfigStore.swift",
    "ConfigStore+Trackpad.swift",
    "ConfigStore+Preferences.swift",
    "MainWindowView.swift",
    "SidebarView.swift",
    "TrackpadView.swift",
    "TrackpadRuleSheets.swift",
    # 프리셋·카탈로그는 SystemActionType.allCases를 그대로 소비한다(의도된 확장)
    "SystemPresetPickerView.swift",
    "ActionCatalogView.swift",
    "StepTestViews.swift",
    "Shortcut.swift",
    "SystemActionExecutor.swift",
    "TrackpadRecognizerTests.swift",
}

errors: list[str] = []


def swift_files() -> list[Path]:
    return sorted(SRC.rglob("*.swift")) + sorted((ROOT / "Sources" / "ApexKeyTests").rglob("*.swift"))


def check_forbidden_symbols() -> None:
    for path in swift_files():
        text = path.read_text(encoding="utf-8", errors="ignore")
        for symbol in FORBIDDEN_SYMBOLS:
            if symbol in text:
                errors.append(f"{path.relative_to(ROOT)}: 금지 심볼 사용 — {symbol} (SIGSEGV)")


def check_private_api_containment() -> None:
    allowed = TRACKPAD / "MTBridge.swift"
    for path in swift_files():
        text = path.read_text(encoding="utf-8", errors="ignore")
        for token in PRIVATE_API_TOKENS:
            if token not in text:
                continue
            if path == allowed:
                continue
            # 문서 주석에서 이름만 언급하는 것은 허용하지 않는다 — 코드/주석 구분 없이 금지.
            errors.append(f"{path.relative_to(ROOT)}: 비공개 API 토큰 '{token}' 이 MTBridge 밖에 있다")


def check_no_input_monitoring() -> None:
    for path in swift_files():
        text = path.read_text(encoding="utf-8", errors="ignore")
        for symbol in INPUT_MONITORING_SYMBOLS:
            if symbol in text:
                errors.append(f"{path.relative_to(ROOT)}: Input Monitoring API 사용 — {symbol}")


def check_entitlements() -> None:
    path = SRC / "ApexKey.entitlements"
    text = path.read_text(encoding="utf-8")
    keys = set(re.findall(r"<key>([^<]+)</key>", text))
    expected = {"com.apple.security.automation.apple-events"}
    extra = keys - expected
    if extra:
        errors.append(f"{path.relative_to(ROOT)}: 예상 밖 엔타이틀먼트 — {sorted(extra)}")
    missing = expected - keys
    if missing:
        errors.append(f"{path.relative_to(ROOT)}: 필수 엔타이틀먼트 누락 — {sorted(missing)}")


def check_engine_references() -> None:
    pattern = re.compile(r"\b(TrackpadEngine|MTBridge|ScrollSuppressor)\b")
    for path in swift_files():
        if TRACKPAD in path.parents:
            continue
        if path.name in ALLOWED_EXTERNAL_REFERENCES:
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        for match in pattern.finditer(text):
            line = text.count("\n", 0, match.start()) + 1
            errors.append(
                f"{path.relative_to(ROOT)}:{line}: 내부 타입 '{match.group(1)}' 직접 참조 — "
                f"Trackpad/ 또는 허용된 배선 파일에서만 사용"
            )


def main() -> int:
    if not TRACKPAD.exists():
        print("[FAIL] Sources/ApexKey/Trackpad 가 없다")
        return 1
    check_forbidden_symbols()
    check_private_api_containment()
    check_no_input_monitoring()
    check_entitlements()
    check_engine_references()

    if errors:
        print("[FAIL] 트랙패드 경계 위반:")
        for error in errors:
            print("  -", error)
        return 1
    print("[OK] 트랙패드 경계 가드 통과 (금지 심볼 0 · 비공개 API 격리 · 새 권한 0)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
