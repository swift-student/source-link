import AppKit
import SwiftUI

@MainActor
final class SettingsWindow: NSWindow {
  init(store: SettingsStore, page: SettingsPage = .repositories,
       size: CGSize = SettingsStyle.Layout.window) {
    super.init(contentRect: NSRect(origin: .zero, size: size),
               styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
               backing: .buffered, defer: false)
    title = "Source Link Settings"
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    // Keep unified chrome even when the split view has no toolbar buttons.
    toolbar = NSToolbar(identifier: "SettingsToolbar")
    toolbarStyle = .unified
    isReleasedWhenClosed = false
    contentView = NSHostingView(rootView: SettingsView(store: store, selection: page))
  }
}
