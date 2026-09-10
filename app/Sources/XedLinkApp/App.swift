import AppKit
import OSLog
import SwiftUI
import XedLinkCore

@main
struct XedLinkApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    MenuBarExtra("xed-link", systemImage: "chevron.left.forwardslash.chevron.right") {
      Text("Source links open in Xcode")
      Divider()
      Button("Quit") { NSApplication.shared.terminate(nil) }
        .keyboardShortcut("q")
    }
  }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
  private let logger = Logger(
    subsystem: "com.shawngee.XedLink",
    category: "URL Handling"
  )
  private var previouslyActiveApplication: NSRunningApplication?

  func applicationWillFinishLaunching(_ notification: Notification) {
    NSApplication.shared.setActivationPolicy(.accessory)
    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(applicationDidDeactivate(_:)),
      name: NSWorkspace.didDeactivateApplicationNotification,
      object: nil
    )
  }

  func application(_ application: NSApplication, open urls: [URL]) {
    var openedURL = false

    for url in urls {
      do {
        try XedURL(url).openInXcode()
        openedURL = true
      } catch {
        logger.error(
          "Could not open \(url.absoluteString, privacy: .public): \(error.localizedDescription)"
        )
      }
    }

    if !openedURL {
      previouslyActiveApplication?.activate()
    }
  }

  @objc private func applicationDidDeactivate(_ notification: Notification) {
    guard
      let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
        as? NSRunningApplication,
      application.processIdentifier != ProcessInfo.processInfo.processIdentifier
    else {
      return
    }

    previouslyActiveApplication = application
  }
}
