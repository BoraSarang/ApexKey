#!/usr/bin/env python3
"""버전 단일 출처 가드 (E-MAC-REL-9301)

`project.yml`의 `MARKETING_VERSION`이 유일한 출처다. `Info.plist`는
`$(MARKETING_VERSION)`을 참조해야 하며, 하드코딩된 실제 버전 숫자가
남아 있으면 xcodegen이 plist를 재생성할 때마다 되돌아오는 사고가 반복된다.

실제 사고: `91a9d7f`가 1.3.0으로 올린 뒤, xcodegen이 plist를 덮어쓰는 것을 되돌리려고
`f2f65a3`에서 `git checkout -- Info.plist`를 실행했고, 그 와중에 버전도 1.0으로 복귀했다.
`release.yml`의 태그-버전 대조는 그 상태에서 다음 릴리스를 막았다.

검사 항목
1. project.yml에 MARKETING_VERSION / CURRENT_PROJECT_VERSION 이 존재하는가
2. 두 값이 SemVer 형태인가
3. Info.plist의 CFBundleShortVersionString 이 `$(MARKETING_VERSION)` 참조인가
4. Info.plist의 CFBundleVersion 이 `$(CURRENT_PROJECT_VERSION)` 참조인가
5. project.yml의 info.properties 가 같은 변수를 선언하는가 (선언 누락 시 치환 안 됨)

사용법: python3 scripts/check-version.py
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROJECT_YML = ROOT / "project.yml"
INFO_PLIST = ROOT / "Sources" / "ApexKey" / "Info.plist"

SEMVER = re.compile(r"^\d+\.\d+\.\d+$")


def fail(errors: list[str]) -> int:
    print(f"[ERROR] 버전 단일 출처 검사 실패 ({len(errors)}건):")
    for e in errors:
        print(f"  {e}")
    print("→ project.yml의 MARKETING_VERSION만 수정하세요. Info.plist는 직접 쓰지 않습니다.")
    return 1


def main() -> int:
    errors: list[str] = []
    warnings: list[str] = []

    yml = PROJECT_YML.read_text(encoding="utf-8")

    m = re.search(r'^\s*MARKETING_VERSION:\s*"([^"]*)"', yml, re.M)
    if not m:
        errors.append("project.yml에 MARKETING_VERSION 설정이 없습니다")
        return fail(errors)
    marketing = m.group(1)

    m2 = re.search(r'^\s*CURRENT_PROJECT_VERSION:\s*"?([^"\s]*)"?', yml, re.M)
    if not m2:
        errors.append("project.yml에 CURRENT_PROJECT_VERSION 설정이 없습니다")
        return fail(errors)
    current = m2.group(1)

    if not SEMVER.match(marketing):
        errors.append(f"MARKETING_VERSION='{marketing}'이 SemVer(x.y.z) 형태가 아닙니다")
    if not current.isdigit():
        errors.append(f"CURRENT_PROJECT_VERSION='{current}'이 정수가 아닙니다")

    # info.properties 선언 확인 — 여기 없으면 빌드 시 치환되지 않는다
    info_block = re.search(r"info:\s*\n\s*path:.*?\n\s*properties:\s*\n(.*?)(?=\n  \w|\Z)", yml, re.S)
    if info_block is None:
        errors.append("project.yml의 info.properties 블록을 찾을 수 없습니다")
    else:
        props = info_block.group(1)
        if "CFBundleShortVersionString: $(MARKETING_VERSION)" not in props:
            errors.append(
                "info.properties에 CFBundleShortVersionString: $(MARKETING_VERSION) 선언이 없습니다 "
                "(없으면 빌드 시 치환되지 않음)"
            )
        if "CFBundleVersion: $(CURRENT_PROJECT_VERSION)" not in props:
            errors.append(
                "info.properties에 CFBundleVersion: $(CURRENT_PROJECT_VERSION) 선언이 없습니다"
            )

    plist = INFO_PLIST.read_text(encoding="utf-8")

    short = re.search(r"<key>CFBundleShortVersionString</key>\s*<string>([^<]*)</string>", plist)
    if short is None:
        errors.append("Info.plist에 CFBundleShortVersionString이 없습니다")
    elif short.group(1) != "$(MARKETING_VERSION)":
        errors.append(
            f"Info.plist의 CFBundleShortVersionString이 하드코딩됨: '{short.group(1)}' "
            "(xcodegen이 매 빌드 덮어씌움 → $(MARKETING_VERSION) 참조로 변경)"
        )

    build = re.search(r"<key>CFBundleVersion</key>\s*<string>([^<]*)</string>", plist)
    if build is None:
        errors.append("Info.plist에 CFBundleVersion이 없습니다")
    elif build.group(1) != "$(CURRENT_PROJECT_VERSION)":
        errors.append(
            f"Info.plist의 CFBundleVersion이 하드코딩됨: '{build.group(1)}' "
            "(→ $(CURRENT_PROJECT_VERSION) 참조로 변경)"
        )

    if marketing == "1.0":
        warnings.append(
            f"MARKETING_VERSION이 '{marketing}'입니다. release.yml 태그 대조를 통과하려면 "
            "릴리스 태그와 같아야 합니다."
        )

    for w in warnings:
        print(f"[WARN] {w}")

    if errors:
        return fail(errors)

    print(f"[OK] 버전 단일 출처 확인: {marketing} (build {current}) — project.yml / Info.plist 일치")
    return 0


if __name__ == "__main__":
    sys.exit(main())
