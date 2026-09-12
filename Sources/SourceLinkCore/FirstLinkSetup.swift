import Foundation

public extension SourceSettings {
  /// Applies the user's setup choice after the app has validated the file and confirmed saving.
  /// Preserve existing checkout identities and unrelated repositories and rules.
  mutating func configure(_ link: SourceLink, root: URL, editor: Editor) {
    let chosen: Checkout
    if let existing = checkouts(for: link.repository).first(where: {
      ConfigurationPaths.expand($0.path) == root.path
    }) {
      chosen = existing
    } else {
      chosen = Checkout(name: link.repository, path: root.path)
      checkouts.append(chosen)
    }
    setDefaultCheckout(chosen.id)

    let fileExtension = FileRule.normalize(root.appendingPathComponent(link.path).pathExtension)
    guard !fileExtension.isEmpty else {
      defaultEditor = editor
      return
    }
    rules.removeAll { $0.normalizedExtension == fileExtension }
    var rule = FileRule()
    rule.fileExtension = fileExtension
    rule.editor = editor
    rules.insert(rule, at: 0)
  }
}
