# Source Link

A macOS 15+ menu-bar utility that opens portable source links in your preferred local editor.
Share a link once; each person maps the repository to their own checkout or worktree.

```text
source-link://my-repo/Sources/My%20File.swift?line=42&column=3
```

![Source Link Settings](docs/assets/settings.png)

Supports Xcode, VS Code, Cursor, Zed, Android Studio, IntelliJ IDEA, Sublime Text, and custom editor profiles. Runs in the menu bar with no Dock icon.

## Build and run

Requires macOS 15+, Xcode with Swift 6.2+, and these development tools:

```sh
brew install xcodegen swiftlint swiftformat
git clone https://github.com/swift-student/source-link.git
cd source-link
make run
```

This builds and opens `.build/xcode/Build/Products/Debug/source-link.app`.
To keep the app, copy it to Applications. Install your preferred editor separately.

## Open your first link

1. In Settings, choose **Add Repository** and select this repository’s root folder (`source-link`).
2. Select your editor in **Editors** and allow a moment for autosave.
3. Open a link to the README:

   ```sh
   open 'source-link://source-link/README.md?line=1'
   ```

The README opens in your selected editor. For an unknown repository, opening a link prompts you to choose its local folder and editor.

Settings auto-saves after 500 ms without edits. Pending or failed edits do not affect link handling.
If saving fails, an alert offers **Keep Editing** or **Reload from File**. Reloading discards unsaved edits.

## Guides

- [Usage and link format](docs/usage.md): repositories, worktrees, editor routing, and path rules.
- [Configuration](docs/configuration.md): JSON reference, dotfiles, external edits, and CLI validation.
- [Troubleshooting](docs/troubleshooting.md): setup, editor failures, and save recovery.
- [Contributing](docs/contributing.md): build tools, tests, formatting, and visual review.
- [Architecture](docs/architecture.md): code map and design decisions.
- [Source-linked diagrams](examples/diagrams/README.md): examples and the reusable [diagram skill](skills/source-link-diagrams/SKILL.md).
