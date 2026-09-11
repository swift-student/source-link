import AppKit
import SwiftUI

struct ConfigurationSettingsFooter: View {
  @ObservedObject var store: SettingsStore

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
          Text(store.isDirty ? "Unsaved changes" : "External changes reload automatically")
            .font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
        Button("Reveal File") { NSWorkspace.shared.activateFileViewerSelecting([store.repository.file]) }
        Button("Revert") { store.revert() }.accessibilityIdentifier("settings.revert")
        Button("Apply") { store.save() }.disabled(!store.canApply || !store.isDirty)
          .accessibilityIdentifier("settings.apply")
      }
    }
    .padding(.horizontal, SettingsStyle.Spacing.extraLarge)
    .padding(.bottom, SettingsStyle.Spacing.medium)
    .background(.bar)
  }
}
