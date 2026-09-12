import Foundation

extension ConfigurationDocument {
  /// Merge independently edited fields. Collections conflict as a unit to avoid ambiguous row identity.
  public func merging(base: SourceSettings, draft: SourceSettings) throws -> ConfigurationDocument {
    var merged = settings
    merged.defaultEditor = try merge(base.defaultEditor, draft.defaultEditor, settings.defaultEditor, "default_editor")
    let keys = Set(base.editors.keys).union(draft.editors.keys).union(settings.editors.keys)
    for key in keys {
      merged.editors[key] = try merge(base.editors[key], draft.editors[key], settings.editors[key], "editors.\(key)")
    }
    let checkouts = try merge(base.checkouts.map { CheckoutFields($0) }, draft.checkouts.map { CheckoutFields($0) },
                              settings.checkouts.map { CheckoutFields($0) }, "checkouts")
    if checkouts != settings.checkouts.map({ CheckoutFields($0) }) {
      merged.checkouts = draft.checkouts
    }
    let rules = try merge(base.rules.map { RuleFields($0) }, draft.rules.map { RuleFields($0) },
                          settings.rules.map { RuleFields($0) }, "rules")
    if rules != settings.rules.map({ RuleFields($0) }) {
      merged.rules = draft.rules
    }
    return try updating(to: merged)
  }

  private func merge<Value: Equatable>(_ base: Value, _ draft: Value, _ disk: Value, _ key: String) throws -> Value {
    guard draft != base else { return disk }
    guard disk == base || disk == draft else {
      throw ConfigurationError("Conflict in \(key): the file changed while you were editing. "
        + "Your draft is retained. Adjust the conflicting setting to match the file, "
        + "or restart Source Link to discard unsaved changes.")
    }
    return draft
  }

  func updating(to desired: SourceSettings) throws -> Self {
    try Self.initial(desired)
  }
}
