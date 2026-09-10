import AppKit

@MainActor
enum SettingsPanels {
  static func chooseFolder(title: String, message: String) -> URL? {
    let panel = NSOpenPanel()
    panel.title = title
    panel.message = message
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    return panel.runModal() == .OK ? panel.url : nil
  }
}
