# Symbol links

Swift, Ruby, Kotlin, and TypeScript files support declaration links:

```text
source-link://my-repo/Sources/Widget.swift?symbol=Widget.refresh(force:)
source-link://my-repo/lib/cart.rb?symbol=Shop::Cart%23add
source-link://my-repo/src/Cart.kt?symbol=shop.Cart.add
source-link://my-repo/src/Cart.ts?symbol=Shop.Cart.add
source-link://my-repo/src/View.tsx?symbol=Shop.View
```

Supported extensions are `.swift`, `.rb`, `.kt`, `.kts`, `.ts`, `.mts`, `.cts`, and `.tsx`,
case-insensitively. TypeScript declaration files such as `.d.ts` are included.
Short names such as `add` work in every language; qualified names follow each language's conventions:

| Language | Qualified name examples |
| --- | --- |
| Swift | `Widget.title`, `Widget.refresh(force:)` |
| Ruby | `Shop::Cart`, `Shop::Cart#add` (instance method), `Shop::Cart.build` (singleton method) |
| Kotlin | `shop.Cart.add` (includes the package), `shop.String.render` (extension receiver) |
| TypeScript / TSX | `Shop.Cart.add`, `Shop.View` (lexical namespaces and declarations) |

In Swift, use a type or property name (`Widget`, `Widget.title`), a function with argument labels
(`Widget.refresh(force:)`), or a short name (`refresh`). Qualified names include enclosing
types and callable argument labels (`Host.outer(value:).inner()`). Members declared in
extensions and associated-value enum cases (`Event.payload(value:)`) are supported.
Ruby, Kotlin, and TypeScript use declaration names without parameter lists.
One match opens immediately. Multiple matches show a borderless floating picker with signatures
and line numbers. Use ↓ or j to move down, ↑ or k to move up, and Enter to open. Escape or
moving focus away dismisses the picker. No matches produce an error.

The file is required, and `symbol` cannot be combined with `line` or `column`. URL-encode
special characters in symbol names, including Ruby's `#` as `%23`. Lookup uses
[SourceSymbols](https://github.com/swift-student/swift-source-symbols) and its bundled
Tree-sitter parsers against the current file on disk, selecting the language by file extension,
without building or indexing the repository. Symbol lookup needs no installed language toolchain
or separate parser executable.
Links survive line changes, but not declaration renames or file moves. Parameter names are
metadata, not link targets, except Kotlin constructor parameters declared with `val`/`var`,
which are properties. Separately declared variables are supported where the language backend
extracts them. Macros, dynamic Ruby declarations, and generated declarations are not supported.

Lookup is syntactic: declarations from all conditional-compilation branches can appear.
Incomplete or unrecognized syntax may yield partial results; recovered declarations remain
navigable even when parsing reports diagnostics. The picker shows declaration headers when
available, otherwise qualified names, alongside line numbers.

## Locations within declarations

Add `find` to target a literal snippet inside a symbol's declaration:

```text
source-link://my-repo/Sources/Store.swift?symbol=Store.commit(_:)&find=outbox.append
```

The resolver searches the entire source range of every matching declaration, including
overloads, headers, comments, strings, and nested declarations. One matching location
opens immediately at the snippet's start. Multiple occurrences show a picker with source
line previews, declaration signatures, and line/column positions, including repeated text
within one method. Overlapping declaration ranges show each physical match only once.
Missing symbols or snippets produce errors; there is no fallback to a declaration or the rest of the file.

`find` requires `symbol`, must be nonempty, and cannot be combined with `line` or `column`.
Matching is case-sensitive and byte-exact: no regex, whitespace normalization, or Unicode
normalization. Spaces, tabs, and newlines are significant; multiline snippets must use the
file's actual newline sequence. Overlapping occurrences count as separate matches.
Percent-encode query values, including `&` as `%26`, `#` as `%23`, and `%` as `%25`;
values are decoded once. SVG/HTML attributes must also escape query separators as `&amp;`.

These links survive inserted lines and moved statements within the selected declaration
as long as the symbol and snippet remain unchanged. Choose a short, distinctive snippet.
[`source-link validate`](validation.md) warns about multiple final locations by default;
`--require-unique-symbols` rejects them after `find` filtering.
