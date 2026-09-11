import AppKit
import ScreenCaptureKit
import SnapshotTesting
import Testing
import XedLinkCore

@Suite(.serialized)
@MainActor
struct SettingsSnapshotTests {
  @Test(arguments: SettingsPage.allCases, [false, true])
  func settingsWindow(page: SettingsPage, dark: Bool) async throws {
    try await snapshot(page: page, dark: dark, size: SettingsStyle.Layout.window)
  }

  @Test(arguments: [false, true])
  func minimumWindow(dark: Bool) async throws {
    try await snapshot(page: .rules, dark: dark, size: SettingsStyle.Layout.minimumWindow)
  }

  private func snapshot(page: SettingsPage, dark: Bool, size: CGSize) async throws {
    // Never read or write the user's real configuration, or launch the menu-bar app.
    let directory = URL(fileURLWithPath: "/tmp/source-link-snapshot-tests", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = SettingsStore(repository: ConfigurationRepository(
      file: directory.appendingPathComponent("settings.json")))
    NSApplication.shared.setActivationPolicy(.regular)
    NSApplication.shared.activate(ignoringOtherApps: true)
    let window = SettingsWindow(store: store, page: page)
    window.setContentSize(size)
    window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    window.setFrameOrigin(NSPoint(x: 100, y: 100))
    window.makeKeyAndOrderFront(nil)
    defer { window.close() }
    // Allow SwiftUI layout and AppKit's title-bar controls to settle.
    try await Task.sleep(for: .milliseconds(300))
    let frameView = try #require(window.contentView?.superview)
    frameView.layoutSubtreeIfNeeded()
    window.displayIfNeeded()
    let close = try #require(window.standardWindowButton(.closeButton))
    let controlFrame = close.convert(close.bounds, to: nil)
    // Native chrome owns the insets; controls must remain inside the window after resizing.
    #expect(controlFrame.minX > 0)
    #expect(controlFrame.maxY < window.frame.height)
    #expect(controlFrame.minY > window.frame.height - 60)
    // Capture the composited window: cacheDisplay omits layer-backed SwiftUI scroll views.
    // currentProcess limits capture to our own windows without Screen Recording permission.
    let content = try await SCShareableContent.currentProcess
    let capturedWindow = try #require(content.windows.first { $0.windowID == window.windowNumber })
    let filter = SCContentFilter(desktopIndependentWindow: capturedWindow)
    let configuration = SCStreamConfiguration()
    configuration.width = Int(size.width * 2)
    configuration.height = Int(size.height * 2)
    configuration.showsCursor = false
    configuration.ignoreShadowsSingleWindow = true
    let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
    let image = NSImage(cgImage: cgImage, size: size)
    let name = "\(page.id)-\(dark ? "dark" : "light")-\(Int(size.width))"
    withSnapshotTesting(record: ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1" ? .all : .missing) {
      assertSnapshot(of: image, as: .image, named: name, testName: "settingsWindow")
    }
  }
}
