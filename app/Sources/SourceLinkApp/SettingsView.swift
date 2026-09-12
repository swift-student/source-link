import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
  case repositories = "Repositories", editors = "Editors", rules = "File Rules"
  var id: String {
    rawValue
  }

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
  @State var selection: SettingsPage? = .repositories

  var body: some View {
    NavigationSplitView {
      List(SettingsPage.allCases, selection: $selection) { page in
        Label(page.rawValue, systemImage: page.symbol)
          .tag(page)
          .accessibilityIdentifier("settings.page.\(page.id)")
      }
      .listStyle(.sidebar)
      .toolbar(removing: .sidebarToggle)
      .navigationSplitViewColumnWidth(min: SettingsStyle.Layout.sidebarMinimum,
                                      ideal: SettingsStyle.Layout.sidebarIdeal,
                                      max: SettingsStyle.Layout.sidebarMaximum)
    } detail: {
      Group {
        switch selection ?? .repositories {
        case .repositories: RepositoriesSettingsView(store: store)
        case .editors: EditorsSettingsView(store: store)
        case .rules: ScrollView { FileRulesSettingsView(store: store) }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .background(SettingsStyle.pageBackground)
      .safeAreaInset(edge: .top, spacing: 0) {
        if let message = store.errorMessage ?? store.saveError {
          Text(message)
            .font(.callout)
            .foregroundStyle(.red)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(SettingsStyle.Spacing.extraLarge)
            .accessibilityIdentifier("settings.configuration.error")
        }
      }
    }
    .frame(minWidth: SettingsStyle.Layout.minimumWindow.width,
           minHeight: SettingsStyle.Layout.minimumWindow.height)
  }
}

#if DEBUG
  #Preview("Settings — Light") {
    SettingsPreview { store in
      SettingsView(store: store)
        .frame(width: SettingsStyle.Layout.window.width, height: SettingsStyle.Layout.window.height)
        .preferredColorScheme(.light)
    }
  }

  #Preview("Settings — Dark") {
    SettingsPreview { store in
      SettingsView(store: store, selection: .rules)
        .frame(width: SettingsStyle.Layout.window.width, height: SettingsStyle.Layout.window.height)
        .preferredColorScheme(.dark)
    }
  }
#endif
