---
name: source-link-diagrams
description: Create or update D2 diagrams with clickable Source Link URLs into local source code, render SVGs, and visually review their layout. Use for source-linked architecture and code-flow diagrams.
---

# Source-linked D2 diagrams

Deliver editable `.d2` source and a visually reviewed `.svg` with portable source links. Keep repository mappings and source provenance alongside the artifacts. This skill does not require changes to the Source Link app.

## Ground the diagram in code

Inspect the relevant implementation before choosing nodes and relationships. Distinguish a conceptual processing flow from a literal call graph. State meaningful omissions, especially error paths, recursion, and alternative modes. Prefer a readable overview plus detail diagrams when one graph becomes crowded.

Use stable, descriptive D2 node IDs. Link code-backed nodes to the declaration or implementation that best explains their label; conceptual headings need no code link. Verify existing files and source locations rather than guessing line numbers. For external repositories, record the inspected revision separately from the URL.

## Portable URLs

Use this shape:

```text
source-link://repo-name/path/relative/to/root.swift?line=42&column=3
```

- Reuse the user's repository alias where known; otherwise use the main repository root folder's name, not a worktree folder's name, and document it. If that name cannot be represented safely as a URL host, resolve the mapping with the user before generating links. Names match case-insensitively.
- Percent-encode individual path segments, preserving `/` separators. Use URL construction utilities, especially for spaces, `#`, `%`, and Unicode.
- Paths must be relative to the configured repository root. Reject empty segments, `.`/`..`, absolute paths, directories, and symlinks escaping the root.
- Line and column are optional positive integers; column requires line. Do not put a branch, commit, symbol, fragment, or extra query key in the URL.
- Repository aliases resolve to each reader's selected checkout. A revision in provenance does not pin that checkout. Xcode supports lines but ignores columns.

Quote URLs in D2:

```d2
direction: down
parse: Parse URL {
  link: "source-link://example/Sources/Parser.swift?line=42"
}
resolve: Resolve file {
  link: "source-link://example/Sources/Resolver.swift?line=18"
}
parse -> resolve
```

The example paths and line numbers are placeholders for real inspected code.

## Render and review

Check available D2 version and engines. Start with a suitable installed engine; ELK often works well for grouped flows. Record the render command or provide a small script with the output. Do not assume engine-specific controls are portable. Consult [D2 layout documentation](https://d2lang.com/tour/layouts/) when changing engine-specific settings.

```sh
d2 --layout elk --pad 30 diagram.d2 diagram.svg
```

Render the SVG and inspect it visually through an available image renderer or browser screenshot. Compilation alone is not visual validation. Check readability at the intended viewing size, label and link-badge clipping, arrow direction, edge crossings, container headings, and excessive whitespace. Adjust labels, grouping, spacing, or engine and render again until the observed problems are resolved. Keep intentional layout edits in the D2 source, not only in the generated SVG.

Inspect the generated SVG anchors as well: verify decoded URLs, file containment, and source declarations, and ensure all intended links survived export. D2 may emit both `href` and `xlink:href` on one anchor; do not count these as two linked nodes. When a Source Link checkout is available, use its parser and resolver for validation where practical.

For interactive viewing, open SVG as a document or use an interactive SVG embedding. Image embeddings such as Markdown images and HTML `<img>` disable links. Test a representative browser-to-editor click when the environment supports it. If rendering, browser access, or external-app handoff is blocked, report which validation remains incomplete; do not equate URL inspection with successful editor navigation.

## Update without discarding layout

Keep a source-anchor record alongside the diagram: stable node ID, repository alias, relative file path, class-qualified symbol or unique declaration text, and last resolved line. Record external revisions separately. Repeated nodes may share an anchor.

For line movement, resolve anchors against the current source and update only their link positions, preserving node IDs, labels, grouping, styles, and edges. Missing or ambiguous declarations require code review; do not silently select the first match. For structural changes, also review whether the diagram's meaning is still accurate. Render and visually review the result again.

An anchor file is metadata, not an automatic refresh system. Do not claim automatic regeneration unless an actual resolver or integration was implemented and exercised. File-only links are appropriate when precise declarations add little value or line stability matters more.

## Deliver

Provide the `.d2`, `.svg`, source-anchor metadata, reproducible render command, and repository mapping instructions. Summarize visual adjustments and validation performed, with any remaining limitations. Keep machine-specific checkout paths out of committed URLs and reusable skill files.
