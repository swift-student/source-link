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

/// Keeps the disclosure button separate from row actions, with a generous hit area.
struct SettingsDisclosureGroupStyle: DisclosureGroupStyle {
  let title: String

  func makeBody(configuration: Configuration) -> some View {
    VStack(spacing: 0) {
      HStack(spacing: 0) {
        Button {
          configuration.isExpanded.toggle()
        } label: {
          Image(systemName: configuration.isExpanded ? "chevron.down" : "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: 36, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(configuration.isExpanded ? "Collapse" : "Expand") \(title)")
        .accessibilityValue(configuration.isExpanded ? "Expanded" : "Collapsed")
        configuration.label
      }
      if configuration.isExpanded {
        configuration.content
      }
    }
  }
}

struct DefaultBadge: View {
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Text("Default")
      .font(.body)
      .foregroundStyle(SettingsStyle.actionForeground)
      .padding(.horizontal, SettingsStyle.Spacing.medium)
      .padding(.vertical, SettingsStyle.Spacing.small)
      .background(
        SettingsStyle.selectionBackground(for: colorScheme),
        in: RoundedRectangle(cornerRadius: SettingsStyle.badgeRadius)
      )
  }
}

/// A single appearance-aware foreground for inline settings actions.
struct SettingsLinkButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled
  @State private var isHovered = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(isEnabled ? SettingsStyle.actionForeground : Color.secondary)
      .opacity(configuration.isPressed ? 0.65 : 1)
      .brightness(isHovered && isEnabled ? 0.06 : 0)
      .contentShape(Rectangle())
      .onHover { isHovered = $0 }
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
