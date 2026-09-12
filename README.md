# Source Link

A macOS 15+ menu-bar utility that opens portable source links in a locally selected editor.

```text
source-link://my-repo/Sources/My%20File.swift?line=42&column=3
```

The repository name in a shared link is the main repository root folder’s name: for example,
`/workspace/my-repo/Sources/File.swift` becomes `source-link://my-repo/Sources/File.swift`.
Repository names map to local checkout/worktree folders in **Settings**. A worktree called
`settings-redesign` still belongs to `my-repo`; its folder name does not replace the shared link identity. Links contain no absolute
local path, branch, or hosting provider. Repository names match case-insensitively. Paths are
URL-encoded and relative to the configured root; traversal and symlinks escaping that root are rejected.
Files must exist. Line and column values must be positive integers; a column requires a line.

## Settings and first-link setup

Settings open automatically on the first unconfigured launch.
Reopening the running app (for example, from Finder) brings Settings forward.
To open Settings from a terminal even on a configured cold launch, use:

```sh
open .build/xcode/Build/Products/Debug/source-link.app --args --settings
```

This also provides a window for computer-use testing without interacting with the menu bar.
For a direct build, substitute `.build/direct/source-link.app`.

- In **Repositories**, choose **Add Repository** and pick the main root folder. Its folder name
  becomes the shared repository name. Use **Add Checkout** within that repository to pick worktrees manually.
- Each repository has exactly one default checkout. The first is selected automatically; **Make Default**
  switches it. Removing the default promotes the first remaining checkout. JSON may omit defaults
  to request the worktree chooser; multiple defaults are errors.
  Existing repository names are preserved so previously shared links continue to work.
- Checkout labels come from their folder names. The action menus can change a folder, reveal it in Finder,
  or remove its mapping; removing a mapping does not delete files.
- Select a default editor and optional extension rules. Rules ignore extension case and a leading dot;
  the first matching rule wins. In **File Rules**, drag rows or use their Move Up/Move Down actions to reorder.
- Built-in launch profiles support Xcode, VS Code, Cursor, and Zed. Install the editor separately and
  expand an editor in **Editors** to adjust or choose its executable path when installed elsewhere.
- An unknown repository prompts for a folder and editor, saves the mapping and extension rule, and opens the file.
- Settings and first-link setup share `~/.config/source-link/config.json` with external editors and agents.
  Settings auto-saves after 500 ms without edits; pending or failed changes do not affect link handling.

