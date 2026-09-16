#!/usr/bin/env python3
"""
Text("...") → Text(localized: "key") 치환기
- Localizable.strings에 있는 키만 치환
- 이미 localized 사용 중인 것 건너뜀
"""
import re
from pathlib import Path

SRC_ROOT = Path(__file__).parent.parent / "Sources" / "ApexKey"

# ko/en strings에서 키-값 매핑 로드
def load_strings_dict(lproj_path: Path) -> dict:
    """Localizable.strings 파싱 → {value: key}"""
    mapping = {}
    content = lproj_path.read_text(encoding="utf-16")
    # "key" = "value"; 패턴
    for match in re.finditer(r'"([^"]+)"\s*=\s*"([^"]+)";', content):
        key, value = match.groups()
        mapping[value] = key
    return mapping

ko_map = load_strings_dict(SRC_ROOT / "ko.lproj" / "Localizable.strings")
en_map = load_strings_dict(SRC_ROOT / "en.lproj" / "Localizable.strings")

# 양쪽에 모두 있는 값만 사용 (일관성)
common_values = set(ko_map.keys()) & set(en_map.keys())
value_to_key = {v: ko_map[v] for v in common_values}
print(f"치환 대상 문자열: {len(value_to_key)}개")

# Text("...") 패턴 (이미 .localized 안 쓴 것)
text_pattern = re.compile(r'Text\(\s*"([^"]+)"\s*\)')

def replace_in_file(filepath: Path):
    content = filepath.read_text(encoding="utf-8")
    original = content
    changes = 0
    
    def replacer(match):
        nonlocal changes
        full = match.group(0)
        value = match.group(1)
        
        # 이미 localized 쓰면 건너뜀
        if ".localized" in full:
            return full
        
        # 인터폴레이션/포맷 포함된 것 건너뜀
        if "{" in value or "%" in value or "\\(" in value:
            return full
        
        key = value_to_key.get(value)
        if key:
            changes += 1
            return f'Text(localized: "{key}")'
        return full
    
    new_content = text_pattern.sub(replacer, content)
    
    if changes > 0:
        filepath.write_text(new_content, encoding="utf-8")
        print(f"  {filepath.relative_to(SRC_ROOT)}: {changes}개 치환")
    return changes

total_changes = 0
for swift_file in SRC_ROOT.rglob("*.swift"):
    if any(ex in swift_file.parts for ex in {".build", "build", "DerivedData"}):
        continue
    total_changes += replace_in_file(swift_file)

print(f"\n총 {total_changes}개 치환 완료")