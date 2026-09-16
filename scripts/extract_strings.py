#!/usr/bin/env python3
"""
SwiftUI 하드코딩 문자열 추출기 — Text("...") 패턴 찾아 Localizable 키 후보 생성
"""
import re
import sys
from pathlib import Path

SRC_ROOT = Path(__file__).parent.parent / "Sources" / "ApexKey"
EXCLUDE_DIRS = {".build", "build", "DerivedData"}

# Text("...") 패턴 (단순화: 중첩 문자열 미지원, 기본 케이스 커버)
TEXT_PATTERN = re.compile(r'Text\(\s*"([^"]+)"\s*\)')
# Text("...") + .font 등 체이닝
TEXT_WITH_MODIFIER = re.compile(r'Text\(\s*"([^"]+)"\s*\)\s*\.')

def extract_strings():
    strings = set()
    for swift_file in SRC_ROOT.rglob("*.swift"):
        if any(ex in swift_file.parts for ex in EXCLUDE_DIRS):
            continue
        content = swift_file.read_text(encoding="utf-8")
        for match in TEXT_PATTERN.finditer(content):
            text = match.group(1)
            # 이미 localized 사용 중인 것 제외
            if ".localized" not in match.group(0):
                # 변수/인터폴레이션 포함된 것 제외 (복잡한 케이스)
                if "{" not in text and "%" not in text:
                    strings.add(text)
    return sorted(strings)

def suggest_key(text: str) -> str:
    """한글 텍스트에서 키 제안"""
    # 간단 휴리스틱: 앞 3단어 영문 약자 + 번호 (충돌 시 수동 조정 필요)
    import hashlib
    h = hashlib.md5(text.encode()).hexdigest()[:8]
    # 한글 포함 여부
    has_korean = any('\uac00' <= c <= '\ud7a3' for c in text)
    if has_korean:
        prefix = "ui"
    else:
        prefix = "txt"
    return f"{prefix}.{h}"

def main():
    strings = extract_strings()
    print(f"발견된 하드코딩 문자열: {len(strings)}개")
    print()
    for s in strings:
        key = suggest_key(s)
        print(f'"{key}" = "{s}";')
    # 파일로도 저장
    out_path = SRC_ROOT.parent / "extracted_strings.txt"
    out_path.write_text("\n".join(f'"{suggest_key(s)}" = "{s}";' for s in strings), encoding="utf-8")
    print(f"\n저장: {out_path}")

if __name__ == "__main__":
    main()