import AppKit
import SourceLinkCore
import SwiftUI

struct EditorsSettingsView: View {
  @ObservedObject var store: SettingsStore
  @State private var expanded: Set<Editor> = []

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: SettingsStyle.Spacing.section) {
        SettingsHeading(title: "Editors", subtitle: "Set a default, then configure only the editors you use.") {}
        SettingsCard {
          ForEach(store.settings.availableEditors) { editor in
            if editor != store.settings.availableEditors.first {
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
                Text(store.settings.title(for: editor)).fontWeight(.medium)
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
          get: { profilePath(editor) },
          set: { store.settings.editors[editor.rawValue]?.executable = $0 }
        ))
        .textFieldStyle(.roundedBorder).accessibilityLabel("\(editor.title) executable path")
        Button("Choose…") { chooseExecutable(editor) }
      }
      Text("Command arguments are configured in config.json. Install the editor before using it.")
        .font(.callout).foregroundStyle(.secondary)
      if let profile = store.settings.editors[editor.rawValue] {
        Text(profile.arguments.joined(separator: " "))
          .font(.system(.caption, design: .monospaced)).textSelection(.enabled)
      }
      if let bundled = EditorProfile.defaults[editor.rawValue], profilePath(editor) != bundled.executable {
        Button("Use Default Path") { store.settings.editors[editor.rawValue]?.executable = bundled.executable }
          .buttonStyle(SettingsLinkButtonStyle())
      }
    }
    .padding(.leading, SettingsStyle.Layout.editorConfigurationInset).padding(.bottom, SettingsStyle.Spacing.extraLarge)
  }

  private func profilePath(_ editor: Editor) -> String {
    store.settings.editors[editor.rawValue]?.executable ?? ""
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
      ConfigurationPaths.expand(profilePath(editor)))
      .deletingLastPathComponent()
    if panel.runModal() == .OK, let url = panel.url {
      guard FileManager.default.isExecutableFile(atPath: url.path) else {
        SettingsStore.show(SourceLinkError.invalidEditor)
        return
      }
      store.settings.editors[editor.rawValue]?.executable = url.path
    }
  }
}

#if DEBUG
  #Preview("Editors — Custom Executable") {
    SettingsPreview { store in
      EditorsSettingsView(store: store)
        .settingsPagePreviewLayout()
    }
  }

  #Preview("Editors — Defaults") {
    SettingsPreview(populated: false) { store in
      EditorsSettingsView(store: store)
        .settingsPagePreviewLayout()
    }
  }
#endif
