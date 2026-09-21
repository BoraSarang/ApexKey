#!/usr/bin/env python3
"""검증 체크리스트 자동 반영 — [자동] 행만 갱신, [수동] 행은 절대 건드리지 않음.

사용법: python3 scripts/update-verify-checklist.py
동작:
  1. ./build_and_run.sh test macos unit 실행 (컴파일+전체 unit 테스트)
  2. 출력에서 `Test Case '-[ApexKeyTests.Class.test]' passed|failed` 파싱
     (구 xcodebuild 형식 `Class test` 공백 구분도 지원)
  3. docs/plans/ACTION_VERIFY_v2_macos.md 에서 `<!-- auto:Class.test -->` 행의
     체크박스 갱신 — 통과 `[x]` (+FAIL 제거), 실패 `[ ]` (+` **FAIL**` 표식)
  4. "마지막 자동 반영" 줄 갱신 + 요약 출력
종료 코드: 테스트 실패가 있으면 1 (체크리스트는 갱신됨).
"""
from __future__ import annotations

import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOC = ROOT / "docs" / "plans" / "ACTION_VERIFY_v2_macos.md"

CASE_RE = re.compile(
    r"Test Case '-\[(\w+)\.(\w+)[ /.](\w+)\]' (passed|failed)"
)
AUTO_TAG_RE = re.compile(r"<!-- auto:(\w+)\.(\w+) -->")


def run_tests() -> int:
    """build_and_run.sh test 실행 (현지화 가드+서명 일관성 유지). 출력은 tail로 잘리므로 무시."""
    proc = subprocess.run(
        ["./build_and_run.sh", "test", "macos", "unit"],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    return proc.returncode


def newest_xcresult() -> Path | None:
    bundles = sorted(
        (ROOT / "build" / "Logs" / "Test").glob("*.xcresult"),
        key=lambda p: p.stat().st_mtime,
    )
    return bundles[-1] if bundles else None


def parse_results(bundle: Path) -> dict[tuple[str, str], str]:
    """xcresult에서 (클래스, 테스트) → Passed/Failed/Skipped 매핑 추출."""
    import json

    proc = subprocess.run(
        ["xcrun", "xcresulttool", "get", "test-results", "tests", "--path", str(bundle)],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        print(proc.stderr[-2000:], file=sys.stderr)
        raise RuntimeError("xcresult 파싱 실패")
    data = json.loads(proc.stdout)
    results: dict[tuple[str, str], str] = {}

    def walk(nodes: list, suite: str = "") -> None:
        for node in nodes:
            ident = node.get("nodeIdentifier", "")
            ntype = node.get("nodeType", "")
            if ntype == "Test Case" and "/" in ident:
                cls, name = ident.split("/", 1)
                name = name.removesuffix("()")
                results[(cls, name)] = node.get("result", "Unknown")
            else:
                # 스위트 노드: 식별자 끝 토큰을 스위트로 (하위 호환용, 실제론 ident 사용)
                walk(node.get("children", []), suite)

    walk(data.get("testNodes", []))
    return results


def update_doc(results: dict[tuple[str, str], str]) -> tuple[int, int, int, list[str]]:
    text = DOC.read_text(encoding="utf-8")
    lines = text.splitlines()
    passed = failed = skipped = 0
    failed_names: list[str] = []
    for i, line in enumerate(lines):
        tag = AUTO_TAG_RE.search(line)
        if not tag or not line.lstrip().startswith("|"):
            continue
        key = (tag.group(1), tag.group(2))
        status = results.get(key)
        if status is None:
            continue  # 이번 실행에 없음 — 손대지 않음
        cells = line.split("|")
        if len(cells) < 3:
            continue
        # 이전 표식 제거 후 상태별로 새로 표기
        cells[-2] = re.sub(r"\s*\*\*(FAIL|SKIP)\*\*.*$", "", cells[-2])
        if status == "Passed":
            cells[1] = " [x] "
            passed += 1
        elif status == "Skipped":
            cells[1] = " [ ] "
            cells[-2] = cells[-2].rstrip() + " **SKIP**"
            skipped += 1
        else:
            cells[1] = " [ ] "
            cells[-2] = cells[-2].rstrip() + " **FAIL**"
            failed += 1
            failed_names.append(f"{key[0]}.{key[1]}")
        lines[i] = "|".join(cells)
    text = "\n".join(lines) + "\n"
    # 마지막 자동 반영 줄 갱신
    stamp = datetime.now().strftime("%Y-%m-%d")
    total_line = f"- **마지막 자동 반영**: {stamp} — [자동] 행 {passed}통과 {failed}실패 {skipped}스킵"
    if re.search(r"^- \*\*마지막 자동 반영\*\*:.*$", text, re.M):
        text = re.sub(r"^- \*\*마지막 자동 반영\*\*:.*$", total_line, text, flags=re.M)
    else:
        text = text.replace(
            "> 이 문서는 계속 업데이트하면서 사용한다",
            "> 이 문서는 계속 업데이트하면서 사용한다\n" + total_line,
        )
    DOC.write_text(text, encoding="utf-8")
    return passed, failed, skipped, failed_names


def main() -> int:
    print("[1/3] unit 테스트 실행 중...")
    rc = run_tests()
    bundle = newest_xcresult()
    if bundle is None:
        print("xcresult를 찾지 못했습니다 (빌드 실패 가능).", file=sys.stderr)
        return 2
    print(f"      결과 번들: {bundle.name}")
    results = parse_results(bundle)
    print(f"      파싱된 테스트: {len(results)}건")
    if not results:
        print("테스트 결과를 찾지 못했습니다.", file=sys.stderr)
        return 2
    print("[2/3] 체크리스트 [자동] 행 갱신 중...")
    passed, failed, skipped, failed_names = update_doc(results)
    print(f"[3/3] 완료 — 통과 {passed} / 실패 {failed} / 스킵 {skipped}")
    for name in failed_names:
        print(f"      FAIL: {name}")
    if skipped:
        print("      참고: 스킵 행(**SKIP**)은 수동으로 확인하세요")
    return 1 if failed or rc != 0 else 0


if __name__ == "__main__":
    sys.exit(main())
