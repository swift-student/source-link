# Validate links in a document

```sh
source-link validate docs/architecture.md
source-link validate diagram.svg --config /path/to/config.json
source-link validate --require-unique-symbols docs/architecture.md
cat docs/architecture.md | source-link validate -
```

`validate` checks every literal `source-link:` URL in a UTF-8 document, including
examples in code blocks and repeated links. It accepts Markdown, plain text, D2, SVG, and
HTML. Other URL schemes are ignored; PDF and Word files must first be exported to text.
Markdown and SVG/HTML/XML files, and standard input, decode markup entities such as `&amp;`
in URLs (inline backtick literals are preserved). Paths must be URL-encoded. Quote or
percent-encode trailing punctuation when it belongs to a filename; bare links treat
trailing sentence punctuation and unmatched closing brackets as document delimiters.

Validation uses the same repository mappings, default checkout selection, URL parser,
and path containment checks as the app. Unknown repositories, ambiguous checkouts,
missing files, directories, and escaping symlinks fail validation. The configuration
must exist and be valid; `--config FILE` selects a different configuration without changing settings.
Validation only reads files and never launches an editor or opens setup windows.

Swift symbol links must match at least one declaration using the app's symbol resolver.
When a link matches multiple declarations, validation prints a warning with the match
count and each candidate's signature and source file, line, and column. These links
pass by default because the app offers a picker when opening them. Missing symbols fail
validation without opening a picker.

Use `--require-unique-symbols` to treat ambiguous symbol links as errors, for example in
CI. Ambiguous links then count as invalid and cause exit status `1`. The summary always
includes the number of ambiguous links, counting repeated occurrences separately.

For example, a link to two overloads produces a diagnostic like this:

```text
docs/architecture.md:8:11: warning: symbol link matches 2 declarations [source-link://repo/Widget.swift?symbol=Widget.refresh(force:)]
  /checkout/Widget.swift:2:8: Widget: func refresh(force: Bool)
  /checkout/Widget.swift:3:8: Widget: func refresh(force: Int)
docs/architecture.md: 1 source links checked, 0 invalid, 1 ambiguous
```

The diagnostic's first location points into the document; indented locations point to
candidate declarations. Candidate columns use the resolver's one-based UTF-16 positions.

Links with positions also require a UTF-8 target and an in-range line and column.
Positions are one-based; columns count Unicode characters, with a tab counting as one.
The position immediately after a line's last character is valid, and a trailing newline
creates an empty final line. This checks that a position exists, not that it still points
to the intended declaration after code changes.

Each failure is printed to standard error as `DOCUMENT:LINE:COLUMN: error: reason [URL]`,
using the URL's location in the document. Ambiguity warnings also go to standard error.
A summary goes to standard output. Exit status is
`0` when all links pass (including an explicit “no source links found” result), `1` for
invalid links or configuration/read errors, and `2` for usage errors.
The longer `source-link links validate` spelling remains an alias.

## Command help and completion

The CLI uses Swift Argument Parser. Options may appear before or after the document.
Use `--` before a document name beginning with a dash, such as
`source-link validate --config config.json -- -notes.md`.

```sh
source-link --help
source-link validate --help
source-link config validate --help
source-link --generate-completion-script zsh
```

The last command prints a completion script; `bash` and `fish` are also supported.
Invoking `source-link`, `source-link config`, or `source-link links` without a subcommand
displays help and exits successfully.
