# Source Link

Source Link opens shared code links in your local checkout. You choose the editor
and the checkout; the link stays the same.

```text
source-link://my-repo/Sources/App.swift?line=42&column=3
```

That link opens `Sources/App.swift` at the requested position, wherever you've put
`my-repo`. It can point to your main checkout today and a worktree tomorrow.
There are no machine-specific paths or editor preferences in the URL.

Source Link runs in the macOS menu bar, with no Dock icon. It requires **macOS 15
or later** and supports Xcode, VS Code, Cursor, Zed, Android Studio, IntelliJ IDEA,
Sublime Text, and custom editor profiles. Xcode opens at the requested line and
ignores the column.

![Source Link Settings](docs/assets/settings.png)

## Try it

Install via Homebrew:

```sh
brew install --cask swift-student/tap/source-link
```

Open **Source Link** from Applications once to register its link handler. The cask
also installs the `source-link` CLI.

With a local checkout of this repository, try opening its README:

```sh
open 'source-link://source-link/README.md?line=1'
```

Source Link asks for the local repository folder and an editor, then opens the
file. It remembers your choice. To change it later, open Settings from the
menu-bar icon or reopen the running app from Finder.

## See it in use

The same links work from a terminal or a diagram. This 24-second demo follows
both kinds of links into Swift declarations in Xcode:

https://github.com/user-attachments/assets/2fc71909-127a-4938-9d0c-16b8aa728b77

## Writing links

Use the main repository folder's name and a path relative to its root. Each
person maps that name to their own local folder. For worktrees, use **Add
Checkout** under the existing repository, then **Make Default** to choose where
links open. A worktree named `settings-redesign` still uses `my-repo` in its links.

You can link to a line, a declaration, or a piece of text within a declaration:

```text
source-link://my-repo/Sources/Store.swift?line=42&column=3
source-link://my-repo/Sources/Store.swift?symbol=Store.commit(_:)
source-link://my-repo/Sources/Store.swift?symbol=Store.commit(_:)&find=outbox.append
```

Symbol links work with Swift, Ruby, Kotlin, and TypeScript/TSX. They resolve
against the file on disk without building or indexing the project. One match
opens immediately; several matches give you a picker. The optional `find` value
matches literal text inside the declaration.

Use a symbol when you want a link to survive inserted lines. Links still depend
on the file path and declaration name, and they don't pin a branch or commit.
URL-encode spaces and special characters in paths and query values.

See [usage and path rules](docs/usage.md) and the
[symbol-link reference](docs/symbol-links.md) for naming conventions, encoding,
text matching, and lookup limits.

## Diagrams that open the code

A diagram can double as a way into the implementation. This simulated call stack
links each frame to its Swift declaration:

![Simulated call stack: SourceLink.resolve, SourceSettings.command, AppDelegate.open](examples/diagrams/stack-trace.png)

[Download the clickable SVG](examples/diagrams/stack-trace.svg?raw=1) and open it
as a document, then click a frame. Map `source-link` to your checkout first.
The image above is a static preview; the [D2 source](examples/diagrams/stack-trace.d2)
is editable.

The [interactive explainer](https://swiftstudent.com/source-link/) walks through
how a link reaches your editor. For more examples and the reusable diagram skill,
see [source-linked diagrams](examples/diagrams/README.md).

## Settings and validation

Settings manages repository mappings, the default editor, and file-extension
rules. Changes save automatically to `~/.config/source-link/config.json`. You can
also edit that file directly or symlink it into your dotfiles; valid changes
reload automatically.

The bundled CLI checks links in documents without opening an editor:

```sh
source-link validate notes.md
```

Add `--require-unique-symbols` to reject ambiguous matches in CI. See the
[validation guide](docs/validation.md) for supported documents and diagnostics,
and the [configuration reference](docs/configuration.md) for editor profiles,
config locations, and external edits.

## Development

Building from source requires Xcode with Swift 6.2 or later:

```sh
brew install xcodegen swiftlint swiftformat
git clone https://github.com/swift-student/source-link.git
cd source-link
make check
make run
```

`make run` builds and opens `.build/xcode/Build/Products/Debug/source-link.app`.

`make check` runs core and app unit tests, strict lint, formatting checks, and an
app build. Run `make format` to format the Swift sources.

- [Contributing](docs/contributing.md): workspace setup, UI tests, and visual review.
- [Architecture](docs/architecture.md): code layout and design decisions.
- [Troubleshooting](docs/troubleshooting.md): setup, editor failures, and settings recovery.
- [Releases](docs/releasing.md): signing, notarization, and Homebrew distribution.
- [Site development](site/README.md): the interactive explainer and its deployment.
