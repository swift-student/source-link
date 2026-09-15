# Configuration and dotfiles

Start with [examples/config.json](../examples/config.json). The file uses standard JSON:

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
| `default_editor` | `"xcode"` | `xcode`, `vscode`, `cursor`, `zed`, `android-studio`, `idea`, `sublime`, or a configured custom editor ID. |
| `editors` | Optional, built-in profiles | Editor IDs mapped to command profiles; custom profiles replace matching defaults. |
| `checkouts` | Optional, empty | Each entry requires `name` and `path`; `default` defaults to `false`. |
| `rules` | Optional, empty | Each entry requires `extension` and `editor`; document order matters. |

Define commands as an executable and argument arrays. For example, add this top-level
`editors` field to override IDEA's command (or use a new ID to add another editor):

```json
"editors": {
  "idea": {
    "name": "IntelliJ IDEA",
    "executable": "/Applications/IntelliJ IDEA.app/Contents/MacOS/idea",
    "arguments": ["{file}"],
    "line_arguments": ["--line", "{line}", "{file}"],
    "column_arguments": ["--line", "{line}", "--column", "{column}", "{file}"]
  }
}
```

`name`, `executable`, and `arguments` are required for each profile. Editor IDs use
lowercase letters, digits, hyphens, or underscores. Custom editors appear in all editor pickers.
The default editor and extension rules must reference an available profile.

- No position: use `arguments` (only the `{file}` placeholder is allowed).
- Line: use `line_arguments`, falling back to `arguments`.
- Line and column: use `column_arguments`, falling back to `line_arguments`, then `arguments`.

An optional `project_arguments` prefix supports `{project}` and is added only when
a project is discovered. The bundled Xcode profile uses it to preserve project/workspace opening.

Templates support `{file}` (absolute resolved path), `{line}`, and `{column}`;
a missing column defaults to 1 in a line template. Every argument list must contain `{file}`.
Each array element is one process argument. Do not add shell quotes around placeholders:
spaces and shell metacharacters in filenames are preserved literally. Unknown placeholders,
null characters, and literal braces in templates are rejected.

Built-in names, executable paths, and argument templates are loaded from
`Packages/SourceLinkPackage/Sources/SourceLinkCore/Resources/editors.json`, using the same profile format as user config.
Adding a bundled editor only requires adding its JSON profile; pickers discover it automatically.
Saving writes the effective profiles
into `editors`, making commands editable in JSON. Omitted built-in profiles are restored from
defaults; removing a custom profile requires removing references to it as well.
The **Editors** page contains file-type rules and a default editor for all other files.
**Edit Configuration…** writes the effective profiles to `config.json` and opens it in the
system-associated application (or reveals it in Finder if no app can open it).
Executable paths and arguments are edited together in that file, manually or with an agent.
Invalid configuration is opened for repair without overwriting it.
The `executables` field is not supported and is rejected.

Unknown keys, incorrect types, unsupported versions, and multiple defaults for the same
repository are errors. Names and extensions must not be empty. Paths must be absolute or
start with `~/`; `~` expands to the current user's home directory only when used. Shell
variables and commands are not expanded. Missing directories or executables do not invalidate
the configuration; availability is checked when opening a link. UI row IDs are never stored.

JSON may contain multiple rules for the same normalized extension; the first matching rule wins.
Settings displays these rules but blocks auto-save until duplicates are removed. First-link setup
replaces all rules matching the chosen file extension with the selected editor.

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

Debounced auto-save merges a draft with the latest file. Independent changes to editor profiles (per editor ID), the default editor,
and separate collections can merge. Concurrent edits to the
same field or collection produce a conflict and retain your draft. Adjust the conflicting
setting to match the file, or choose **Reload from File** in the error alert to load the file.
File creation/deletion or symlink retargeting during a draft also requires **Reload from File** before
editing again. First-link setup uses the same save mechanism with explicit confirmation.

Saves rewrite the document as pretty-printed JSON with sorted object keys and preserve array
order. Comments are not supported. Saves recheck disk contents before replacement. This is
optimistic concurrency, not a lock on arbitrary external editors: avoid simultaneous writes
during the final filesystem replacement.

When the configuration file is absent at startup, the app starts with defaults. The file is
created when you save settings or complete first-link setup.

### Agent workflow and CLI

The app bundles a compiled `source-link` command-line executable. With the Homebrew cask installed:

```sh
source-link config path
source-link config validate
source-link config validate /path/to/proposed-config.json
```

`config path` prints the resolved configuration location. `config validate` reads and checks
the file without opening the app, or writing settings. It exits `0` for valid
configuration, `1` for configuration/read errors, and `2` for usage errors. Diagnostics include
the file path and, for field decoding or validation errors, the setting key when available.
A missing file is a validation error. Validation does not require editors or checkout directories to exist.

An agent should read the latest file, make the smallest necessary edit, and validate it.
Preserve unrelated settings. No `config set` API or UI automation is required.
For a standalone CLI binary, build with `swift build --package-path Packages/SourceLinkPackage -c release --product source-link`;
`swift build --package-path Packages/SourceLinkPackage -c release --show-bin-path` prints its containing directory.

For development, prefix the command with `swift run --package-path Packages/SourceLinkPackage`.
See [document validation](validation.md) for `source-link validate DOCUMENT`.
