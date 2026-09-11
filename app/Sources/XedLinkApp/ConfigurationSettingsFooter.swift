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
        Text(store.isDirty ? "Unsaved changes" : "All changes saved")
          .font(.system(size: 12)).foregroundStyle(.secondary)
          .accessibilityIdentifier("settings.saveStatus")
        Spacer()
        Button("Reveal Configuration") { NSWorkspace.shared.activateFileViewerSelecting([store.repository.file]) }
          .help(store.repository.file.path)
        Button("Revert") { store.revert() }.disabled(!store.isDirty)
          .accessibilityIdentifier("settings.revert")

      }
    }
    .buttonStyle(.plain)
    .font(.system(size: 12)).foregroundStyle(.secondary)
    .padding(.horizontal, 40)
    .padding(.bottom, 24)
    .background(SettingsStyle.pageBackground)
  }
}
