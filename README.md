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
  switches it. Removing the default promotes the first remaining checkout. Existing settings with missing
  or multiple defaults are repaired on load, retaining the first marked default (or the first checkout).
  Existing repository names are preserved so previously shared links continue to work.
- Checkout labels come from their folder names. The action menus can change a folder, reveal it in Finder,
  or remove its mapping; removing a mapping does not delete files.
- Select a default editor and optional extension rules. Rules ignore extension case and a leading dot;
  the first matching rule wins. In **File Rules**, drag rows or use their Move Up/Move Down actions to reorder.
- Built-in launch profiles support Xcode, VS Code, Cursor, and Zed. Install the editor separately and
  expand an editor in **Editors** to adjust or choose its executable path when installed elsewhere.
- An unknown repository prompts for a folder and editor, saves the mapping and extension rule, and opens the file.
- Settings are stored in `~/Library/Application Support/SourceLink/settings.json`.

Xcode uses `/usr/bin/xed --line` and does not receive a column. VS Code and Cursor use `--goto`;
Zed uses `file:line:column`. Editor arguments are passed directly to `Process`, without shell interpolation.
See the [VS Code CLI](https://code.visualstudio.com/docs/configure/command-line) and
[Zed CLI](https://zed.dev/docs/reference/cli) documentation.

The app remains a menu-bar accessory with no Dock icon. Settings and setup windows appear on request.
Only `source-link:` URLs are supported.
Internal package/project names still use XedLink to preserve the imported build structure.

## Development

Requires Swift 6.2+, Xcode, XcodeGen, and SwiftLint. Tests use native Swift Testing without external dependencies.

```sh
make check
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
The ad-hoc signed app is written to `.build/direct/source-link.app`. This does not install or launch it.

## Manual verification

1. Open Settings using the command above. Close the window and run the command again to verify it reopens.
   Also verify Settings still opens from the menu-bar icon.
2. Open a `source-link:` URL for an unknown name and a file in your checkout.
3. Choose the repository root and Xcode; verify the requested file and line in Xcode.
4. Install VS Code and select it for `md`; open a Markdown link with a line and column.
5. Add a second checkout under the repository, make it default, and verify the same shared link opens there.
   Remove that checkout and verify the remaining checkout becomes default.
6. Switch among all three Settings pages, reorder competing extension rules, and verify the first rule wins.
7. Restart the app and verify that mappings and editor rules persist.
8. Try an absent file, an escaping symlink, and an invalid line; verify a visible error and no editor launch.

Unit tests cover parsing, invalid inputs, path containment, worktree decisions, settings round-trips,
file-type routing, and editor arguments. Real editor navigation requires the manual checks above.

## Planned follow-up

Add TOML dotfile configuration. This version stores settings in JSON.
