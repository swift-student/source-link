# Source Link

A macOS 15+ menu-bar utility that opens portable source links in a locally selected editor.

```text
source-link://my-repo/Sources/My%20File.swift?line=42&column=3
```

Repository names map to local checkout/worktree folders in **Settings**. Links contain no absolute
local path, branch, or hosting provider. Repository names match case-insensitively. Paths are
URL-encoded and relative to the configured root; traversal and symlinks escaping that root are rejected.
Files must exist. Line and column values must be positive integers; a column requires a line.

## Settings and first-link setup

Settings open automatically on the first unconfigured launch.

- Add a repository name and choose its local root folder. Add more rows with the same name for worktrees.
- A single checkout resolves automatically. With multiple checkouts, mark exactly one as default;
  otherwise the next link prompts for a worktree.
- Select a default editor and optional extension rules. Rules ignore extension case and a leading dot;
  the first matching rule wins.
- Built-in launch profiles support Xcode, VS Code, Cursor, and Zed. Install the editor separately and
  adjust its executable path when installed outside the default location.
- An unknown repository prompts for a folder and editor, saves the mapping and extension rule, and opens the file.
- Settings are stored in `~/Library/Application Support/SourceLink/settings.json`.

Xcode uses `/usr/bin/xed --line` and does not receive a column. VS Code and Cursor use `--goto`;
Zed uses `file:line:column`. Editor arguments are passed directly to `Process`, without shell interpolation.
See the [VS Code CLI](https://code.visualstudio.com/docs/configure/command-line) and
[Zed CLI](https://zed.dev/docs/reference/cli) documentation.

The app remains a menu-bar accessory with no Dock icon. Settings and setup windows appear on request.
Legacy `xed:///absolute/path?line=42&project=/absolute/project.xcworkspace` links remain supported.
Internal package/project names still use XedLink to preserve the imported build structure.

## Development

Requires Swift 6.2+, Xcode, XcodeGen, and SwiftLint. Tests use native Swift Testing without external dependencies.

```sh
make check
make run
```

Open `XedLink.xcworkspace`, or the generated `app/XedLink.xcodeproj`.

For an Apple Silicon build without Xcode workspace services, run `bash scripts/build-direct.sh`.
The ad-hoc signed app is written to `.build/direct/source-link.app`. This does not install or launch it.

## Manual verification

1. Run the app and open Settings from its menu-bar icon.
2. Open a `source-link:` URL for an unknown name and a file in your checkout.
3. Choose the repository root and Xcode; verify the requested file and line in Xcode.
4. Install VS Code and select it for `md`; open a Markdown link with a line and column.
5. Add a second worktree with the same name and clear defaults; verify the chooser and saved default.
6. Restart the app and verify that mappings and editor rules persist.
7. Try an absent file, an escaping symlink, and an invalid line; verify a visible error and no editor launch.
8. Try a legacy `xed:` link, including its optional project parameter.

Unit tests cover parsing, invalid inputs, path containment, worktree decisions, settings round-trips,
file-type routing, and editor arguments. Real editor navigation requires the manual checks above.

## Planned follow-up

Polish the Settings interface and add TOML dotfile configuration. This version stores settings in JSON.
