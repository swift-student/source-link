import SwiftUI

struct SettingsHeading<Actions: View>: View {
  let title: String
  let subtitle: String
  @ViewBuilder var actions: Actions

  var body: some View {
    HStack(alignment: .top, spacing: SettingsStyle.Spacing.large) {
      VStack(alignment: .leading, spacing: SettingsStyle.Spacing.small) {
        Text(title).font(SettingsStyle.headingFont)
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
      .background(SettingsStyle.cardBackground)
      .clipShape(RoundedRectangle(cornerRadius: SettingsStyle.cardRadius))
      .overlay(RoundedRectangle(cornerRadius: SettingsStyle.cardRadius).strokeBorder(SettingsStyle.cardBorder))
  }
}

struct DefaultBadge: View {
  var body: some View {
    Text("Default").font(.caption).foregroundStyle(Color.accentColor)
      .padding(.horizontal, SettingsStyle.Spacing.small).padding(.vertical, SettingsStyle.Spacing.extraSmall)
      .background(SettingsStyle.badgeBackground, in: RoundedRectangle(cornerRadius: SettingsStyle.badgeRadius))
  }
}

struct SettingsActions<Content: View>: View {
  let label: String
  @ViewBuilder var content: Content

  var body: some View {
    Menu { content } label: { Image(systemName: "ellipsis") }
      .menuStyle(.borderlessButton).menuIndicator(.hidden)
      .fixedSize().frame(width: SettingsStyle.Layout.actionMenu).accessibilityLabel(label)
  }
}
