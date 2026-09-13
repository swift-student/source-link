import AppKit
import ScreenCaptureKit
import SourceLinkCore
import Testing

@Suite(.serialized)
@MainActor
struct SymbolPickerTests {
  @Test(arguments: ["close", "escape", "open"])
  func `picker supports cancellation and keyboard opening`(action: String) async throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".swift")
    try """
    struct Widget {
      func refresh(force: Bool) {}
      func refresh(force: Int) {}
    }
    extension Widget {
      func refresh() {}
    }
    """.write(to: file, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: file) }
    let matches = try SwiftSymbolResolver.matches(in: file, named: "refresh")
    #expect(matches.count == 3)
    NSApplication.shared.setActivationPolicy(.accessory)
    let picker = SymbolPicker()
    var completions = 0
    picker.choose(matches, file: "Sources/Widget.swift") { symbol in
      #expect(symbol == (action == "open" ? matches.first : nil))
      completions += 1
    }
    let window = try #require(NSApp.windows.first { $0.title == "Choose Symbol" && $0.isVisible })
    defer { window.close() }
    #expect(window.isVisible)
    try await Task.sleep(for: .milliseconds(700))
    if action == "close", let directory = ProcessInfo.processInfo.environment["SOURCE_LINK_SCREENSHOT_DIR"] {
      try await screenshot(window, directory: directory)
    }
    if action == "close" {
      window.performClose(nil)
    } else {
      let key = action == "open" ? "\r" : "\u{1b}"
      let event = try #require(NSEvent.keyEvent(
        with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
        windowNumber: window.windowNumber, context: nil, characters: key,
        charactersIgnoringModifiers: key, isARepeat: false, keyCode: action == "open" ? 36 : 53
      ))
      #expect(window.performKeyEquivalent(with: event))
    }
    #expect(completions == 1)
    #expect(!window.isVisible)
    window.close()
    #expect(completions == 1)
  }

  private func screenshot(_ window: NSWindow, directory: String) async throws {
    let content = try await SCShareableContent.currentProcess
    let capturedWindow = try #require(content.windows.first { $0.windowID == window.windowNumber })
    let filter = SCContentFilter(desktopIndependentWindow: capturedWindow)
    let configuration = SCStreamConfiguration()
    configuration.width = Int(window.frame.width * 2)
    configuration.height = Int(window.frame.height * 2)
    configuration.showsCursor = false
    configuration.ignoreShadowsSingleWindow = true
    let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
    let png = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
    let destination = URL(fileURLWithPath: directory)
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    try png.write(to: destination.appendingPathComponent("symbol-picker.png"))
  }
}
