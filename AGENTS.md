# AGENTS.md — ApexKey

macOS menu-bar launcher (SwiftUI + AppKit, Swift 5.9, macOS 14+). Bundle ID `com.borasarang.ApexKey`. macOS-only — never add other platform targets or change the bundle ID.

## Build / Test (use this, nothing else)

```bash
xcodegen generate --spec project.yml   # .xcodeproj is gitignored; always regenerate first
./build_and_run.sh debug macos         # build + install to ~/Applications + relaunch
./build_and_run.sh test macos unit     # scopes: smoke (fast regression subset) | unit (default, full suite) | full
```

- `xcodebuild` only — `swift build/test` does not work for this project.
- CI (`.github/workflows/ci.yml`) runs: localizable guard → version guard → Debug build (`CODE_SIGNING_ALLOWED=NO`) → unit tests.
- Local builds sign with `DEVELOPMENT_TEAM=6GPJQ7BQC9`; keep it — ad-hoc signing breaks TCC/Accessibility permission persistence across rebuilds.

## Guards that fail the build (run automatically in `build_and_run.sh`)

- `scripts/check-localizable.py` — every user-visible string must go through `.localized` / `.localizedFormat` (`en.lproj/` + `ko.lproj/`). Raw Korean literals in `Sources/` fail unless they match a documented allowlist (logs, comments, seed/migration data, `preconditionFailure`, shell-script output). Run it before committing UI text.
- `scripts/check-version.py` — version single source is `project.yml` `MARKETING_VERSION` (+ `CURRENT_PROJECT_VERSION`). Never edit `Info.plist` version strings directly; they must stay as `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)` refs.

## Architecture

- Entry: `Sources/ApexKey/main.swift` → `AppDelegate` (split: `AppDelegate+*.swift` — StatusItem, Menus, Windows, Windowing, PaletteHUD, URLScheme). `LSUIElement=true`, no Dock icon.
- `Sources/ApexKey/`: `Views/` (SwiftUI panels/HUD), `Models/`, `Services/` (real logic: `HotKeyService`, `MenuEnumerator`, `ExecutionEngine`, `ActionExecutor`, `ConfigStore/`), `Utils/`.
- `Sources/ApexKeyTests/` (~37 files) — unit tests wired via `ApexKeyTests` target depending on `ApexKey` target.
- Key tech constraints: global hotkeys via Carbon `RegisterEventHotKey`; cross-app menu execution via `AXUIElement` (needs Accessibility permission); persistence via SwiftData (`ConfigStore`); custom URL scheme `apexkey://`.
- Localization identity: English `ApexKey`, Korean `애펙스키` via `LSHasLocalizedDisplayName=true` + `ko.lproj/InfoPlist.strings` (UTF-16) — do not remove.

## Conventions

- `Resources/Assets.xcassets` holds `AppIcon` + `MenuBarIcon`; `Resources/scrcpy_run.sh` ships as a resource bundle file.
- Docs that matter: `docs/TODO.md`, `docs/FUNCTIONAL_CHECKLIST.md`, `docs/DESIGN.md`, `docs/CHANGELOG.md`.
