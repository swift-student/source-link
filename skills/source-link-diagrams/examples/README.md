# Ownership-card style example

- [Editable D2](ownership-cards.d2)
- [Rendered SVG](ownership-cards.svg) — open directly as a browser document for clickable links
- [Style guide](../STYLE.md)

This small structural view uses real types from Source Link's local working tree
based on revision `92a1d74`. The inspected tree had uncommitted changes; line anchors
reflect that working tree, not necessarily the clean commit. It shows stored values,
not request execution or filesystem ownership. Map the Source Link repository name
**source-link** to your local checkout of this repository.

From the repository root, render with:

```sh
d2 --layout elk --pad 30 \
  skills/source-link-diagrams/examples/ownership-cards.d2 \
  skills/source-link-diagrams/examples/ownership-cards.svg
```

The SVG was rendered and visually reviewed. Source Link handoff was not exercised.
Copy the entire `source-link-diagrams` directory when installing the skill so its
style guide and example remain available. Refresh actual source locations when
reusing this example; do not copy these anchors into unrelated diagrams.
