# AGENTS.md — ApexKey

macOS menu-bar launcher (SwiftUI + AppKit, Swift 5.9, macOS 14+). Bundle ID `com.borasarang.ApexKey`. macOS-only — never add other platform targets or change the bundle ID.

## Build / Test (use this, nothing else)

```bash
xcodegen generate --spec project.yml   # .xcodeproj is gitignored; always regenerate first
./build_and_run.sh debug macos         # build + install to ~/Applications + relaunch
./build_and_run.sh test macos unit     # scopes: smoke (fast filtered subset) | unit (default, full suite) | full
```

- `xcodebuild` only — `swift build/test` does not work for this project.
- Single test: `xcodebuild test -project ApexKey.xcodeproj -scheme ApexKey -destination 'platform=macOS' -only-testing:ApexKeyTests/<Suite>/<testMethod>` (after `xcodegen generate`).
- Local builds sign with `DEVELOPMENT_TEAM=6GPJQ7BQC9`; keep it — ad-hoc signing breaks TCC/Accessibility permission persistence across rebuilds. CI uses `CODE_SIGNING_ALLOWED=NO`, so local pass ≠ CI pass for permission-dependent tests (e.g. `MenuActionPathTests` skips via `XCTSkipUnless` without a real Accessibility grant).
- New code: verify with a clean build — incremental builds hide warnings (baseline is warning-free).

## Guards that fail the build (run automatically in `build_and_run.sh`)

- `scripts/check-localizable.py` — every user-visible string must go through `.localized` / `.localizedFormat` (`en.lproj/` + `ko.lproj/`). Scans `Sources/ApexKey/` only (test fixtures exempt); allowlist is documented in the script header (logs, comments, seed/migration data, `preconditionFailure`, shell-script output).
- **The guard does NOT check key existence.** A missing `Localizable.strings` key passes the gate and shows as a raw key in the UI. When adding UI text, add the key to both `en.lproj/Localizable.strings` and `ko.lproj/Localizable.strings`.
- `scripts/check-version.py` — version single source is `project.yml` `MARKETING_VERSION` (+ `CURRENT_PROJECT_VERSION`). Never edit `Info.plist` version strings directly; they must stay as `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)` refs.

## Release

- Tag `vX.Y.Z` must exactly equal `MARKETING_VERSION` or `release.yml` fails the build. Bump procedure: edit `MARKETING_VERSION` in `project.yml` → commit → tag.
- Optional body: `release-notes/<tag>.md` (e.g. `release-notes/v1.3.0.md`); missing file falls back to auto-generated notes. Single artifact: `ApexKey-<version>-macOS.dmg`.
- Release builds are unsigned/unnotarized (no Developer ID enrollment): first launch needs right-click → Open, and Accessibility permission must be re-granted on every version update. Do not present this as a defect.

## Architecture

- Entry: `Sources/ApexKey/main.swift` → `AppDelegate` (split: `AppDelegate+*.swift` — StatusItem, Menus, Windows, Windowing, PaletteHUD, URLScheme). `LSUIElement=true`, no Dock icon.
- `Sources/ApexKey/`: `Views/` (SwiftUI panels/HUD), `Models/`, `Services/` (real logic: `HotKeyService`, `MenuEnumerator`, `ExecutionEngine`, `ActionExecutor`, `ConfigStore/`), `Utils/`.
- `Sources/ApexKeyTests/` (~37 files) — unit tests wired via `ApexKeyTests` target depending on `ApexKey` target.
- Key tech constraints: global hotkeys via Carbon `RegisterEventHotKey`; cross-app menu execution via AppleScript/`System Events` + `AXUIElement` enumeration (needs Accessibility permission); persistence via SwiftData at `~/Library/Application Support/com.borasarang.ApexKey/` (dedicated path — the default shared `default.store` collides with other SwiftData apps); custom URL scheme `apexkey://`.
- Localization identity: English `ApexKey`, Korean `애펙스키` via `LSHasLocalizedDisplayName=true` + `ko.lproj/InfoPlist.strings` (UTF-16) — do not remove.

## Conventions

- `Resources/Assets.xcassets` holds `AppIcon` + `MenuBarIcon`; `Resources/scrcpy_run.sh` ships as a resource bundle file.
- Docs: start at `docs/README.md` (index) → `docs/STATUS.md` (current state) → `docs/OPEN_ITEMS.md` (agent-can't-do list: manual device steps, PRs). `docs/FUNCTIONAL_CHECKLIST.md` is an audit snapshot and goes stale — always re-verify against code before acting on it. `T-` task tracking lives in `docs/TODO.md` (`[~]` = intentionally dropped, do not revive).