Xcode uses `/usr/bin/xed --line` and does not receive a column. VS Code and Cursor use `--goto`;
Zed uses `file:line:column`. Editor arguments are passed directly to `Process`, without shell interpolation.
See the [VS Code CLI](https://code.visualstudio.com/docs/configure/command-line) and
[Zed CLI](https://zed.dev/docs/reference/cli) documentation.

The app remains a menu-bar accessory with no Dock icon. Settings and setup windows appear on request.
Only `source-link:` URLs are supported.
Internal package/project names still use XedLink to preserve the imported build structure.

## JSON configuration and dotfiles

Start with [examples/config.json](examples/config.json). The file uses standard JSON:

```json
{
  "version": 1,
  "default_editor": "cursor",
  "checkouts": [
    { "name": "my-repo", "path": "~/code/my-repo", "default": true }
  ],
  "rules": [
    { "extension": "swift", "editor": "xcode" }
  ]
}
```

| Setting | Required / default | Meaning |
| --- | --- | --- |
| `version` | Required, integer `1` | Configuration schema version. |
| `default_editor` | `"xcode"` | `xcode`, `vscode`, `cursor`, or `zed`. |
| `executables` | Optional | Editor names mapped to executable path overrides. |
| `checkouts` | Optional, empty | Each entry requires `name` and `path`; `default` defaults to `false`. |
| `rules` | Optional, empty | Each entry requires `extension` and `editor`; document order matters. |

Unknown keys, incorrect types, unsupported versions, and multiple defaults for the same
repository are errors. Names and extensions must not be empty. Paths must be absolute or
start with `~/`; `~` expands to the current user's home directory only when used. Shell
variables and commands are not expanded. Missing directories or executables do not invalidate
the configuration; availability is checked when opening a link. UI row IDs are never stored.

The location is `$XDG_CONFIG_HOME/source-link/config.json` when `XDG_CONFIG_HOME` is an
absolute path, otherwise `~/.config/source-link/config.json`. A GUI app launched from Finder
usually does not inherit shell startup variables. Use `source-link config path` to check the
CLI's resolved location, accounting for any different GUI environment. The default location is
recommended for a shared GUI/terminal workflow.

You can symlink the file or its parent directory into a dotfiles repository. Saves follow the
current symlink destination, preserve the symlink and file permissions, and atomically replace
the target. A dangling symlink is an error, not an invitation to create a replacement file.
New files use owner-only permissions.

External changes are checked every second and before handling links, including files replaced
atomically by editors and symlinks replaced by dotfiles tools. Valid settings become active
automatically. Invalid edits leave the last valid settings in memory and display an error in
Settings. At startup, invalid JSON opens Settings with the error and blocks first-link setup
from overwriting it. Restore a removed file to resume editing.

Debounced auto-save merges a draft with the latest file. Independent changes to the default editor,
individual executable overrides, and separate collections can merge. Concurrent edits to the
same field or collection produce a conflict and retain your draft. Adjust the conflicting
setting to match the file, or restart Source Link to discard unsaved changes and load the file.
File creation/deletion or symlink retargeting during a draft also requires restarting before
editing again. First-link setup uses the same save mechanism with explicit confirmation.

Saves rewrite the document as pretty-printed JSON with sorted object keys and preserve array
order. Comments are not supported. Saves recheck disk contents before replacement. This is
optimistic concurrency, not a lock on arbitrary external editors: avoid simultaneous writes
during the final filesystem replacement.

When the configuration file is absent at startup, the app starts with defaults. The file is
created when you save settings or complete first-link setup.

### Agent workflow and CLI

The package includes a separate `source-link` command-line executable:

```sh
swift run source-link config path
swift run source-link config validate
swift run source-link config validate /path/to/proposed-config.json
```

`config path` prints the resolved configuration location. `config validate` reads and checks
the file without opening the app, or writing settings. It exits `0` for valid
configuration, `1` for configuration/read errors, and `2` for usage errors. Diagnostics include
the file path and, for field decoding or validation errors, the setting key when available.
A missing file is a validation error. Validation does not require editors or checkout directories to exist.

An agent should read the latest file, make the smallest necessary edit, and validate it.
Preserve unrelated settings. No `config set` API or UI automation is required.
For a standalone CLI binary, build with `swift build -c release --product source-link`;
`swift build -c release --show-bin-path` prints its containing directory.

## Development

Requires Swift 6.2+, Xcode, XcodeGen, SwiftLint, and SwiftFormat. Install the development tools
with `brew install xcodegen swiftlint swiftformat` (formatting verified with SwiftFormat 0.63.0
and SwiftLint 0.65.1). Tests use native Swift Testing.
Configuration uses Foundation's JSON encoder and decoder without external dependencies.

```sh
make format # Format and auto-correct all repository Swift sources, tests, and scripts
make check  # Tests, strict lint, formatting verification, and app build
make run
```

Settings UI tokens live in `app/Sources/XedLinkApp/SettingsStyle.swift`: use the shared
spacing scale for padding and gaps, and layout tokens for aligned columns and window sizes.
`SettingsComponents.swift` contains shared headings, cards, badges, and action menus.
Keep native control styles and semantic macOS colors so appearance follows system settings.

Run Settings UI automation in a logged-in macOS desktop session:

```sh
make ui-test
```

The XCUITest target launches the app with `--settings`, visits all three pages, and
adds a file rule then verifies it survives a restart. A populated-settings test also
checks checkout defaults, executable-path persistence and reset, and rule reordering
and removal. It uses a temporary settings
file through the Debug-only `SOURCE_LINK_TEST_SETTINGS_PATH` environment variable
and removes it afterward. Release builds always use the normal settings location.
The app and test runner are signed locally with an ad-hoc identity; no development
team is required. Xcode stores results under `.build/xcode/Logs/Test`, including a
retained window screenshots for all three pages and on failure. UI tests use XCTest;
core tests use Swift Testing. Verified screenshots are in `docs/screenshots/settings`.

Open `XedLink.xcworkspace`, or the generated `app/XedLink.xcodeproj`.

For an Apple Silicon build without Xcode workspace services, run `bash scripts/build-direct.sh`.
The ad-hoc signed app is written to `.build/direct/source-link.app`, and the separate CLI to
`.build/direct/source-link`. This does not install or launch either executable.

## Manual verification

1. Open Settings using the command above. Close the window and run the command again to verify it reopens.
   Also verify Settings still opens from the menu-bar icon.
2. Open a `source-link:` URL for an unknown name and a file in your checkout.
3. Choose the repository root and Xcode; verify the requested file and line in Xcode.
4. Install VS Code and select it for `md`; open a Markdown link with a line and column.
5. Add a second checkout under the repository, make it default, and verify the same shared link opens there.
   Remove that checkout and verify the remaining checkout becomes default.
6. Switch among all three Settings pages, reorder competing extension rules, and verify the first rule wins.
7. Change Settings, wait for “All changes saved”, restart the app and verify that mappings and editor rules persist.
8. Try an absent file, an escaping symlink, and an invalid line; verify a visible error and no editor launch.

9. Edit JSON externally and verify the app reloads within a second; repeat with an atomic file replacement.
10. Keep a UI draft open while changing an unrelated setting externally, then wait for auto-save and verify both survive.
11. Change the same setting externally and in a draft; verify auto-save reports a conflict and retains the draft.
12. Introduce invalid JSON; verify the error is visible and existing links use the last valid settings.
13. Symlink the config into dotfiles, auto-save a change, and verify the symlink remains intact.
14. With no configuration file, launch and verify defaults are used; save settings and verify the file is created.

Unit tests cover URL and JSON parsing, schema validation, JSON round-trips, conflicts,
symlink saves, path containment, worktree decisions, file-type routing, and editor
arguments. Real editor navigation requires the manual checks above.

## Source-linked diagrams

The reusable [Source Link Diagrams skill](skills/source-link-diagrams/SKILL.md) creates D2 diagrams with portable code links and a render-and-review workflow. Copy the `skills/source-link-diagrams` directory into your agent's skills directory to install it (for Codex, `~/.codex/skills/`). It requires a D2 renderer; clicking links also requires Source Link with a repository mapping.

See the [example diagrams](examples/diagrams/README.md) for Source Link's URL flow and Click's command dispatch and parameter processing. Editable D2, rendered SVGs, source anchors, and a render script are included. Source line refresh remains agent-driven; no automatic resolver is bundled.
