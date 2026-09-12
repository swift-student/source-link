# Using Source Link

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
- Select a default editor and optional extension rules. Rules ignore extension case and surrounding dots and spaces.
  In **Editors**, use + to add a rule and − or swipe to remove one. Settings requires one rule per extension.
- Built-in launch profiles support Xcode, VS Code, Cursor, Zed, Android Studio, IntelliJ IDEA, and Sublime Text. Install the editor separately and
  use **Edit Configuration…** in **Editors** to configure its executable and arguments.
- An unknown repository prompts for a folder and editor, saves the mapping and extension rule, and opens the file.
- Settings and first-link setup share `~/.config/source-link/config.json` with external editors and agents.
  Settings auto-saves after 500 ms without edits; pending or failed changes do not affect link handling.

By default, Xcode uses `/usr/bin/xed --line` and does not receive a column. VS Code and Cursor use `--goto`;
Zed and Sublime Text use `file:line:column`. Android Studio and IntelliJ IDEA use
`--line` and `--column` with their bundled macOS launchers. Editor arguments are passed directly to `Process`,
without shell interpolation.

These profiles default to apps in `/Applications`. For JetBrains Toolbox, older IDEA
Community installations, or renamed apps, set the executable path in the configuration file:
`Contents/MacOS/studio` or `Contents/MacOS/idea`. Sublime Text uses
`Contents/SharedSupport/bin/subl`. No separate shell launcher installation is required.
See the [VS Code CLI](https://code.visualstudio.com/docs/configure/command-line) and
[Zed CLI](https://zed.dev/docs/reference/cli),
[IntelliJ IDEA CLI](https://www.jetbrains.com/help/idea/opening-files-from-command-line.html), and
[Sublime Text CLI](https://www.sublimetext.com/docs/command_line.html) documentation.

The app remains a menu-bar accessory with no Dock icon. Settings and setup windows appear on request.
Only `source-link:` URLs are supported.
Package, module, and Xcode project names use `SourceLink`; the app and URL scheme use `source-link`.

