# Source-link direction

## Purpose

Provide portable macOS source links that resolve a file relative to a configured local repository or worktree, then open it in the editor selected for that file type.

## Link format

```text
source-link://<repository-name>/<path-from-repository-root>?line=<positive-integer>&column=<positive-integer>
```

Example:

```text
source-link://source-link/Sources/SourceLinkCore/SourceLink.swift?line=42
```

- `repository-name` is the user-configured repository/workspace name.
- The path is relative to that repository's root.
- `line` and `column` are optional; when supplied, each must be a positive integer.
- Links are intentionally provider-neutral. They do not include a Git host, remote URL, branch, or absolute local path.

## Settings

The app provides a Settings window with:

- **Repositories/workspaces** — a name and one or more local checkout/worktree folders. A repository name resolves to the selected default folder.
- **Editors** — built-in editor profiles plus optional custom launch commands.
- **File-type rules** — map extensions or other file-type identifiers to an editor, with a default editor fallback.

A repository mapping is a local preference and is not embedded in the shared link.

## Opening behavior

1. Parse and validate the `source-link:` URL.
2. Resolve the repository name to configured local folders.
3. If one default folder exists, construct the local file path from its root plus the link path.
4. Select the editor using the matching file-type rule, or the default editor.
5. Invoke the editor adapter with the file path, line, and column.

## First-link setup

When a link refers to an unknown repository/workspace:

1. Show a setup window rather than failing silently.
2. Display the requested repository name and file path.
3. Let the user select the local repository or worktree folder.
4. Let the user select an editor (and optionally make it the default for the relevant file type).
5. Save the mapping, then open the requested file.

When several worktrees are configured for a repository and no default is selected, prompt the user to choose one and optionally save it as the default.

## Compatibility and migration

- `xed:` remains a legacy adapter initially.
- New links use `source-link:`.
- Rename domain types and the app-facing terminology from XedLink/XedURL to SourceLink/SourceLinkURL as implementation moves forward.
- A follow-up implementation PR should add unit tests for parsing, repository resolution, editor selection, and first-link decision logic before wiring the UI.
