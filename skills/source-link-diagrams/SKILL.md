---
name: source-link-diagrams
description: Create or update D2 diagrams with clickable Source Link URLs into local source code, render SVGs, and visually review their layout. Use for source-linked architecture and code-flow diagrams.
---

# Source-linked D2 diagrams

Deliver editable `.d2` source and a visually reviewed `.svg`. Base nodes and relationships on the relevant code, linking nodes to the implementations that explain them.

## Source links

Use repository aliases and paths relative to the repository root:

```d2
parse: Parse URL {
  link: "source-link://example/Sources/Parser.swift?line=42"
}
```

Reuse the user's alias where known; otherwise use the main repository folder's name and include the mapping in the handoff. Percent-encode path segments as needed. Line and column are optional positive integers (`?line=42&column=3`); column requires line. Use actual source locations in place of the example above.

Aliases open each reader's selected checkout, so record an external repository's inspected revision separately when relevant.

## Render and visually review

Render with D2, for example:

```sh
d2 --layout elk --pad 30 diagram.d2 diagram.svg
```

Inspect the rendered diagram at its intended viewing size. Fix unreadable labels, clipped link badges, confusing arrows, and crowded layout, then render again. Keep layout edits in the D2 source.

Assume Source Link URLs work; verification here is visual. Do not test links, run the Source Link parser or resolver, or exercise browser-to-editor handoff unless requested.

Provide the D2 and SVG files with the render command and repository mapping. For clickable viewing, open the SVG as a document; Markdown images and HTML `<img>` embeddings disable links.

When refreshing source locations, preserve existing labels, grouping, styles, and edges. Source-anchor metadata can help with recurring updates but is optional.
