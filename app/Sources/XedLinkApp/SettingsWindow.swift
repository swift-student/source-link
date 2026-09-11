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
    isReleasedWhenClosed = false
    let hostingView = NSHostingView(rootView: SettingsView(store: store, selection: page))
    // The settings layout reserves its own space for the native window controls.
    hostingView.safeAreaRegions = []
    contentView = hostingView
    positionWindowControls()
  }

  override func setFrame(_ frameRect: NSRect, display flag: Bool) {
    super.setFrame(frameRect, display: flag)
    positionWindowControls()
  }

  override func displayIfNeeded() {
    // AppKit can relayout the title bar after appearance changes or first presentation.
    // Reapply the shared geometry after that layout, before the window is composited.
    super.displayIfNeeded()
    positionWindowControls()
  }

  private func positionWindowControls() {
    guard let close = standardWindowButton(.closeButton),
          let minimize = standardWindowButton(.miniaturizeButton),
          let zoom = standardWindowButton(.zoomButton),
          let titlebar = close.superview,
          let container = titlebar.superview else { return }
    let height: CGFloat = 52
    var containerFrame = container.frame
    // Keep the native window outline full-width; only the title-bar view is
    // narrowed to the sidebar so it cannot cover page actions.
    containerFrame.size.width = frame.width
    containerFrame.size.height = height
    containerFrame.origin.y = frame.height - height
    container.frame = containerFrame
    titlebar.frame = NSRect(x: 0, y: 0,
                           width: SettingsStyle.Layout.sidebarIdeal + 2 * SettingsStyle.Spacing.small,
                           height: height)
    let spacing = minimize.frame.minX - close.frame.minX
    // Share the inset and radius with the pane so the close button is concentric
    // with its top-left corner, rather than offset farther into the sidebar.
    let center = SettingsStyle.Layout.windowControlsCenter
    for (index, button) in [close, minimize, zoom].enumerated() {
      button.setFrameOrigin(NSPoint(x: center - button.frame.width / 2 + CGFloat(index) * spacing,
                                    y: titlebar.bounds.height - center - button.frame.height / 2))
    }
  }
}
