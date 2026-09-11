# Source Link icon

`source-link.svg` is the approved three-dash, forward-leaning black mark. It keeps the complete links underneath an SVG mask, with three progressively shorter segments per arc.

Regenerate the checked-in app icon and template menu-bar images from the repository root:

```sh
swift scripts/generate-icons.swift
```

The generator uses macOS AppKit and writes `app/Sources/XedLinkApp/Assets.xcassets`. The app icon uses a neutral light tile for contrast; the menu-bar image is transparent and rendered as a template for light/dark appearances. Both Xcode and `scripts/build-direct.sh` compile the same asset catalog.
