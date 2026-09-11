import SwiftUI
import XedLinkCore

struct FileRulesSettingsView: View {
  @ObservedObject var store: SettingsStore
  @Environment(\.colorScheme) private var colorScheme
  @FocusState private var isRuleTableFocused: Bool
  @State private var selection: FileRule.ID?
  @FocusState private var focusedRule: FileRule.ID?

  var body: some View {
    VStack(alignment: .leading, spacing: SettingsStyle.Spacing.section) {
      SettingsHeading(title: "File Rules", subtitle: "Open specific file types in a different editor.") {}
      SettingsCard {
        HStack {
          Text("File extension")
            .padding(.leading, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
          Text("Open in")
            // The macOS picker bezel extends beyond its layout frame.
            .padding(.leading, -SettingsStyle.Spacing.small)
            .frame(width: SettingsStyle.Layout.editorPicker, alignment: .leading)
        }
        .font(.caption).foregroundStyle(.secondary).padding(SettingsStyle.Spacing.large)
        .background(SettingsStyle.tableHeaderBackground)
        Divider()
        if store.settings.rules.isEmpty {
          ContentUnavailableView("No File Rules", systemImage: "doc.text", description:
            Text("All files open in \(store.settings.defaultEditor.title). Click + to add a rule."))
            .frame(maxWidth: .infinity, minHeight: SettingsStyle.Layout.emptyRulesHeight)
        } else {
          // The list provides swipe actions, but selection belongs to this view
          // so macOS does not draw its own highlight over our accent tint.
          List {
            ForEach(store.settings.rules) { rule in
              ruleRow($store.settings.rules[ruleID: rule.id])
                .selectionDisabled()
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(selection == rule.id ? selectionBackground : Color.clear)
                .overlay(alignment: .bottom) { Divider() }
                .swipeActions(edge: .trailing) {
                  Button("Delete", role: .destructive) { removeRule(rule.id) }
                }
            }
          }
          .listStyle(.plain)
          .contentMargins(.horizontal, 0, for: .scrollContent)
          .scrollContentBackground(.hidden)
          .scrollDisabled(true)
          .frame(height: CGFloat(store.settings.rules.count) * 45)
          .focusEffectDisabled()
          .focused($isRuleTableFocused)
          .onDeleteCommand {
            guard focusedRule == nil else { return }
            removeRuleButtonTapped()
          }
        }
        ruleToolbar
      }
      Text("Each file extension can have one rule. Files without a rule use the default editor.")
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
    }
    .padding(SettingsStyle.Spacing.page)
    .onChange(of: focusedRule) { _, id in
      if let id { selection = id }
    }
    .onChange(of: store.settings.rules.map(\.id)) { _, ids in
      if let selection, !ids.contains(selection) { self.selection = nil }
    }
  }

  private var ruleToolbar: some View {
    HStack(spacing: 0) {
      Button(action: addRuleButtonTapped) {
        Image(systemName: "plus").frame(width: 32, height: 28)
      }
      .accessibilityLabel("Add Rule")
      .help("Add a file rule")
      Divider().frame(height: 28)
      Button(action: removeRuleButtonTapped) {
        Image(systemName: "minus").frame(width: 32, height: 28)
      }
      .accessibilityLabel("Remove Rule")
      .help("Remove the selected rule")
      .disabled(selection == nil)
      Divider().frame(height: 28)
      Spacer(minLength: 0)
    }
    .buttonStyle(.borderless)
    .background(SettingsStyle.tableHeaderBackground)
  }

  private func ruleRow(_ binding: Binding<FileRule>) -> some View {
    let rule = binding.wrappedValue
    let index = store.settings.rules.firstIndex(where: { $0.id == rule.id }) ?? 0
    return HStack(spacing: SettingsStyle.Spacing.large) {
      TextField("Extension", text: binding.fileExtension)
        .textFieldStyle(.roundedBorder).frame(maxWidth: SettingsStyle.Layout.extensionField)
        .accessibilityLabel("File extension for rule \(index + 1)")
        .focused($focusedRule, equals: rule.id)
      Spacer(minLength: 0)
      Picker("Editor for rule \(index + 1)", selection: binding.editor) {
        ForEach(Editor.allCases) { Text($0.title).tag($0) }
      }
      .labelsHidden().frame(width: SettingsStyle.Layout.editorPicker, alignment: .leading)
      .simultaneousGesture(TapGesture().onEnded { selection = rule.id })
    }
    .padding(.horizontal, SettingsStyle.Spacing.large)
    .padding(.vertical, SettingsStyle.Spacing.small)
    .frame(height: 45)
    .contentShape(Rectangle())
    .onTapGesture { ruleRowTapped(rule.id) }
    .accessibilityAddTraits(selection == rule.id ? .isSelected : [])
  }

  private var selectionBackground: Color {
    Color.accentColor.opacity(colorScheme == .dark ? 0.25 : 0.1)
  }

  private func ruleRowTapped(_ id: FileRule.ID) {
    focusedRule = nil
    isRuleTableFocused = true
    selection = id
  }

  private func addRuleButtonTapped() {
    let extensions = Set(store.settings.rules.map {
      $0.fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: ". ")).lowercased()
    })
    var rule = FileRule()
    if extensions.contains(rule.fileExtension) {
      rule.fileExtension = "txt"
      var suffix = 2
      while extensions.contains(rule.fileExtension) {
        rule.fileExtension = "extension\(suffix)"
        suffix += 1
      }
    }
    store.settings.rules.append(rule)
    selection = rule.id
    focusedRule = rule.id
  }

  private func removeRuleButtonTapped() {
    guard let selection else { return }
    removeRule(selection)
  }

  private func removeRule(_ id: FileRule.ID) {
    guard let index = store.settings.rules.firstIndex(where: { $0.id == id }) else { return }
    if focusedRule == id { focusedRule = nil }
    if selection == id { selection = nil }
    store.settings.rules.remove(at: index)
  }
}

private extension Array where Element == FileRule {
  // Text fields can finish editing after their row is removed. Resolve by identity
  // rather than retaining an array-index binding that can become invalid.
  subscript(ruleID id: FileRule.ID) -> FileRule {
    get { first { $0.id == id } ?? FileRule() }
    set {
      guard let index = firstIndex(where: { $0.id == id }) else { return }
      self[index] = newValue
    }
  }
}
