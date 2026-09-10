import AppKit
import SwiftUI
import XedLinkCore

enum SettingsPage: String, CaseIterable, Identifiable {
  case repositories = "Repositories", editors = "Editors", rules = "File Rules"
  var id: String { rawValue }
  var symbol: String {
    switch self {
    case .repositories: "folder"
    case .editors: "chevron.left.forwardslash.chevron.right"
    case .rules: "doc.text"
    }
  }
}

struct SettingsView: View {
  @ObservedObject var store: SettingsStore
  @State private var selection: SettingsPage? = .repositories

  var body: some View {
    NavigationSplitView {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 5) {
          Text("Source Link").font(.title3.weight(.semibold))
          Text("Settings").foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20).padding(.top, 24)
        List(SettingsPage.allCases, selection: $selection) { page in
          Label(page.rawValue, systemImage: page.symbol)
            .padding(.vertical, 7).tag(page)
            .accessibilityIdentifier("settings.page.\(page.id)")
        }
        .listStyle(.sidebar)
      }
      .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
    } detail: {
      Group {
        switch selection ?? .repositories {
        case .repositories: RepositoriesSettingsView(store: store)
        case .editors: EditorsSettingsView(store: store)
        case .rules: ScrollView { FileRulesSettingsView(store: store) }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .background(Color(nsColor: .textBackgroundColor))
    }
    .navigationSplitViewStyle(.balanced)
    .frame(minWidth: 860, minHeight: 540)
    .onChange(of: store.settings) { store.save() }
  }
}

struct SettingsHeading<Actions: View>: View {
  let title: String
  let subtitle: String
  @ViewBuilder var actions: Actions

  var body: some View {
    HStack(alignment: .top, spacing: 16) {
      VStack(alignment: .leading, spacing: 8) {
        Text(title).font(.system(size: 24, weight: .semibold))
          .accessibilityIdentifier("settings.heading.\(title)")
        Text(subtitle).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
      actions
    }
  }
}

struct SettingsCard<Content: View>: View {
  @ViewBuilder var content: Content

  var body: some View {
    VStack(spacing: 0) { content }
      .background(Color(nsColor: .controlBackgroundColor))
      .clipShape(RoundedRectangle(cornerRadius: 9))
      .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(.separator.opacity(0.5)))
  }
}

struct DefaultBadge: View {
  var body: some View {
    Text("Default").font(.caption).foregroundStyle(Color.accentColor)
      .padding(.horizontal, 9).padding(.vertical, 4)
      .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 5))
  }
}

struct SettingsActions<Content: View>: View {
  let label: String
  @ViewBuilder var content: Content

  var body: some View {
    Menu { content } label: { Image(systemName: "ellipsis") }
      .menuStyle(.borderlessButton).menuIndicator(.hidden)
      .fixedSize().frame(width: 28).accessibilityLabel(label)
  }
}

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
