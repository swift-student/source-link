# Source Link icon

`source-link.png` is the current approved artwork: a forward-leaning S with two dashed pieces on each return, wider cuts between segments, and rounded chain-like bends. The generator crops the surrounding whitespace and converts luminance to transparency, preserving the black mark for template rendering. `source-link.svg` retains the previous three-dash design as a reference; it is no longer used to generate icons.

Regenerate the checked-in app icon and template menu-bar images from the repository root:

```sh
swift scripts/generate-icons.swift
```

The generator uses macOS AppKit and writes `app/Sources/SourceLinkApp/Assets.xcassets`. The app icon uses a neutral light tile for contrast; the menu-bar image is transparent and rendered as a template for light/dark appearances. Both Xcode and `scripts/build-direct.sh` compile the same asset catalog.

## README screenshot

`settings.png` is a documentation copy of the populated light Repositories snapshot.
After reviewing and verifying refreshed baselines, update it from the repository root:

```sh
cp app/Tests/SettingsSnapshotTests/__Snapshots__/SettingsSnapshotTests/settingsWindow.Repositories-light-1100-populated.png docs/assets/settings.png
```

The test baseline remains in Git LFS; the documentation copy renders directly in the README.
