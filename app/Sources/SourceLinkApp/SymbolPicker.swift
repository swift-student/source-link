import AppKit
import SourceLinkCore
import SwiftUI

@MainActor
final class SymbolPicker: NSObject, NSWindowDelegate {
  private var window: NSWindow?
  private var completion: ((SwiftSymbol?) -> Void)?

  func choose(_ symbols: [SwiftSymbol], file: String, completion: @escaping (SwiftSymbol?) -> Void) {
    self.completion = completion
    let window = SymbolPickerPanel(symbols: symbols, file: file) { [weak self] in
      self?.finish($0)
    }
    window.delegate = self
    self.window = window
    window.center()
    window.makeKeyAndOrderFront(nil)
  }

  func windowWillClose(_: Notification) {
    finish(nil)
  }

  func windowDidResignKey(_: Notification) {
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

@MainActor
final class SymbolPickerSelection: ObservableObject {
  let symbols: [SwiftSymbol]
  @Published var id: SwiftSymbol.ID?

  init(symbols: [SwiftSymbol]) {
    self.symbols = symbols
    id = symbols.first?.id
  }

  var symbol: SwiftSymbol? {
    symbols.first { $0.id == id }
  }

  func move(by distance: Int) {
    guard !symbols.isEmpty else { return }
    let index = symbols.firstIndex { $0.id == id } ?? 0
    id = symbols[min(max(index + distance, 0), symbols.count - 1)].id
  }
}

@MainActor
final class SymbolPickerPanel: NSPanel {
  private let selection: SymbolPickerSelection
  private let completion: (SwiftSymbol?) -> Void

  override var canBecomeKey: Bool {
    true
  }

  override var canBecomeMain: Bool {
    false
  }

  init(symbols: [SwiftSymbol], file: String, completion: @escaping (SwiftSymbol?) -> Void) {
    selection = SymbolPickerSelection(symbols: symbols)
    self.completion = completion
    super.init(
      contentRect: NSRect(x: 0, y: 0, width: 640, height: 136 + CGFloat(min(max(symbols.count, 1), 6)) * 52),
      styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false
    )
    title = "Choose Symbol"
    isReleasedWhenClosed = false
    isOpaque = false
    backgroundColor = .clear
    hasShadow = true
    level = .floating
    isMovableByWindowBackground = true
    contentView = NSHostingView(rootView: SymbolPickerView(selection: selection, file: file, completion: completion))
  }

  /// Handle navigation at the panel so it works immediately, regardless of list or button focus.
  override func sendEvent(_ event: NSEvent) {
    if !handleKey(event) {
      super.sendEvent(event)
    }
  }

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    handleKey(event) || super.performKeyEquivalent(with: event)
  }

  override func performClose(_: Any?) {
    close()
  }

  private func handleKey(_ event: NSEvent) -> Bool {
    guard event.type == .keyDown,
          event.modifierFlags.isDisjoint(with: [.command, .control, .option, .shift]) else { return false }
    switch event.charactersIgnoringModifiers {
    case "j", "\u{f701}": selection.move(by: 1)
    case "k", "\u{f700}": selection.move(by: -1)
    case "\r", "\u{3}":
      if let symbol = selection.symbol {
        completion(symbol)
      }
    case "\u{1b}": completion(nil)
    default: return false
    }
    return true
  }
}

struct SymbolPickerView: View {
  @ObservedObject var selection: SymbolPickerSelection
  let file: String
  let completion: (SwiftSymbol?) -> Void
  @FocusState private var listFocused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Choose a declaration").font(.headline)
          Text(file).font(.subheadline).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
        }
        Spacer(minLength: 0)
        Text("\(selection.symbols.count) matches").font(.caption).foregroundStyle(.secondary)
      }
      .padding(20)
      Divider()
      ScrollViewReader { proxy in
        List(selection.symbols, selection: $selection.id) { symbol in
          VStack(alignment: .leading, spacing: 4) {
            Text(symbol.signature).font(.system(.body, design: .monospaced)).lineLimit(1)
            Text("Line \(symbol.line)").font(.caption).foregroundStyle(.secondary)
          }
          .padding(.vertical, 5)
          .help(symbol.signature)
          .tag(symbol.id)
          .id(symbol.id)
          .listRowSeparator(.hidden)
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .accessibilityLabel("Matching declarations")
        .focused($listFocused)
        .onChange(of: selection.id) { _, id in
          if let id {
            proxy.scrollTo(id)
          }
        }
      }
      Divider()
      HStack(spacing: 18) {
        shortcut("↑ k  ↓ j", label: "Navigate")
        Spacer()
        Button { completion(nil) } label: { shortcut("esc", label: "Close") }
          .accessibilityLabel("Close")
        Button { completion(selection.symbol) } label: { shortcut("↵", label: "Open") }
          .accessibilityLabel("Open")
          .disabled(selection.symbol == nil)
      }
      .buttonStyle(.plain)
      .padding(.horizontal, 20)
      .padding(.vertical, 12)
    }
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .overlay {
      RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.12), lineWidth: 1)
    }
    .onAppear { listFocused = true }
  }

  private func shortcut(_ keys: String, label: String) -> some View {
    HStack(spacing: 6) {
      Text(keys)
        .font(.system(.caption, design: .monospaced))
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
      Text(label).font(.caption)
    }
    .foregroundStyle(.secondary)
  }
}
