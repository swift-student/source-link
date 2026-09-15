import AppKit
import SourceLinkCore
import SwiftUI

@main
struct SourceLinkApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    MenuBarExtra {
      Button("Settings…") { appDelegate.showSettings() }.keyboardShortcut(",")
      Divider()
      Button("Quit") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
    } label: {
      Image("SourceLinkMenu")
        .renderingMode(.template)
        .accessibilityLabel("Source Link")
    }
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let store = SettingsStore()
  private var settingsWindow: NSWindow?
  private var symbolPickers: [UUID: SymbolPicker] = [:]

  func applicationWillFinishLaunching(_: Notification) {
    NSApplication.shared.setActivationPolicy(.accessory)
  }

  func applicationDidFinishLaunching(_: Notification) {
    if store.activeSettings.checkouts.isEmpty || store.errorMessage != nil
      || CommandLine.arguments.contains("--settings") {
      showSettings()
    }
  }

  func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
    showSettings()
    return true
  }

  func showSettings() {
    if settingsWindow == nil {
      let window = SettingsWindow(store: store)
      window.center()
      settingsWindow = window
    }
    settingsWindow?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  func application(_: NSApplication, open urls: [URL]) {
    store.reload()
    for url in urls {
      do {
        let link = try SourceLink(url)
        if store.activeSettings.checkout(for: link.repository) == nil {
          guard configure(link) else { continue }
        }
        let settings = store.activeSettings
        Task {
          do {
            if let query = link.symbol,
               let checkout = settings.checkout(for: link.repository) {
              let file = try link.resolve(root: URL(fileURLWithPath: ConfigurationPaths.expand(checkout.path)))
              let matches = try await Task.detached {
                try SourceSymbolResolver.matches(in: file, named: query)
              }.value
              guard let first = matches.first else { throw SourceLinkError.missingSymbol }
              if matches.count == 1 {
                open(link, settings: settings, symbol: first)
              } else {
                let id = UUID()
                let picker = SymbolPicker()
                symbolPickers[id] = picker
                picker.choose(matches, file: link.path) { [weak self = self] symbol in
                  self?.symbolPickers[id] = nil
                  if let symbol {
                    self?.open(link, settings: settings, symbol: symbol)
                  }
                }
              }
            } else {
              open(link, settings: settings)
            }
          } catch { SettingsStore.show(error) }
        }
      } catch { SettingsStore.show(error) }
    }
  }

  private func open(_ link: SourceLink, settings: SourceSettings, symbol: SourceSymbol? = nil) {
    do {
      guard let command = try settings.command(for: link, symbol: symbol) else { return }
      Task {
        do { try await Task.detached { try command.run() }.value } catch { SettingsStore.show(error) }
      }
    } catch { SettingsStore.show(error) }
  }

  private func configure(_ link: SourceLink) -> Bool {
    guard store.errorMessage == nil, store.setupSnapshot != nil else {
      showSettings()
      return false
    }
    return FirstLinkSetupPresenter(store: store).configure(link)
  }
}
