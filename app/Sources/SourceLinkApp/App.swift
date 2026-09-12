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
        guard let command = try store.activeSettings.command(for: link) else { continue }
        Task {
          do { try await Task.detached { try command.run() }.value } catch { SettingsStore.show(error) }
        }
      } catch { SettingsStore.show(error) }
    }
  }

  private func configure(_ link: SourceLink) -> Bool {
    guard store.errorMessage == nil, let base = store.setupSnapshot else { showSettings(); return false }
    var settings = base.document.settings
    guard let root = chooseRoot(for: link) else { return false }
    do { _ = try link.resolve(root: root) } catch { SettingsStore.show(error); return false }
    let alert = NSAlert()
    alert.messageText = "Open with"
    alert.informativeText = "Choose the editor for this file type. You can change it in Settings."
    let picker = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 260, height: 28))
    picker.addItems(withTitles: Editor.allCases.map(\.title))
    let preferred = settings.editor(for: root.appendingPathComponent(link.path))
    picker.selectItem(at: Editor.allCases.firstIndex(of: preferred) ?? 0)
    alert.accessoryView = picker
    alert.addButton(withTitle: "Save and Open")
    alert.addButton(withTitle: "Cancel")
    guard alert.runModal() == .alertFirstButtonReturn else { return false }
    let editor = Editor.allCases[picker.indexOfSelectedItem]
    for index in settings.checkouts.indices where
      settings.checkouts[index].name.caseInsensitiveCompare(link.repository) == .orderedSame {
      settings.checkouts[index].isDefault = false
    }
    if let index = settings.checkouts.firstIndex(where: {
      $0.name.caseInsensitiveCompare(link.repository) == .orderedSame
        && ConfigurationPaths.expand($0.path) == root.path
    }) {
      settings.checkouts[index].isDefault = true
    } else {
      settings.checkouts.append(Checkout(name: link.repository, path: root.path, isDefault: true))
    }
    let fileExtension = root.appendingPathComponent(link.path).pathExtension.lowercased()
    if !fileExtension.isEmpty {
      settings.rules.removeAll { $0.fileExtension.lowercased() == fileExtension }
      var rule = FileRule()
      rule.fileExtension = fileExtension
      rule.editor = editor
      settings.rules.insert(rule, at: 0)
    } else {
      settings.defaultEditor = editor
    }
    return store.saveSetup(settings, base: base)
  }

  private func chooseRoot(for link: SourceLink) -> URL? {
    NSApp.activate(ignoringOtherApps: true)
    let matches = store.activeSettings.checkouts.filter {
      $0.name.caseInsensitiveCompare(link.repository) == .orderedSame
    }
    if !matches.isEmpty {
      let alert = NSAlert()
      alert.messageText = "Choose a worktree for \(link.repository)"
      alert.informativeText = "The selected folder will become the default for future links."
      let picker = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 480, height: 28))
      picker.addItems(withTitles: matches.map(\.path))
      alert.accessoryView = picker
      alert.addButton(withTitle: "Use Worktree")
      alert.addButton(withTitle: "Choose Another Folder…")
      alert.addButton(withTitle: "Cancel")
      switch alert.runModal() {
      case .alertFirstButtonReturn:
        return URL(fileURLWithPath: ConfigurationPaths.expand(matches[picker.indexOfSelectedItem].path))
      case .alertSecondButtonReturn: break
      default: return nil
      }
    }
    let panel = NSOpenPanel()
    panel.title = "Choose checkout for \(link.repository)"
    panel.message = "Select the local directory for “\(link.repository)”."
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    return panel.runModal() == .OK ? panel.url : nil
  }
}
