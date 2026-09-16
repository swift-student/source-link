import SwiftUI

/// Shared settings rhythm. Use system fonts and semantic colors to follow macOS appearance.
enum SettingsStyle {
  enum Spacing {
    static let extraSmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let extraLarge: CGFloat = 20
    static let section: CGFloat = 24
    static let page: CGFloat = 32
  }

  enum Layout {
    static let window = CGSize(width: 1100, height: 680)
    static let minimumWindow = CGSize(width: 860, height: 540)
    static let sidebarMinimum: CGFloat = 190
    static let sidebarIdeal: CGFloat = 220
    static let sidebarMaximum: CGFloat = 260
    static let editorPicker: CGFloat = 200
    static let extensionField: CGFloat = 160
    static let actionMenu: CGFloat = 28
    static let checkoutStatus: CGFloat = 100
    static let ruleRowHeight: CGFloat = 45
    static let ruleToolbarButtonWidth: CGFloat = 32
    static let ruleToolbarHeight: CGFloat = 28
    static let ruleHeaderInset: CGFloat = 6
    // Plain macOS lists add asymmetric insets outside the row's 16-point padding.
    static let ruleColumnLeadingInset: CGFloat = 23
    static let ruleColumnTrailingInset: CGFloat = 25
    static let repositoryPageInset: CGFloat = 40
    static let checkoutIconWidth: CGFloat = 20
    // Match the popup bezel width, accounting for native button title padding.
    static let editorConfigurationInset: CGFloat = 62
    static let emptyRulesHeight: CGFloat = 180
  }

  static let headingFont = Font.system(size: 24, weight: .semibold)
  static let cardRadius: CGFloat = 8
  static let badgeRadius: CGFloat = 4
  static let pageBackground = Color(nsColor: .textBackgroundColor)
  static let cardBackground = Color(nsColor: .controlBackgroundColor)
  static let cardBorder = Color(nsColor: .separatorColor).opacity(0.5)
  static let tableHeaderBackground = Color.primary.opacity(0.03)
  /// Keep the system accent hue, but soften text toward the appearance's label color.
  static let actionForeground = Color.accentColor.mix(with: .primary, by: 0.25)

  static func selectionBackground(for colorScheme: ColorScheme) -> Color {
    Color.accentColor.opacity(colorScheme == .dark ? 0.25 : 0.1)
  }
}
