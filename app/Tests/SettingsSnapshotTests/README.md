# Settings window snapshots

Uses [Point-Free SnapshotTesting](https://github.com/pointfreeco/swift-snapshot-testing)
with Swift Testing. Run from the repository root:

```sh
make snapshot-test
# Intentionally replace the reference images, then inspect every changed PNG:
make record-snapshots
make snapshot-test
```

Recording reports test failures by design. Normal runs must pass without recording.
PNG references are tracked with Git LFS; run `git lfs pull` before testing.
Missing baselines fail rather than being recorded automatically. References live in `__Snapshots__/SettingsSnapshotTests/`.

The standalone test bundle compiles the shared app UI sources (excluding `App.swift`),
so it exercises the same `SettingsWindow` and views without launching the menu-bar
app or accessing the user's settings. Each case uses a unique temporary configuration directory; the suite runs serially.

Snapshots cover both pages with empty and populated settings in light/dark
appearance at 1100×680,
plus empty Editors resized to the minimum 860×540. Geometry assertions also check that the
native close button stays within the title-bar region after resizing. The sidebar,
rounded chrome, toolbar, and control placement are owned by macOS via NavigationSplitView. The captures include the native title
bar and controls, not just SwiftUI content. ScreenCaptureKit's `currentProcess`
API captures only the test process's windows and does not require permission to
record other applications. AppKit bitmap caching is insufficient here: it omits
layer-backed SwiftUI scroll views.

## Environment

Run in an **unlocked graphical macOS session**. ScreenCaptureKit fails with
SCStreamErrorDomain -3811 on the lock screen. The current references were recorded
on macOS 26.6.2 (25G83), Xcode 27 beta, at 2× resolution with the blue system accent.
Native AppKit rendering, activation state, and translucent materials depend on the
OS and desktop environment; use the same environment for comparisons. Review and
re-record deliberately when changing macOS versions or appearance settings.

`make check` continues to run core tests, lint, and the app build without requiring
an unlocked desktop. Window snapshots are a separate `make snapshot-test` gate.

`make ui-test` covers navigation, actions, and autosave persistence. It attaches
screenshots on failure for diagnosis, but keeps no separate visual baselines.
