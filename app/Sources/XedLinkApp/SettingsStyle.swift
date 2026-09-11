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
    static let windowControlsHeight: CGFloat = 44
    static let sidebarRadius: CGFloat = 18
    static let windowControlsCenter = Spacing.small + sidebarRadius
    static let sidebarMinimum: CGFloat = 190
    static let sidebarIdeal: CGFloat = 220
    static let sidebarMaximum: CGFloat = 260
    static let editorPicker: CGFloat = 200
    static let ruleOrder: CGFloat = 44
    static let extensionField: CGFloat = 160
    static let actionMenu: CGFloat = 28
    static let checkoutStatus: CGFloat = 100
    static let emptyRulesHeight: CGFloat = 180
    static let rulesMinimumHeight: CGFloat = 160
  }

  static let headingFont = Font.system(size: 24, weight: .semibold)
  static let cardRadius: CGFloat = 8
  static let badgeRadius: CGFloat = 4
  static let pageBackground = Color(nsColor: .textBackgroundColor)
  static let sidebarBackground = Color.primary.opacity(0.045)
  static let cardBackground = Color(nsColor: .controlBackgroundColor)
  static let cardBorder = Color(nsColor: .separatorColor).opacity(0.5)
  static let tableHeaderBackground = Color.primary.opacity(0.03)
  static let badgeBackground = Color.accentColor.opacity(0.1)
}
