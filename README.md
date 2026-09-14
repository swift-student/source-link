# Source Link

A macOS 15+ menu-bar utility that opens portable source links in your preferred local editor.
Share a link once; each person maps the repository to their own checkout or worktree.

```text
source-link://my-repo/Sources/My%20File.swift?line=42&column=3
```

![Source Link Settings](docs/assets/settings.png)

Supports Xcode, VS Code, Cursor, Zed, Android Studio, IntelliJ IDEA, Sublime Text, and custom editor profiles. Runs in the menu bar with no Dock icon.

## Swift symbol links

Swift files also support declaration links:

```text
source-link://my-repo/Sources/Widget.swift?symbol=Widget.refresh(force:)
```

Use a type or property name (`Widget`, `Widget.title`), a function with argument labels
(`Widget.refresh(force:)`), or a short name (`refresh`). Qualified names include enclosing
types and callable argument labels (`Host.outer(value:).inner()`). Members declared in
extensions and associated-value enum cases (`Event.payload(value:)`) are supported.
One match opens immediately. Multiple matches show a selection window with signatures and
line numbers; use the arrow keys and
Enter to open, or Escape to cancel. No matches produce an error.

The file is required, and `symbol` cannot be combined with `line` or `column`. URL-encode
special characters in symbol names. Lookup uses
[SourceSymbols](https://github.com/swift-student/swift-source-symbols) and its bundled
Tree-sitter Swift parser against the current file on disk, without building or indexing the
repository. Symbol lookup needs no installed Swift toolchain or separate parser executable.
Links survive line changes, but not declaration renames or file moves. Parameter names are
metadata, not link targets; separately declared local variables are supported. Macros and
generated declarations are not supported.

Lookup is syntactic: declarations from all conditional-compilation branches can appear.
Incomplete or unrecognized syntax may yield partial results; recovered declarations remain
navigable even when parsing reports diagnostics. The picker shows declaration headers when
available, otherwise qualified names, alongside line numbers.

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

Open a link to the README:

```sh
open 'source-link://source-link/README.md?line=1'
```

Source Link prompts you to choose the repository’s local folder and an editor, then opens
the file. No Settings changes are needed beforehand. You can manage repository mappings
and editors in Settings later.

## Guides

- [Usage and link format](docs/usage.md): repositories, worktrees, editor routing, and path rules.
- [Configuration](docs/configuration.md): JSON reference, dotfiles, external edits, and CLI validation.
- [Troubleshooting](docs/troubleshooting.md): setup, editor failures, and save recovery.
- [Contributing](docs/contributing.md): build tools, tests, formatting, and visual review.
- [Architecture](docs/architecture.md): code map and design decisions.
- [Source-linked diagrams](examples/diagrams/README.md): examples and the reusable [diagram skill](skills/source-link-diagrams/SKILL.md).
