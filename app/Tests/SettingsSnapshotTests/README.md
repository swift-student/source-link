# Settings window snapshots

Uses [Point-Free SnapshotTesting](https://github.com/pointfreeco/swift-snapshot-testing)
with Swift Testing. Run from the repository root:

```sh
make snapshot-test
# Intentionally replace the reference images, then inspect every changed PNG:
TEST_RUNNER_RECORD_SNAPSHOTS=1 make snapshot-test
make snapshot-test
```

Recording reports test failures by design. Normal runs must pass without recording.
References live in `__Snapshots__/SettingsSnapshotTests/`.

The standalone test bundle compiles the shared app UI sources (excluding `App.swift`),
so it exercises the same `SettingsWindow` and views without launching the menu-bar
app or accessing the user's settings. Its isolated configuration path is
`/tmp/source-link-snapshot-tests/settings.json`; the suite runs serially.

Snapshots cover all three selected pages in light/dark appearance at 1100×680,
and File Rules resized to the minimum 860×540. Geometry assertions also check the
native close button's inset after resizing. The captures include the native title
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
