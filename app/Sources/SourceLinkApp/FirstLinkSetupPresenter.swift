import AppKit
import SourceLinkCore

@MainActor
struct FirstLinkSetupPresenter {
  let store: SettingsStore

  func configure(_ link: SourceLink) -> Bool {
    guard store.errorMessage == nil, let base = store.setupSnapshot else { return false }
    var settings = base.document.settings
    guard let root = chooseRoot(for: link) else { return false }
    do { _ = try link.resolve(root: root) } catch { SettingsStore.show(error); return false }
    let alert = NSAlert()
    alert.messageText = "Open with"
    alert.informativeText = "Choose the editor for this file type. You can change it in Settings."
    let picker = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 260, height: 28))
    picker.addItems(withTitles: settings.availableEditors.map { settings.title(for: $0) })
    let preferred = settings.editor(for: root.appendingPathComponent(link.path))
    picker.selectItem(at: settings.availableEditors.firstIndex(of: preferred) ?? 0)
    alert.accessoryView = picker
    alert.addButton(withTitle: "Save and Open")
    alert.addButton(withTitle: "Cancel")
    guard alert.runModal() == .alertFirstButtonReturn else { return false }
    let editor = settings.availableEditors[picker.indexOfSelectedItem]
    settings.configure(link, root: root, editor: editor)
    return store.saveSetup(settings, base: base)
  }

  private func chooseRoot(for link: SourceLink) -> URL? {
    NSApp.activate(ignoringOtherApps: true)
    let matches = store.activeSettings.checkouts(for: link.repository)
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
    return SettingsPanels.chooseFolder(
      title: "Choose checkout for \(link.repository)",
      message: "Select the local directory for “\(link.repository)”."
    )
  }
}
