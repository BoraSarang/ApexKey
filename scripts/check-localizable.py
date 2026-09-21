#!/usr/bin/env python3
"""잔여 한글 리터럴 가드 — 미로컬라이즈 UI 문자열 발견 시 빌드를 실패시킨다.

허용(의도적 유지) 항목은 제외한다:
- 주석(//, /* */), Logger 로그
- 이미 로컬라이즈된 참조 (.localized / .localizedFormat)
- 토큰/정규식 패턴 ({마법변수:}, {변수:}, {마법:}, 마법변수)
- 불리언 입력 파싱 (참/예/거짓/아니오 비교)
- 메뉴 항목 식별 ("서비스")
- StoreCoding 로그 라벨 (DataModels.swift)
- 앱스토어 카테고리 키워드 매칭 (AppFinder.swift)
- 시드 데이터·레거시 마이그레이션 (ConfigStore.swift, ConfigStore+Shortcuts.swift)
- 시스템 액션 내장 셸 스크립트 출력 메시지 (SystemActionExecutor.swift, 터미널 출력)

사용법: python3 scripts/check-localizable.py
"""
from __future__ import annotations

import glob
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "Sources"
KOREAN = re.compile(r"[\uac00-\ud7af]")

EXCLUDED_FILES = {
    "AppFinder.swift",  # 앱스토어 카테고리 키워드 매칭 (표시 아님)
    "ConfigStore.swift",  # 레거시 마이그레이션 키 + 빌트인 프리셋 (시드)
    "ConfigStore+Shortcuts.swift",  # 시드 데이터 (사용자 결정: 유지)
    "SystemActionExecutor.swift",  # androidMirror 내장 스크립트의 터미널 출력 메시지
}

# 라인 단위로 제외할 패턴 (리터럴 내용 기준)
ALLOWED_LINE = (
    r"Logger\.",
    r"\.localized\b",
    r"\.localizedFormat\(",
    r"\{\s*마법변수:",
    r"\{\s*변수:",
    r"\{\s*마법:",
    r"마법변수:",
    r'[=!]=\s*"(참|거짓|예|아니오)"',
    r'\bcase\s+["\']?(참|거짓|예|아니오)',
    r'"(참|거짓|예|아니오)"\s*(\)|,|\.)',
    r'"서비스"',
    r"StoreCoding\.(encode|decode)",
    r'\b(참|거짓|예|아니오)\b.*(===|==|!=)',
    r"osascript 실행 실패",  # 로그 전용 (MenuEnumerator → Logger.error)
)

ALLOWED_RE = [re.compile(p) for p in ALLOWED_LINE]


def strip_comments(src: str) -> str:
    """// 주석과 /* */ 블록 주석을 제거한다."""
    out: list[str] = []
    i, n = 0, len(src)
    in_block = False
    while i < n:
        if in_block:
            end = src.find("*/", i)
            if end == -1:
                break
            out.append(" " * (end - i + 2))
            i = end + 2
            in_block = False
            continue
        if src.startswith("/*", i):
            in_block = True
            out.append("  ")
            i += 2
            continue
        if src.startswith("//", i):
            end = src.find("\n", i)
            if end == -1:
                end = n
            out.append(" " * (end - i))
            i = end
            continue
        out.append(src[i])
        i += 1
    return "".join(out)


def line_keeps_korean(line: str) -> bool:
    """한글 포함 + 허용 패턴에 걸리지 않는 라인이면 True (잔여 한글)."""
    if not KOREAN.search(line):
        return False
    stripped = line.strip()
    if not stripped:
        return False
    if any(p.search(line) for p in ALLOWED_RE):
        return False
    return True


def is_str_literal(text: str) -> bool:
    """코드(주석 제거 후)에서 한글 문자열 리터럴 포함 여부."""
    # 큰따옴표로 묶인 리터럴 안에 한글이 있는 라인만 잡는다 (식별자/테스트 데이터는 제외)
    return KOREAN.search(text) and '"' in text and re.search(r'"[^"\n]*[\uac00-\ud7af][^"\n]*"', text) is not None


def main() -> int:
    hits: list[tuple[str, int, str]] = []
    # 앱 타깃(Sources/ApexKey)만 스캔 — 테스트 픽스처의 한글 데이터는 제외
    for path in sorted(glob.glob(str(SRC / "ApexKey" / "**" / "*.swift"), recursive=True)):
        p = Path(path)
        if p.name in EXCLUDED_FILES:
            continue
        try:
            raw = p.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        code = strip_comments(raw)
        for lineno, code_line, raw_line in zip(
            range(1, len(code.split("\n")) + 1),
            code.split("\n"),
            raw.split("\n"),
        ):
            if not is_str_literal(code_line):
                continue
            if line_keeps_korean(code_line):
                hits.append((str(p), lineno, raw_line.strip()))

    if hits:
        print(f"[ERROR] 미로컬라이즈 한글 리터럴 {len(hits)}건 발견:")
        for f, ln, text in hits[:100]:
            rel = Path(f).relative_to(SRC)
            print(f"  {rel}:{ln}: {text[:90]}")
        print("→ '.localized' 키로 변환하거나 scripts/check-localizable.py 허용목록에 추가하세요.")
        return 1

    print("[OK] 잔여 한글 리터럴 없음 (가드 통과)")
    return 0


if __name__ == "__main__":
    sys.exit(main())