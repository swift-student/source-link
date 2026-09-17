# Architecture

Source Link has three boundaries:

- `Packages/SourceLinkPackage/Sources/SourceLinkCore`: URL validation, checkout/editor selection, command construction and execution, configuration validation and persistence. It imports Foundation and has no app UI dependency.
- `app/Sources/SourceLinkApp`: menu-bar lifecycle, setup dialogs, settings views, and the observable settings store.
- `Packages/SourceLinkPackage/Sources/SourceLinkCLI`: configuration path and validation commands, independent of the running app.

## Opening a link

`AppDelegate` reloads configuration, parses a `SourceLink`, asks `FirstLinkSetupPresenter` for any missing checkout/editor choice, then uses `SourceSettings.command(for:)` to resolve the file and construct an `EditorCommand`. The process runs off the main actor; errors are presented by the app.

`SourceLink.resolve(root:)` resolves symlinks and requires an existing non-directory file inside the configured root. Shared links contain repository identity and a relative path, so local absolute paths and worktree names do not leak into link identity.

For symbol links, the app runs `SourceSymbolResolver.matches(in:named:find:)` off the main
actor before constructing the editor command. Parsing, optional literal search within all
matching declaration ranges, and UTF-16 position conversion use one immutable source snapshot.
The resolver returns declaration positions or text occurrences in source order, deduplicated
by byte offset. For overlapping declaration ranges, text matches use the innermost matching
declaration's context. The app opens one result or presents multiple results in `SymbolPicker`;
document validation calls the same resolver without UI or process invocation.

`SourceSettings.command(for:)` returns `nil` when the repository has no unambiguous checkout. An unknown repository or multiple checkouts without a default requires setup. Invalid or missing files throw errors. Xcode project discovery prefers the discovered project/workspace for that checkout.

`EditorCommand` constructs argument arrays and invokes `Process` directly. There is no shell interpolation. Tests cover routing, arguments, missing executables, and exit status.

## Editing configuration

`SettingsStore.settings` is the editable draft. `activeSettings` is the last valid configuration used to open links. A 500 ms debounce saves edits; a one-second watcher reloads external changes. Tests inject a controlled delay so cancellation and conflicts are deterministic.

A `ConfigurationSnapshot` contains the decoded document, resolved file target, and existence state. The store retains a base snapshot for three-way merging and an active snapshot for link setup. Independent scalar edits merge; checkout and rule collections conflict as units because UI row identities are not persisted.

`ConfigurationRepository` follows symlinks and atomically replaces the target while preserving permissions. It rechecks disk state immediately before replacement; this is optimistic concurrency, not a lock on external writers.

**Reload from File** cancels pending saves and replaces the draft/base/active state only after a successful read. Read failures retain the draft and last valid active state. Explicit reload may accept file removal as defaults without writing a replacement.

## Reference standards

Use [Apple Swift Argument Parser](https://github.com/apple/swift-argument-parser) for approachable examples and layered documentation, and [Point-Free Swift Dependencies](https://github.com/pointfreeco/swift-dependencies) for controllable external effects and deterministic tests. Keep abstractions proportional to this utility’s size.
