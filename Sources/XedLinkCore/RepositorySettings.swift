import Foundation

extension Checkout {
  public var folderName: String { URL(fileURLWithPath: ConfigurationPaths.expand(path)).lastPathComponent }
}

extension SourceSettings {
  public var repositoryNames: [String] {
    var names: [String] = []
    for checkout in checkouts where !names.contains(where: {
      $0.caseInsensitiveCompare(checkout.name) == .orderedSame
    }) {
      names.append(checkout.name)
    }
    return names
  }

  public func checkouts(for repository: String) -> [Checkout] {
    checkouts.filter { $0.name.caseInsensitiveCompare(repository) == .orderedSame }
  }

  /// Repairs older settings without changing repository identities or folder mappings.
  public mutating func normalizeDefaults() {
    for name in repositoryNames {
      let group = checkouts(for: name)
      if let chosen = group.first(where: \.isDefault) ?? group.first {
        setDefaultCheckout(chosen.id)
      }
    }
  }

  public mutating func setDefaultCheckout(_ id: UUID) {
    guard let chosen = checkouts.first(where: { $0.id == id }) else { return }
    for index in checkouts.indices where
      checkouts[index].name.caseInsensitiveCompare(chosen.name) == .orderedSame {
      checkouts[index].isDefault = checkouts[index].id == id
    }
  }

  /// New repositories take their shared identity from the main root folder's name.
  /// Additional worktrees retain that identity, regardless of their local folder name.
  public mutating func addCheckout(root: URL, repository: String? = nil) {
    let root = root.standardizedFileURL
    let name = repository ?? root.lastPathComponent
    guard !name.isEmpty, root.path != "/" else { return }
    guard !checkouts(for: name).contains(where: { ConfigurationPaths.expand($0.path) == root.path }) else { return }
    checkouts.append(Checkout(name: name, path: root.path))
    normalizeDefaults()
  }

  public mutating func removeCheckout(_ id: UUID) {
    checkouts.removeAll { $0.id == id }
    normalizeDefaults()
  }

  public mutating func removeRepository(_ name: String) {
    checkouts.removeAll { $0.name.caseInsensitiveCompare(name) == .orderedSame }
  }
}
