#!/usr/bin/env python3
"""
종합 치환기:
1. 모든 Text("...") 수집
2. Localizable.strings에 없는 것들 키 생성 후 추가
3. Text("...") -> Text(localized: "key") 치환
"""
import re
from pathlib import Path

SRC_ROOT = Path("/Users/lee/Documents/Apps/ApexKey/Sources/ApexKey")

def load_strings_dict(lproj_path: Path) -> dict:
    content = lproj_path.read_text(encoding="utf-16")
    mapping = {}
    for m in re.finditer(r'"([^"]+)"\s*=\s*"([^"]+)";', content):
        mapping[m.group(2)] = m.group(1)
    return mapping

def save_strings_dict(lproj_path: Path, mapping: dict):
    """mapping: {value: key} → write Localizable.strings"""
    lines = []
    for key in sorted(mapping.keys(), key=lambda k: mapping[k]):
        value = mapping[key]
        # escape quotes and backslashes
        value_esc = value.replace('\\', '\\\\').replace('"', '\\"')
        key_esc = key.replace('\\', '\\\\').replace('"', '\\"')
        lines.append(f'"{key_esc}" = "{value_esc}";')
    content = "\n".join(lines) + "\n"
    lproj_path.write_text(content, encoding="utf-16")

# Load existing
ko_path = SRC_ROOT / "ko.lproj" / "Localizable.strings"
en_path = SRC_ROOT / "en.lproj" / "Localizable.strings"

ko_map = load_strings_dict(ko_path)  # {value: key}
en_map = load_strings_dict(en_path)

# Merge: keep existing, add new
all_values = set(ko_map.keys()) | set(en_map.keys())
print(f"기존 ko: {len(ko_map)}, en: {len(en_map)}, 합집합: {len(all_values)}")

# Find all Text("...") in code
text_pattern = re.compile(r'Text\(\s*"([^"]+)"\s*\)')
new_entries = {}  # {value: key}

for f in SRC_ROOT.rglob("*.swift"):
    if any(ex in f.parts for ex in {".build", "build", "DerivedData"}):
        continue
    content = f.read_text(encoding="utf-8")
    for m in text_pattern.finditer(content):
        full = m.group(0)
        value = m.group(1)
        if ".localized" in full:
            continue
        if "{" in value or "%" in value or "\\(" in value:
            continue
        if value in all_values:
            continue
        # Generate key
        # Use first 4 words as slug
        words = re.sub(r'[^\w\s]', '', value).split()[:4]
        slug = "_".join(w.lower() for w in words if w)
        if not slug:
            import hashlib
            slug = hashlib.md5(value.encode()).hexdigest()[:8]
        # Determine namespace
        if any(kw in value for kw in ["설정", "표시", "권한", "테마", "언어", "단축키", "메뉴", "HUD", "패널"]):
            ns = "settings"
        elif any(kw in value for kw in ["앱", "동작", "스크립트", "자동화", "변수", "실행", "단계"]):
            ns = "ui"
        elif any(kw in value for kw in ["알림", "오류", "실패", "성공", "중복", "권한"]):
            ns = "toast"
        elif any(kw in value for kw in ["앱 실행", "메뉴", "파일", "URL", "스크립트", "시스템", "대기", "클릭", "입력", "매크로", "대화", "텍스트", "클립보드", "이동", "깨우기", "지우기", "방지", "배경", "다크", "집중", "스크린샷", "PDF", "Wi-Fi", "블루투스", "타이머", "스톱워치", "위치", "AirDrop", "메모", "테이블", "이메일", "날짜", "AppleScript", "JavaScript", "보기", "사진", "음악", "비디오", "재생", "팟캐스트", "라디오", "앨범", "카메라", "이미지", "자르기", "회전", "다운로드", "문서", "번역", "편집", "메일", "드라이브", "파일", "압축", "저장소", "동작", "확인", "첨부", "딕셔너리", "포맷", "리스트", "조정", "숫자", "수학", "해시", "UUID", "출력", "입력", "정렬", "대소문자", "교체", "결합", "일치", "분리", "공백", "감싸기", "개수", "단어", "계산", "Base64", "HTML", "측정", "QR", "인식", "감지", "지도", "대중교통", "메시지", "이메일", "캘린더", "할일", "웹", "프레젠테이션", "연동", "주변기기", "단축어", "실행", "반복", "각 항목", "If", "종료", "중지", "선택", "코멘트", "변수", "숫자", "출력", "모델", "라이팅", "이미지", "앱", "Intent", "검색", "자동화", "트리거"]):
            ns = "action"
        elif any(kw in value for kw in ["ApexKey", "애펙스키", "버전", "최상위", "정점", "글로벌", "단축키", "매니저", "©", "BoRaSaRang"]):
            ns = "about"
        else:
            ns = "ui"
        key = f"{ns}.{slug}"
        # Avoid duplicates
        if key in [v for v in all_values]:
            import hashlib
            key = f"{ns}.{hashlib.md5(value.encode()).hexdigest()[:8]}"
        new_entries[value] = key

print(f"신규 진입: {len(new_entries)}개")

# Add to both maps
for value, key in new_entries.items():
    ko_map[value] = key
    en_map[value] = key  # placeholder, will need translation

# Save updated
save_strings_dict(ko_path, {v: k for k, v in ko_map.items()})
save_strings_dict(en_path, {v: k for k, v in en_map.items()})
print("Localizable.strings 업데이트 완료")

# Now replace in all files
total_replaced = 0
for f in SRC_ROOT.rglob("*.swift"):
    if any(ex in f.parts for ex in {".build", "build", "DerivedData"}):
        continue
    content = f.read_text(encoding="utf-8")
    original = content
    
    def replacer(match):
        full = match.group(0)
        value = match.group(1)
        if ".localized" in full:
            return full
        if "{" in value or "%" in value or "\\(" in value:
            return full
        key = ko_map.get(value)
        if key:
            return f'Text(localized: "{key}")'
        return full
    
    new_content = text_pattern.sub(replacer, content)
    if new_content != original:
        f.write_text(new_content, encoding="utf-8")
        total_replaced += 1
        print(f"  {f.name}: 치환됨")

print(f"\n총 {total_replaced}개 파일 치환 완료")