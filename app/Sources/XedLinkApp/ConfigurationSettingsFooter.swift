import AppKit
import SwiftUI

struct ConfigurationSettingsFooter: View {
  @ObservedObject var store: SettingsStore

  private var status: String {
    if store.isDirty {
      return store.errorMessage != nil || store.saveError != nil ? "Changes not saved" : "Saving…"
    }
    return "All changes saved · External changes reload automatically"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: SettingsStyle.Spacing.small) {
      Divider()
      if let message = store.errorMessage ?? store.saveError {
        Text(message).font(.callout).foregroundStyle(.red).textSelection(.enabled)
          .accessibilityIdentifier("settings.configuration.error")
      }
      HStack(spacing: SettingsStyle.Spacing.medium) {
        VStack(alignment: .leading, spacing: SettingsStyle.Spacing.extraSmall) {
          Text(store.repository.file.path).font(.caption).lineLimit(1).truncationMode(.middle)
            .textSelection(.enabled).help(store.repository.file.path)
          Text(status)
            .font(.caption).foregroundStyle(.secondary)
            .accessibilityIdentifier("settings.saveStatus")
        }
        Spacer()
        Button("Reveal File") { NSWorkspace.shared.activateFileViewerSelecting([store.repository.file]) }
        Button("Revert") { store.revert() }.accessibilityIdentifier("settings.revert")
      }
    }
    .padding(.horizontal, SettingsStyle.Spacing.extraLarge)
    .padding(.bottom, SettingsStyle.Spacing.medium)
    .background(.bar)
  }
}
