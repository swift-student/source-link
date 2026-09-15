# Validate links in a document

```sh
source-link validate docs/architecture.md
source-link validate diagram.svg --config /path/to/config.json
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
Multiple matches are valid: the app offers a picker when opening such a link. Missing
symbols fail validation without opening a picker.

Links with positions also require a UTF-8 target and an in-range line and column.
Positions are one-based; columns count Unicode characters, with a tab counting as one.
The position immediately after a line's last character is valid, and a trailing newline
creates an empty final line. This checks that a position exists, not that it still points
to the intended declaration after code changes.

Each failure is printed to standard error as `DOCUMENT:LINE:COLUMN: reason [URL]`, using
the URL's location in the document. A summary goes to standard output. Exit status is
`0` when all links pass (including an explicit “no source links found” result), `1` for
invalid links or configuration/read errors, and `2` for usage errors.
The longer `source-link links validate` spelling remains an alias.
