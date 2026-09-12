# Contributing

Requires Swift 6.2+, Xcode, XcodeGen, SwiftLint, and SwiftFormat. Install the development tools
with `brew install xcodegen swiftlint swiftformat` (formatting verified with SwiftFormat 0.63.0
and SwiftLint 0.65.1). Tests use native Swift Testing.
Configuration uses Foundation's JSON encoder and decoder without external dependencies.

```sh
make format # Format and auto-correct all repository Swift sources, tests, and scripts
make check  # Core and app unit tests, strict lint, formatting verification, and app build
make run
```

Settings UI tokens live in `app/Sources/SourceLinkApp/SettingsStyle.swift`: use the shared
spacing scale for padding and gaps, and layout tokens for aligned columns and window sizes.
`SettingsComponents.swift` contains shared headings, cards, badges, and action menus.
Keep native control styles and semantic macOS colors so appearance follows system settings.

Run Settings UI automation in a logged-in macOS desktop session:

```sh
make ui-test
```

The XCUITest target launches the app with `--settings`, visits both pages, and
adds a file rule then verifies it survives a restart. A populated-settings test also
checks checkout defaults, default-editor persistence, and rule selection
and removal. It uses a temporary settings
file through the Debug-only `SOURCE_LINK_TEST_SETTINGS_PATH` environment variable
and removes it afterward. Release builds always use the normal settings location.
The app and test runner are signed locally with an ad-hoc identity; no development
team is required. Xcode stores results under `.build/xcode/Logs/Test`, including
retained window screenshots for both pages and on failure. UI tests use XCTest;
core tests use Swift Testing. Verified screenshots are in `docs/screenshots/settings` (historical captures; current baselines are in `app/Tests/SettingsSnapshotTests`).

Run `make generate` once, then `xed .` from the repository root to open
`SourceLink.xcworkspace`. The Swift package lives in `Packages/SourceLinkPackage`,
leaving the workspace as the root Xcode entry point.

For an Apple Silicon build without Xcode workspace services, run `bash scripts/build-direct.sh`.
The ad-hoc signed app is written to `.build/direct/source-link.app`, and the separate CLI to
`.build/direct/source-link`. This does not install or launch either executable.


## Checks and visual review

Run `make check` before submitting changes. It runs core and app unit tests, lint, formatting checks, and the app build.
For UI changes, also run `make ui-test` and `make snapshot-test`. Snapshot tests require Git LFS assets and an unlocked graphical session; see the [snapshot guide](../app/Tests/SettingsSnapshotTests/README.md) for the exact environment and baseline workflow.

Attach screenshots to visual PRs using the [repository instructions](../AGENTS.md). Keep baseline images in Git LFS.

See [architecture](architecture.md) for the code map and [manual verification](verification.md) for editor and configuration checks.
