import AppKit
import SwiftUI
import XedLinkCore

@main
struct SourceLinkApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    MenuBarExtra("Source Link", systemImage: "chevron.left.forwardslash.chevron.right") {
      Button("Settings…") { appDelegate.showSettings() }
      Divider()
      Button("Quit") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
    }
  }
}

@MainActor
final class SettingsStore: ObservableObject {
  @Published var settings = SourceSettings()
  private let storage: URL

  init() {
    storage = URL.applicationSupportDirectory.appendingPathComponent("SourceLink/settings.json")
    do {
      if FileManager.default.fileExists(atPath: storage.path) {
        settings = try JSONDecoder().decode(SourceSettings.self, from: Data(contentsOf: storage))
      }
    } catch { Self.show(error) }
  }

  func save() {
    do {
      try FileManager.default.createDirectory(at: storage.deletingLastPathComponent(),
                                             withIntermediateDirectories: true)
      try JSONEncoder().encode(settings).write(to: storage, options: .atomic)
    } catch { Self.show(error) }
  }

  static func show(_ error: Error) {
    let alert = NSAlert(error: error)
    NSApp.activate(ignoringOtherApps: true)
    alert.runModal()
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let store = SettingsStore()
  private var settingsWindow: NSWindow?

  func applicationWillFinishLaunching(_ notification: Notification) {
    NSApplication.shared.setActivationPolicy(.accessory)
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    if store.settings.checkouts.isEmpty { showSettings() }
  }

  func showSettings() {
    if settingsWindow == nil {
      let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 740, height: 580),
                            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
      window.title = "Source Link Settings"
      window.isReleasedWhenClosed = false
      window.contentView = NSHostingView(rootView: SettingsView(store: store))
      window.center()
      settingsWindow = window
    }
    settingsWindow?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls {
      do {
        if url.scheme?.lowercased() == "xed" {
          try XedURL(url).openInXcode()
          continue
        }
        let link = try SourceLink(url)
        if store.settings.checkout(for: link.repository) == nil {
          guard configure(link) else { continue }
        }
        guard let command = try store.settings.command(for: link) else { continue }
        Task {
          do { try await Task.detached { try command.run() }.value } catch { SettingsStore.show(error) }
        }
      } catch { SettingsStore.show(error) }
    }
  }

  private func configure(_ link: SourceLink) -> Bool {
    guard let root = chooseRoot(for: link) else { return false }
    do { _ = try link.resolve(root: root) } catch { SettingsStore.show(error); return false }
    let alert = NSAlert()
    alert.messageText = "Open with"
    alert.informativeText = "Choose the editor for this file type. You can change it in Settings."
    let picker = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 260, height: 28))
    picker.addItems(withTitles: Editor.allCases.map(\.title))
    let preferred = store.settings.editor(for: root.appendingPathComponent(link.path))
    picker.selectItem(at: Editor.allCases.firstIndex(of: preferred) ?? 0)
    alert.accessoryView = picker
    alert.addButton(withTitle: "Save and Open")
    alert.addButton(withTitle: "Cancel")
    guard alert.runModal() == .alertFirstButtonReturn else { return false }
    let editor = Editor.allCases[picker.indexOfSelectedItem]
    for index in store.settings.checkouts.indices where
      store.settings.checkouts[index].name.caseInsensitiveCompare(link.repository) == .orderedSame {
      store.settings.checkouts[index].isDefault = false
    }
    if let index = store.settings.checkouts.firstIndex(where: {
      $0.name.caseInsensitiveCompare(link.repository) == .orderedSame && $0.path == root.path
    }) {
      store.settings.checkouts[index].isDefault = true
    } else {
      store.settings.checkouts.append(Checkout(name: link.repository, path: root.path, isDefault: true))
    }
    let fileExtension = root.appendingPathComponent(link.path).pathExtension.lowercased()
    if !fileExtension.isEmpty {
      store.settings.rules.removeAll { $0.fileExtension.lowercased() == fileExtension }
      var rule = FileRule()
      rule.fileExtension = fileExtension
      rule.editor = editor
      store.settings.rules.insert(rule, at: 0)
    } else { store.settings.defaultEditor = editor }
    store.save()
    return true
  }

  private func chooseRoot(for link: SourceLink) -> URL? {
    NSApp.activate(ignoringOtherApps: true)
    let matches = store.settings.checkouts.filter {
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
        return URL(fileURLWithPath: matches[picker.indexOfSelectedItem].path)
      case .alertSecondButtonReturn: break
      default: return nil
      }
    }
    let panel = NSOpenPanel()
    panel.title = "Choose checkout for \(link.repository)"
    panel.message = "Select the repository root containing \(link.path)."
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    return panel.runModal() == .OK ? panel.url : nil
  }

}
