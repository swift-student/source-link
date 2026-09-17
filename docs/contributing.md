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

Xcode Cloud uses the committed workspace and runs `ci_scripts/ci_post_clone.sh` to
install XcodeGen if needed and generate the project before building. Make project
changes in `app/project.yml`; generated projects and Info.plist remain ignored.

For an Apple Silicon build without Xcode workspace services, run `bash scripts/build-direct.sh`.
The ad-hoc signed app is written to `.build/direct/source-link.app`, with the CLI at
`Contents/Helpers/source-link` inside the bundle and a standalone copy at `.build/direct/source-link`.
Xcode builds also bundle the CLI at `Contents/Helpers/source-link`. These builds do not install
or launch either executable.


## Prepare a Homebrew release

For a signed and notarized public release, follow [automated GitHub releases](releasing.md).
The command below produces a local, ad-hoc signed build for packaging checks.

```sh
make release
```

This builds a Release app and bundled CLI for Apple Silicon and Intel, then writes
`.build/release/source-link-VERSION.zip` and `.build/release/source-link.rb`.
The cask is generated from [homebrew/source-link.rb.in](../homebrew/source-link.rb.in), with
the app's `CFBundleShortVersionString` and the ZIP's SHA-256 checksum. Its `app` and `binary`
entries let Homebrew install the app and expose the bundled CLI in its own command directory.
Preparing these artifacts does not install the app or change the local Homebrew installation.

The local build uses ad-hoc signing. For public distribution, sign the app and bundled CLI
with a Developer ID Application identity, notarize the app and staple its ticket, then generate
the final archive and cask from that app:

```sh
bash scripts/prepare-homebrew.sh /path/to/signed/source-link.app .build/release
```

The script preserves the app's signature and stapled ticket. Upload the generated ZIP to the
`vVERSION` GitHub release in `swift-student/source-link`, then publish the matching `source-link.rb`
under `Casks/` in the Homebrew tap. Generate the checksum after signing and stapling; it must
match the exact uploaded archive. Neither releases nor tap updates are published automatically.

## Checks and visual review

Run `make check` before submitting changes. It runs core and app unit tests, lint, formatting checks, and the app build.
For UI changes, also run `make ui-test` and `make snapshot-test`. Snapshot tests require Git LFS assets and an unlocked graphical session; see the [snapshot guide](../app/Tests/SettingsSnapshotTests/README.md) for the exact environment and baseline workflow.

Attach screenshots to visual PRs using the [repository instructions](../AGENTS.md). Keep baseline images in Git LFS.

See [architecture](architecture.md) for the code map and [manual verification](verification.md) for editor and configuration checks.
