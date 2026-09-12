#if DEBUG
  import SourceLinkCore
  import SwiftUI

  /// Owns an isolated store for the lifetime of each interactive canvas preview.
  struct SettingsPreview<Content: View>: View {
    @StateObject private var store: SettingsStore
    private let content: (SettingsStore) -> Content

    init(populated: Bool = true, @ViewBuilder content: @escaping (SettingsStore) -> Content) {
      self.content = content
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
      content(store)
    }
  }

  extension View {
    /// Match the detail area of the standard settings window.
    func settingsPagePreviewLayout() -> some View {
      frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SettingsStyle.pageBackground)
        .frame(width: SettingsStyle.Layout.window.width - SettingsStyle.Layout.sidebarIdeal,
               height: SettingsStyle.Layout.window.height)
    }
  }
#endif
