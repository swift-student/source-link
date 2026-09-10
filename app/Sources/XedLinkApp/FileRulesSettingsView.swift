import SwiftUI
import XedLinkCore

struct FileRulesSettingsView: View {
  @ObservedObject var store: SettingsStore

  var body: some View {
    VStack(alignment: .leading, spacing: SettingsStyle.Spacing.section) {
      SettingsHeading(title: "File Rules", subtitle: "Open specific file types in a different editor.") {
        Button("Add Rule", systemImage: "plus") { store.settings.rules.append(FileRule()) }
      }
      SettingsCard {
        HStack(spacing: SettingsStyle.Spacing.large) {
          Text("Order").frame(width: SettingsStyle.Layout.ruleOrder, alignment: .leading)
          Text("File extension").frame(maxWidth: .infinity, alignment: .leading)
          Text("Open in").frame(width: SettingsStyle.Layout.editorPicker, alignment: .leading)
          Color.clear.frame(width: SettingsStyle.Layout.actionMenu, height: 1)
        }
        .font(.caption).foregroundStyle(.secondary).padding(SettingsStyle.Spacing.large)
        .background(SettingsStyle.tableHeaderBackground)
        Divider()
        if store.settings.rules.isEmpty {
          ContentUnavailableView("No File Rules", systemImage: "doc.text", description:
            Text("All files open in \(store.settings.defaultEditor.title). Add a rule to use another editor."))
            .frame(maxWidth: .infinity, minHeight: SettingsStyle.Layout.emptyRulesHeight)
        } else {
          List {
            ForEach($store.settings.rules) { $rule in
              ruleRow($rule)
                .listRowInsets(EdgeInsets(
                  top: SettingsStyle.Spacing.large, leading: SettingsStyle.Spacing.large,
                  bottom: SettingsStyle.Spacing.large, trailing: SettingsStyle.Spacing.large))
            }
            .onMove { source, destination in
              store.settings.rules.move(fromOffsets: source, toOffset: destination)
            }
          }
          .listStyle(.plain).scrollContentBackground(.hidden)
          .frame(minHeight: SettingsStyle.Layout.rulesMinimumHeight)
        }
      }
      Text("First match wins. Drag rows to change the order, or use Move Up and Move Down in a row’s menu.")
        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
      Divider()
      HStack {
        VStack(alignment: .leading, spacing: SettingsStyle.Spacing.small) {
          Text("All other files").fontWeight(.medium)
          Text("Use the default editor").foregroundStyle(.secondary)
        }
        Spacer()
        Text(store.settings.defaultEditor.title)
      }
      if store.settings.rules.isEmpty { Spacer(minLength: 0) }
    }
    .padding(SettingsStyle.Spacing.page)
  }

  private func ruleRow(_ binding: Binding<FileRule>) -> some View {
    let rule = binding.wrappedValue
    let index = store.settings.rules.firstIndex(where: { $0.id == rule.id }) ?? 0
    return HStack(spacing: SettingsStyle.Spacing.large) {
      HStack(spacing: SettingsStyle.Spacing.small) {
        Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary)
        Text("\(index + 1)").monospacedDigit().foregroundStyle(.secondary)
      }
      .frame(width: SettingsStyle.Layout.ruleOrder, alignment: .leading)
      TextField("Extension", text: binding.fileExtension)
        .textFieldStyle(.roundedBorder).frame(maxWidth: SettingsStyle.Layout.extensionField)
        .accessibilityLabel("File extension for rule \(index + 1)")
      Spacer(minLength: 0)
      Picker("Editor for rule \(index + 1)", selection: binding.editor) {
        ForEach(Editor.allCases) { Text($0.title).tag($0) }
      }
      .labelsHidden().frame(width: SettingsStyle.Layout.editorPicker)
      SettingsActions(label: "Actions for rule \(index + 1)") {
        Button("Move Up") { store.settings.rules.swapAt(index, index - 1) }.disabled(index == 0)
        Button("Move Down") { store.settings.rules.swapAt(index, index + 1) }
          .disabled(index == store.settings.rules.count - 1)
        Divider()
        Button("Remove Rule", role: .destructive) { store.settings.rules.removeAll { $0.id == rule.id } }
      }
    }
  }
}
