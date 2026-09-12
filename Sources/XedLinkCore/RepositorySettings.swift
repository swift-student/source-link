import Foundation

public extension Checkout {
  var folderName: String {
    URL(fileURLWithPath: ConfigurationPaths.expand(path)).lastPathComponent
  }
}

public extension SourceSettings {
  var repositoryNames: [String] {
    var names: [String] = []
    for checkout in checkouts where !names.contains(where: {
      $0.caseInsensitiveCompare(checkout.name) == .orderedSame
    }) {
      names.append(checkout.name)
    }
    return names
  }

  func checkouts(for repository: String) -> [Checkout] {
    checkouts.filter { $0.name.caseInsensitiveCompare(repository) == .orderedSame }
  }

  /// Ensures each repository has one default after adding or removing checkouts.
  mutating func normalizeDefaults() {
    for name in repositoryNames {
      let group = checkouts(for: name)
      if let chosen = group.first(where: \.isDefault) ?? group.first {
        setDefaultCheckout(chosen.id)
      }
    }
  }

  mutating func setDefaultCheckout(_ id: UUID) {
    guard let chosen = checkouts.first(where: { $0.id == id }) else { return }
    for index in checkouts.indices where
      checkouts[index].name.caseInsensitiveCompare(chosen.name) == .orderedSame {
      checkouts[index].isDefault = checkouts[index].id == id
    }
  }

  /// New repositories take their shared identity from the main root folder's name.
  /// Additional worktrees retain that identity, regardless of their local folder name.
  mutating func addCheckout(root: URL, repository: String? = nil) {
    let root = root.standardizedFileURL
    let name = repository ?? root.lastPathComponent
    guard !name.isEmpty, root.path != "/" else { return }
    guard !checkouts(for: name).contains(where: { ConfigurationPaths.expand($0.path) == root.path }) else { return }
    checkouts.append(Checkout(name: name, path: root.path))
    normalizeDefaults()
  }

  mutating func removeCheckout(_ id: UUID) {
    checkouts.removeAll { $0.id == id }
    normalizeDefaults()
  }

  mutating func removeRepository(_ name: String) {
    checkouts.removeAll { $0.name.caseInsensitiveCompare(name) == .orderedSame }
  }
}
