import AppKit
import SwiftUI
import XedLinkCore

struct RepositoriesSettingsView: View {
  @ObservedObject var store: SettingsStore
  @State private var collapsed: Set<String> = []

  var body: some View {
    GeometryReader { geometry in
      ScrollView {
        VStack(alignment: .leading, spacing: SettingsStyle.Spacing.section) {
          SettingsHeading(title: "Repositories", subtitle: "Connect shared source links to folders on this Mac.") {
            if !store.settings.checkouts.isEmpty {
              Button("Add Repository", systemImage: "plus") { addRepository() }
            }
          }
          if store.settings.checkouts.isEmpty {
            VStack(spacing: 10) {
              Text("No repositories yet")
                .font(.system(size: 16, weight: .semibold))
              Button("+ Add Repository…") { addRepository() }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(SettingsStyle.pageBackground, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(SettingsStyle.cardBorder))
                .accessibilityIdentifier("repositories.add")
            }
            .frame(maxWidth: .infinity)
            .padding(.top, max(40, geometry.size.height * 0.35 - 84))
          } else {
            SettingsCard {
              ForEach(store.settings.repositoryNames, id: \.self) { name in
                if name != store.settings.repositoryNames.first { Divider() }
                repositoryGroup(name)
              }
            }
          }
        }
        .padding(.horizontal, 40)
        .padding(.top, 32)
        .padding(.bottom, 24)
      }
    }
  }

  private func repositoryGroup(_ name: String) -> some View {
    let checkouts = store.settings.checkouts(for: name)
    return DisclosureGroup(isExpanded: Binding(
      get: { !collapsed.contains(name) },
      set: { if $0 { collapsed.remove(name) } else { collapsed.insert(name) } }
    )) {
      VStack(spacing: 0) {
        ForEach(checkouts) { checkout in
          Divider()
          checkoutRow(checkout)
        }
        HStack {
          Button("Add Checkout to \(name)…", systemImage: "plus") { addCheckout(to: name) }
            .buttonStyle(.link)
          Spacer()
        }
        .padding(.leading, SettingsStyle.Spacing.page).padding(.vertical, SettingsStyle.Spacing.large)
      }
    } label: {
      HStack(spacing: SettingsStyle.Spacing.medium) {
        Image(systemName: "folder").font(.title3).foregroundStyle(.secondary)
        Text(name).font(.headline).lineLimit(1).help(name)
        Spacer()
        Text("\(checkouts.count) \(checkouts.count == 1 ? "checkout" : "checkouts")")
          .font(.callout).foregroundStyle(.secondary)
        SettingsActions(label: "Actions for \(name)") {
          Button("Add Checkout…") { addCheckout(to: name) }
          Divider()
          Button("Remove Repository", role: .destructive) { store.settings.removeRepository(name) }
        }
      }
      .padding(.vertical, SettingsStyle.Spacing.large)
    }
    .padding(.horizontal, SettingsStyle.Spacing.large)
  }

  private func checkoutRow(_ checkout: Checkout) -> some View {
    HStack(spacing: SettingsStyle.Spacing.medium) {
      Image(systemName: "arrow.turn.down.right").foregroundStyle(.tertiary).frame(width: 20)
      VStack(alignment: .leading, spacing: SettingsStyle.Spacing.small) {
        Text(checkout.folderName).fontWeight(.medium).lineLimit(1)
        Text((checkout.path as NSString).abbreviatingWithTildeInPath)
          .font(.callout).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
          .textSelection(.enabled).help(checkout.path)
      }
      Spacer(minLength: SettingsStyle.Spacing.medium)
      Group {
        if checkout.isDefault { DefaultBadge() } else {
          Button("Make Default") { store.settings.setDefaultCheckout(checkout.id) }.buttonStyle(.link)
        }
      }
      .frame(width: SettingsStyle.Layout.checkoutStatus)
      SettingsActions(label: "Actions for checkout \(checkout.folderName)") {
        Button("Show in Finder") {
          NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: ConfigurationPaths.expand(checkout.path))
        }
        Button("Change Folder…") { changeFolder(checkout) }
        Divider()
        Button("Remove Checkout", role: .destructive) { store.settings.removeCheckout(checkout.id) }
      }
    }
    .padding(.leading, SettingsStyle.Spacing.medium).padding(.vertical, SettingsStyle.Spacing.large)
  }

  private func addRepository() {
    guard let root = SettingsPanels.chooseFolder(
      title: "Add Repository", message: "Choose the main repository root. Its folder name will identify shared links."
    ) else { return }
    store.settings.addCheckout(root: root)
    collapsed.remove(root.lastPathComponent)
  }

  private func addCheckout(to name: String) {
    guard let root = SettingsPanels.chooseFolder(
      title: "Add Checkout to \(name)", message: "Choose a local checkout or worktree. Shared links keep using \(name)."
    ) else { return }
    store.settings.addCheckout(root: root, repository: name)
  }

  private func changeFolder(_ checkout: Checkout) {
    guard let root = SettingsPanels.chooseFolder(
      title: "Change Checkout Folder", message: "Choose a replacement folder for \(checkout.name)."
    ), let index = store.settings.checkouts.firstIndex(where: { $0.id == checkout.id }) else { return }
    guard !store.settings.checkouts(for: checkout.name).contains(where: {
      $0.id != checkout.id && ConfigurationPaths.expand($0.path) == root.path
    }) else { return }
    store.settings.checkouts[index].path = root.path
  }
}
