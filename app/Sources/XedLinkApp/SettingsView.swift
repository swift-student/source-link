import AppKit
import SwiftUI
import XedLinkCore

struct SettingsView: View {
  @ObservedObject var store: SettingsStore

  var body: some View {
    Form {
      Section("Repositories and worktrees") {
        Text("Use the same name for multiple worktrees. Select one default per repository.")
          .font(.caption).foregroundStyle(.secondary)
        ForEach($store.settings.checkouts) { $checkout in
          VStack(alignment: .leading) {
            HStack {
              TextField("Repository name", text: $checkout.name)
              Toggle("Default", isOn: $checkout.isDefault)
              Button("Remove", role: .destructive) {
                store.settings.checkouts.removeAll { $0.id == checkout.id }
              }
            }
            HStack {
              Text(checkout.path.isEmpty ? "Choose a repository root" : checkout.path)
                .font(.caption).lineLimit(2).textSelection(.enabled)
              Spacer()
              Button("Choose Folder…") {
                let panel = NSOpenPanel()
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                panel.allowsMultipleSelection = false
                if panel.runModal() == .OK, let url = panel.url { checkout.path = url.path }
              }
            }
          }
        }
        Button("Add Checkout") { store.settings.checkouts.append(Checkout()) }
      }
      Section("Editors") {
        Picker("Default editor", selection: $store.settings.defaultEditor) {
          ForEach(Editor.allCases) { Text($0.title).tag($0) }
        }
        ForEach(Editor.allCases) { editor in
          TextField(editor.title + " executable", text: Binding(
            get: { store.settings.executablePaths[editor.rawValue] ?? editor.defaultExecutable },
            set: { store.settings.executablePaths[editor.rawValue] = $0 }
          ))
        }
        Text("Install an editor before selecting it. Xcode supports lines; other editors also use columns.")
          .font(.caption).foregroundStyle(.secondary)
      }
      Section("File-type rules (first match wins)") {
        ForEach($store.settings.rules) { $rule in
          HStack {
            TextField("Extension", text: $rule.fileExtension)
            Picker("Editor", selection: $rule.editor) {
              ForEach(Editor.allCases) { Text($0.title).tag($0) }
            }
            Button("Remove", role: .destructive) { store.settings.rules.removeAll { $0.id == rule.id } }
          }
        }
        Button("Add Rule") { store.settings.rules.append(FileRule()) }
      }
    }
    .formStyle(.grouped)
    .frame(minWidth: 640, minHeight: 480)
    .onChange(of: store.settings) { store.save() }
  }
}
