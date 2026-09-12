import AppKit
import SwiftUI
import XedLinkCore

struct EditorsSettingsView: View {
  @ObservedObject var store: SettingsStore
  @State private var expanded: Set<Editor> = []

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: SettingsStyle.Spacing.section) {
        SettingsHeading(title: "Editors", subtitle: "Set a default, then configure only the editors you use.") {}
        SettingsCard {
          ForEach(Editor.allCases) { editor in
            if editor != Editor.allCases.first {
              Divider()
            }
            DisclosureGroup(isExpanded: Binding(
              get: { expanded.contains(editor) },
              set: {
                if $0 {
                  expanded.insert(editor)
                } else {
                  expanded.remove(editor)
                }
              }
            )) {
              editorConfiguration(editor)
            } label: {
              HStack {
                Text(editor.title).fontWeight(.medium)
                Spacer()
                if editor == store.settings.defaultEditor {
                  Text("Default editor").foregroundStyle(SettingsStyle.actionForeground)
                } else {
                  Button("Make Default") { store.settings.defaultEditor = editor }
                    .buttonStyle(SettingsLinkButtonStyle())
                    .accessibilityIdentifier("editors.makeDefault.\(editor.rawValue)")
                }
              }
              .padding(.vertical, SettingsStyle.Spacing.large)
            }
            .disclosureGroupStyle(SettingsDisclosureGroupStyle(title: editor.title))
            .padding(.horizontal, SettingsStyle.Spacing.large)
          }
        }
      }
      .padding(SettingsStyle.Spacing.page)
    }
    .onAppear { expanded.insert(store.settings.defaultEditor) }
  }

  private func editorConfiguration(_ editor: Editor) -> some View {
    VStack(alignment: .leading, spacing: SettingsStyle.Spacing.medium) {
      Text("Executable").fontWeight(.medium)
      HStack(spacing: SettingsStyle.Spacing.medium) {
        TextField("Executable path", text: Binding(
          get: { store.settings.executablePaths[editor.rawValue] ?? editor.defaultExecutable },
          set: { store.settings.executablePaths[editor.rawValue] = $0 }
        ))
        .textFieldStyle(.roundedBorder).accessibilityLabel("\(editor.title) executable path")
        Button("Choose…") { chooseExecutable(editor) }
      }
      Text(editor == .xcode
        ? "Opens files at the requested line. Column positions aren’t supported."
        : "Opens files at the requested line and column. Install the editor before using it.")
        .font(.callout).foregroundStyle(.secondary)
      if let path = store.settings.executablePaths[editor.rawValue], path != editor.defaultExecutable {
        Button("Use Default Path") { store.settings.executablePaths.removeValue(forKey: editor.rawValue) }
          .buttonStyle(SettingsLinkButtonStyle())
      }
    }
    .padding(.leading, 36).padding(.bottom, SettingsStyle.Spacing.extraLarge)
  }

  private func chooseExecutable(_ editor: Editor) {
    let panel = NSOpenPanel()
    panel.title = "Choose \(editor.title) Executable"
    panel.message = "Select the editor’s command-line executable."
    panel.canChooseDirectories = false
    panel.canChooseFiles = true
    panel.allowsMultipleSelection = false
    panel.treatsFilePackagesAsDirectories = true
    panel.directoryURL = URL(fileURLWithPath:
      ConfigurationPaths.expand(store.settings.executablePaths[editor.rawValue] ?? editor.defaultExecutable))
      .deletingLastPathComponent()
    if panel.runModal() == .OK, let url = panel.url {
      guard FileManager.default.isExecutableFile(atPath: url.path) else {
        SettingsStore.show(SourceLinkError.invalidEditor)
        return
      }
      store.settings.executablePaths[editor.rawValue] = url.path
    }
  }
}
