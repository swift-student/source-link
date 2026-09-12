#if DEBUG
  import SourceLinkCore
  import SwiftUI

  /// Owns an isolated store for the lifetime of each interactive canvas preview.
  private struct SettingsPreview: View {
    @StateObject private var store: SettingsStore
    let page: SettingsPage

    init(page: SettingsPage, populated: Bool = true) {
      self.page = page
      var settings = SourceSettings()
      if populated {
        settings.checkouts = [
          Checkout(name: "source-link", path: "/workspace/source-link"),
          Checkout(name: "source-link", path: "/worktrees/settings", isDefault: true),
          Checkout(name: "website", path: "/workspace/website", isDefault: true)
        ]
        settings.executablePaths[Editor.xcode.rawValue] = "/usr/local/bin/custom-xed"
        settings.rules = [("swift", Editor.xcode), ("md", Editor.vscode)].map { fileExtension, editor in
          var rule = FileRule()
          rule.fileExtension = fileExtension
          rule.editor = editor
          return rule
        }
      }
      _store = StateObject(wrappedValue: SettingsStore(previewSettings: settings))
    }

    var body: some View {
      SettingsView(store: store, selection: page)
        .frame(width: SettingsStyle.Layout.window.width, height: SettingsStyle.Layout.window.height)
    }
  }

  #Preview("Repositories — Populated") {
    SettingsPreview(page: .repositories)
  }

  #Preview("Repositories — Empty") {
    SettingsPreview(page: .repositories, populated: false)
  }

  #Preview("Editors — Custom Executable") {
    SettingsPreview(page: .editors)
  }

  #Preview("Editors — Defaults") {
    SettingsPreview(page: .editors, populated: false)
  }

  #Preview("File Rules — Populated") {
    SettingsPreview(page: .rules)
  }

  #Preview("File Rules — Empty") {
    SettingsPreview(page: .rules, populated: false)
  }

  #Preview("Settings — Dark") {
    SettingsPreview(page: .rules)
      .preferredColorScheme(.dark)
  }
#endif
