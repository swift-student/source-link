import AppKit
import SourceLinkCore
import SwiftUI

@MainActor
final class SymbolPicker: NSObject, NSWindowDelegate {
  private var window: NSWindow?
  private var completion: ((SwiftSymbol?) -> Void)?

  func choose(_ symbols: [SwiftSymbol], file: String, completion: @escaping (SwiftSymbol?) -> Void) {
    self.completion = completion
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 580, height: 340),
      styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false
    )
    window.title = "Choose Symbol"
    window.isReleasedWhenClosed = false
    window.minSize = NSSize(width: 440, height: 260)
    window.delegate = self
    window.contentView = NSHostingView(rootView: SymbolPickerView(symbols: symbols, file: file) { [weak self] in
      self?.finish($0)
    })
    self.window = window
    window.center()
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  func windowWillClose(_: Notification) {
    finish(nil)
  }

  private func finish(_ symbol: SwiftSymbol?) {
    guard let completion else { return }
    self.completion = nil
    window?.close()
    window = nil
    completion(symbol)
  }
}

struct SymbolPickerView: View {
  let symbols: [SwiftSymbol]
  let file: String
  let completion: (SwiftSymbol?) -> Void
  @State private var selection: SwiftSymbol.ID?

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Choose a declaration").font(.headline)
      Text(file).font(.subheadline).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
      List(symbols, selection: $selection) { symbol in
        VStack(alignment: .leading, spacing: 4) {
          Text(symbol.signature).font(.system(.body, design: .monospaced))
          Text("Line \(symbol.line)").font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
        .tag(symbol.id)
      }
      .accessibilityLabel("Matching declarations")
      HStack {
        Spacer()
        Button("Cancel") { completion(nil) }.keyboardShortcut(.cancelAction)
        Button("Open") { completion(symbols.first { $0.id == selection }) }
          .keyboardShortcut(.defaultAction)
          .disabled(selection == nil)
      }
    }
    .padding(20)
    .onAppear { selection = symbols.first?.id }
  }
}
