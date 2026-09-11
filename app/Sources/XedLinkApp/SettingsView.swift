import SwiftUI

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
  @State var selection: SettingsPage = .repositories

  var body: some View {
    HStack(spacing: 0) {
      VStack(spacing: SettingsStyle.Spacing.extraSmall) {
        ForEach(SettingsPage.allCases) { page in
          Button {
            selection = page
          } label: {
            Label(page.rawValue, systemImage: page.symbol)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(SettingsStyle.Spacing.medium)
              .foregroundStyle(selection == page ? Color.white : Color.primary)
              .background {
                if selection == page {
                  RoundedRectangle(cornerRadius: 10).fill(Color.accentColor)
                }
              }
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("settings.page.\(page.id)")
          .accessibilityAddTraits(selection == page ? .isSelected : [])
        }
        Spacer(minLength: 0)
      }
      .padding(.horizontal, SettingsStyle.Spacing.small)
      .padding(.top, SettingsStyle.Layout.windowControlsHeight)
      .frame(width: SettingsStyle.Layout.sidebarIdeal)
      .frame(maxHeight: .infinity)
      .background(SettingsStyle.sidebarBackground,
                  in: RoundedRectangle(cornerRadius: SettingsStyle.Layout.sidebarRadius))
      .overlay {
        RoundedRectangle(cornerRadius: SettingsStyle.Layout.sidebarRadius)
          .strokeBorder(SettingsStyle.cardBorder)
          .allowsHitTesting(false)
      }
      .padding(SettingsStyle.Spacing.small)

      Group {
        switch selection {
        case .repositories: RepositoriesSettingsView(store: store)
        case .editors: EditorsSettingsView(store: store)
        case .rules: ScrollView { FileRulesSettingsView(store: store) }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .background(SettingsStyle.pageBackground)
    }
    // Keep the sidebar background behind the native window controls.
    .ignoresSafeArea(.container, edges: .top)
    .frame(minWidth: SettingsStyle.Layout.minimumWindow.width,
           minHeight: SettingsStyle.Layout.minimumWindow.height)
    .safeAreaInset(edge: .bottom, spacing: 0) { ConfigurationSettingsFooter(store: store) }
    .background(SettingsStyle.pageBackground)
  }
}
