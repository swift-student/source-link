import AppKit
import ScreenCaptureKit
import SourceLinkCore
import Testing

@Suite(.serialized)
@MainActor
struct SymbolPickerTests {
  @Test(arguments: ["close", "escape", "open", "focus"])
  func `picker supports cancellation and keyboard opening`(action: String) async throws {
    let matches = try symbols()
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
    #expect(!window.styleMask.contains(.titled))
    #expect(!window.styleMask.contains(.resizable))
    #expect(window.canBecomeKey)
    #expect(!window.canBecomeMain)
    #expect(window.level == .floating)
    #expect(window.standardWindowButton(.closeButton) == nil)
    try await Task.sleep(for: .milliseconds(700))
    if action == "close", let directory = ProcessInfo.processInfo.environment["SOURCE_LINK_SCREENSHOT_DIR"] {
      for dark in [false, true] {
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        try await Task.sleep(for: .milliseconds(300))
        try await screenshot(window, directory: directory, name: "symbol-picker-\(dark ? "dark" : "light")")
      }
    }
    if action == "close" {
      window.performClose(nil)
    } else if action == "focus" {
      #expect(window.isKeyWindow)
      let other = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
                           styleMask: [.titled], backing: .buffered, defer: false)
      other.isReleasedWhenClosed = false
      other.makeKeyAndOrderFront(nil)
      defer { other.close() }
      #expect(!window.isKeyWindow)
    } else {
      let key = action == "open" ? "\r" : "\u{1b}"
      #expect(try window.performKeyEquivalent(with: event(key, window: window)))
    }
    #expect(completions == 1)
    #expect(!window.isVisible)
    window.close()
    #expect(completions == 1)
  }

  @Test(arguments: [
    ("j", 1), ("jjk", 1), ("kkkk", 0), ("jjjj", 2),
    ("\u{f701}", 1), ("\u{f701}\u{f701}\u{f700}", 1),
    ("\u{f700}\u{f700}", 0), ("\u{f701}\u{f701}\u{f701}", 2),
    ("j\u{f701}k", 1)
  ], [false, true])
  func `navigation opens the selected declaration`(navigation: (String, Int), keyEquivalent: Bool) throws {
    let matches = try symbols()
    let picker = SymbolPicker()
    var chosen: SourceSymbol?
    var completions = 0
    picker.choose(matches, file: "Sources/Widget.swift") {
      chosen = $0
      completions += 1
    }
    let window = try #require(NSApp.windows.first { $0.title == "Choose Symbol" && $0.isVisible })
    defer { window.close() }
    // Exercise both the application's shortcut path and direct window event delivery.
    // No click or layout delay should be needed before the first navigation key.
    for key in navigation.0.map(String.init) + ["\r"] {
      let event = try event(key, window: window)
      if keyEquivalent {
        #expect(window.performKeyEquivalent(with: event))
      } else {
        NSApp.sendEvent(event)
      }
    }
    #expect(chosen == matches[navigation.1])
    #expect(completions == 1)
    #expect(!window.isVisible)
  }

  @Test
  func `modified navigation keys remain available for shortcuts`() throws {
    let matches = try symbols()
    let picker = SymbolPicker()
    var chosen: SourceSymbol?
    picker.choose(matches, file: "Sources/Widget.swift") { chosen = $0 }
    let window = try #require(NSApp.windows.first { $0.title == "Choose Symbol" && $0.isVisible })
    defer { window.close() }
    for modifier in [NSEvent.ModifierFlags.command, .control, .option, .shift] {
      #expect(try !window.performKeyEquivalent(with: event("j", window: window, modifiers: modifier)))
    }
    try window.sendEvent(event("\u{3}", window: window))
    #expect(chosen == matches.first)
  }

  @Test
  func `navigation scrolls through a long list`() async throws {
    let matches = try symbols(count: 12)
    let picker = SymbolPicker()
    var chosen: SourceSymbol?
    picker.choose(matches, file: "Sources/Widget.swift") { chosen = $0 }
    let window = try #require(NSApp.windows.first { $0.title == "Choose Symbol" && $0.isVisible })
    defer { window.close() }
    try await Task.sleep(for: .milliseconds(300))
    for _ in 0 ..< 11 {
      try window.sendEvent(event("j", window: window, isRepeat: true))
      await Task.yield()
    }
    try await Task.sleep(for: .milliseconds(300))
    if let directory = ProcessInfo.processInfo.environment["SOURCE_LINK_SCREENSHOT_DIR"] {
      try await screenshot(window, directory: directory, name: "symbol-picker-scrolled")
    }
    try window.sendEvent(event("\r", window: window))
    #expect(chosen == matches.last)
  }

  @Test(arguments: [
    LanguageFixture(
      file: "Cart.rb",
      source: "class Cart\n  def add(value); end\n  def add(value, force: false); end\nend",
      query: "Cart#add"
    ),
    LanguageFixture(file: "Cart.kt", source: "class Cart {\n  fun add(value: Int) {}\n  fun add(value: String) {}\n}",
                    query: "Cart.add"),
    LanguageFixture(file: "Cart.ts",
                    source: "class Cart {\n  add(value: number): void;\n  add(value: number | string): void {}\n}",
                    query: "Cart.add"),
    LanguageFixture(file: "View.tsx", source: "function View(): unknown;\nfunction View() { return <section />; }",
                    query: "View")
  ])
  func `picker opens declarations from each new language`(fixture: LanguageFixture) async throws {
    let file = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString + "-" + fixture.file)
    try fixture.source.write(to: file, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: file) }
    let matches = try SourceSymbolResolver.matches(in: file, named: fixture.query)
    #expect(matches.count == 2)
    let picker = SymbolPicker()
    var chosen: SourceSymbol?
    picker.choose(matches, file: fixture.file) { chosen = $0 }
    let window = try #require(NSApp.windows.first { $0.title == "Choose Symbol" && $0.isVisible })
    defer { window.close() }
    try window.sendEvent(event("j", window: window))
    if let directory = ProcessInfo.processInfo.environment["SOURCE_LINK_SCREENSHOT_DIR"] {
      window.appearance = NSAppearance(named: .aqua)
      try await Task.sleep(for: .milliseconds(500))
      try await screenshot(window, directory: directory, name: "symbol-picker-\(file.pathExtension)")
    }
    try window.sendEvent(event("\r", window: window))
    #expect(chosen == matches.last)
    #expect(!window.isVisible)
  }

  struct LanguageFixture: Sendable {
    let file: String
    let source: String
    let query: String
  }

  private func symbols(count: Int = 3) throws -> [SourceSymbol] {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".swift")
    let declarations = (0 ..< count).map { "func refresh(value\($0): Int) {}" }.joined(separator: "\n")
    try "struct Widget {\n\(declarations)\n}".write(to: file, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: file) }
    return try SourceSymbolResolver.matches(in: file, named: "refresh")
  }

  private func event(_ key: String, window: NSWindow, modifiers: NSEvent.ModifierFlags = [],
                     isRepeat: Bool = false) throws -> NSEvent {
    let keyCodes: [String: UInt16] = ["j": 38, "k": 40, "\r": 36, "\u{3}": 76, "\u{1b}": 53,
                                      "\u{f700}": 126, "\u{f701}": 125]
    return try #require(NSEvent.keyEvent(
      with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0,
      windowNumber: window.windowNumber, context: nil, characters: key,
      charactersIgnoringModifiers: key, isARepeat: isRepeat, keyCode: keyCodes[key] ?? 0
    ))
  }

  private func screenshot(_ window: NSWindow, directory: String, name: String) async throws {
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
    try png.write(to: destination.appendingPathComponent("\(name).png"))
  }
}
