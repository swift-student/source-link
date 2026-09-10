import Foundation

extension ConfigurationDocument {
  /// Merge independently edited fields. Collections conflict as a unit to avoid ambiguous row identity.
  public func merging(base: SourceSettings, draft: SourceSettings) throws -> ConfigurationDocument {
    var merged = settings
    merged.defaultEditor = try merge(base.defaultEditor, draft.defaultEditor, settings.defaultEditor, "default_editor")
    for editor in Editor.allCases {
      let key = editor.rawValue
      merged.executablePaths[key] = try merge(base.executablePaths[key], draft.executablePaths[key],
                                               settings.executablePaths[key], "executables.\(key)")
    }
    let checkouts = try merge(base.checkouts.map { CheckoutFields($0) }, draft.checkouts.map { CheckoutFields($0) },
                              settings.checkouts.map { CheckoutFields($0) }, "checkouts")
    if checkouts != settings.checkouts.map({ CheckoutFields($0) }) { merged.checkouts = draft.checkouts }
    let rules = try merge(base.rules.map { RuleFields($0) }, draft.rules.map { RuleFields($0) },
                          settings.rules.map { RuleFields($0) }, "rules")
    if rules != settings.rules.map({ RuleFields($0) }) { merged.rules = draft.rules }
    return try updating(to: merged)
  }

  private func merge<Value: Equatable>(_ base: Value, _ draft: Value, _ disk: Value, _ key: String) throws -> Value {
    guard draft != base else { return disk }
    guard disk == base || disk == draft else {
      throw ConfigurationError("Conflict in \(key): the file changed while you were editing. "
        + "Your draft is retained. Use Revert to load the file, or edit the file to resolve the conflict.")
    }
    return draft
  }

  func updating(to desired: SourceSettings) throws -> Self {
    _ = try Self.initial(desired)
    var editor = DocumentEditor(document: self)
    if desired.defaultEditor != settings.defaultEditor {
      try editor.set("/default_editor", literal: ConfigurationSchema.quote(desired.defaultEditor.rawValue))
    }
    for profile in Editor.allCases {
      let key = profile.rawValue
      if desired.executablePaths[key] != settings.executablePaths[key] {
        try editor.set("/executables/\(key)", literal: desired.executablePaths[key].map(ConfigurationSchema.quote))
      }
    }
    try editor.updateCollections(desired)
    let result = try Self(text: editor.text)
    guard result.settings.hasSameConfiguration(as: desired) else {
      throw ConfigurationError("The document edit could not preserve the requested settings. The file was not saved.")
    }
    return result
  }
}

/// Edits use parser ranges, not a second TOML grammar. Every resulting document is parsed again before saving.
private struct DocumentEditor {
  var document: ConfigurationDocument
  var text: String { document.text }

  mutating func replace(_ edits: [(Range<String.Index>, String)]) throws {
    var result = text
    for (range, replacement) in edits.sorted(by: { $0.0.lowerBound > $1.0.lowerBound }) {
      result.replaceSubrange(range, with: replacement)
    }
    document = try ConfigurationDocument(text: result, settingsOverride: document.settings)
  }

  func index(_ position: [Int]) -> String.Index {
    let scalars = text.unicodeScalars
    var cursor = scalars.startIndex
    var line = 1
    while line < position[0], cursor < scalars.endIndex {
      if scalars[cursor] == "\n" { line += 1 }
      cursor = scalars.index(after: cursor)
    }
    return scalars.index(cursor, offsetBy: position[1] - 1, limitedBy: scalars.endIndex) ?? scalars.endIndex
  }

  func range(_ node: TOMLNode) -> Range<String.Index> { index(node.begin)..<index(node.end) }

  func lineStart(_ cursor: String.Index) -> String.Index {
    text[..<cursor].lastIndex(of: "\n").map { text.index(after: $0) } ?? text.startIndex
  }

  func afterLine(_ cursor: String.Index) -> String.Index {
    text[cursor...].firstIndex(of: "\n").map { text.index(after: $0) } ?? text.endIndex
  }

  mutating func set(_ path: String, literal: String?) throws {
    if let node = document.nodes[path] {
      if let literal { try replace([(range(node), literal)]) } else { try removeScalar(node) }
      return
    }
    guard let literal else { return }
    let parentPath = String(path[..<(path.lastIndex(of: "/") ?? path.startIndex)])
    let key = String(path.split(separator: "/").last ?? "")
    if let parent = document.nodes[parentPath], parentPath != "", text[range(parent)].hasPrefix("{") {
      let end = text.index(before: index(parent.end))
      let hasChildren = document.nodes.keys.contains { $0.hasPrefix(parentPath + "/") }
      try replace([(end..<end, (hasChildren ? ", " : "") + key + " = " + literal)])
    } else if let parent = document.nodes[parentPath], parentPath != "",
              text[range(parent)].hasPrefix("[") {
      let insertion = afterLine(index(parent.end))
      let prefix = insertion == text.endIndex && !text.hasSuffix("\n") ? "\n" : ""
      try replace([(insertion..<insertion, prefix + key + " = " + literal + "\n")])
    } else {
      let dotted = path.dropFirst().replacingOccurrences(of: "/", with: ".")
      try replace([(text.startIndex..<text.startIndex, dotted + " = " + literal + "\n")])
    }
  }

  mutating func removeScalar(_ node: TOMLNode) throws {
    let parentPath = String(node.path[..<(node.path.lastIndex(of: "/") ?? node.path.startIndex)])
    if let parent = document.nodes[parentPath], text[range(parent)].hasPrefix("{") {
      let start = index(node.keyBegin ?? node.begin)
      let end = index(node.end)
      let parentEnd = text.index(before: index(parent.end))
      if let comma = text[end..<parentEnd].firstIndex(of: ",") {
        try replace([(start..<text.index(after: comma), "")])
      } else if let comma = text[index(parent.begin)..<start].lastIndex(of: ",") {
        try replace([(comma..<end, "")])
      } else { try replace([(start..<end, "")]) }
    } else {
      try replace([(lineStart(index(node.keyBegin ?? node.begin))..<index(node.end), "")])
    }
  }

  mutating func updateCollections(_ desired: SourceSettings) throws {
    if desired.checkouts.count == document.settings.checkouts.count {
      for (index, checkout) in desired.checkouts.enumerated() {
        let old = document.settings.checkouts[index]
        let key = "/checkouts/\(index)"
        if old.name != checkout.name { try set(key + "/name", literal: ConfigurationSchema.quote(checkout.name)) }
        if old.path != checkout.path { try set(key + "/path", literal: ConfigurationSchema.quote(checkout.path)) }
        if old.isDefault != checkout.isDefault { try set(key + "/default", literal: String(checkout.isDefault)) }
      }
    } else {
      try replaceCollection("checkouts", rows: desired.checkouts.map(ConfigurationSchema.checkoutText))
    }
    if desired.rules.count == document.settings.rules.count {
      for (index, rule) in desired.rules.enumerated() {
        let old = document.settings.rules[index]
        let key = "/rules/\(index)"
        if old.fileExtension != rule.fileExtension {
          try set(key + "/extension", literal: ConfigurationSchema.quote(rule.fileExtension))
        }
        if old.editor != rule.editor {
          try set(key + "/editor", literal: ConfigurationSchema.quote(rule.editor.rawValue))
        }
      }
    } else { try replaceCollection("rules", rows: desired.rules.map(ConfigurationSchema.ruleText)) }
  }

  mutating func replaceCollection(_ name: String, rows: [String]) throws {
    let path = "/" + name
    if let node = document.nodes[path], !text[range(node)].hasPrefix("[[") {
      // Inline arrays retain their comments when a structural edit requires new rows.
      let comments = comments(in: range(node))
      let entries = rows.map { "{ " + $0.split(separator: "\n").joined(separator: ", ") + " }" }
      let value = "[\n" + comments + entries.map { "  " + $0 + ",\n" }.joined() + "]"
      try replace([(range(node), value)])
      return
    }
    var edits: [(Range<String.Index>, String)] = []
    for node in document.nodes.values where node.path.hasPrefix(path + "/") {
      if node.kind == "table" { edits.append((range(node), "")) } else {
        edits.append((lineStart(index(node.keyBegin ?? node.begin))..<index(node.end), ""))
      }
    }
    let addition = rows.map { "\n[[\(name)]]\n" + $0 }.joined()
    // Apply removals and additions together; intermediate documents need not satisfy the schema.
    var result = text
    for (range, replacement) in edits.sorted(by: { $0.0.lowerBound > $1.0.lowerBound }) {
      result.replaceSubrange(range, with: replacement)
    }
    if !result.hasSuffix("\n") { result += "\n" }
    result += addition
    document = try ConfigurationDocument(text: result, settingsOverride: document.settings)
  }

  func comments(in region: Range<String.Index>) -> String {
    let strings = document.nodes.values.filter { $0.kind == "string" }.map(range)
    var cursor = region.lowerBound
    var result = ""
    while cursor < region.upperBound {
      if let string = strings.first(where: { $0.contains(cursor) }) {
        cursor = string.upperBound
      } else if text[cursor] == "#" {
        let end = min(afterLine(cursor), region.upperBound)
        result += text[cursor..<end]
        if !result.hasSuffix("\n") { result += "\n" }
        cursor = end
      } else { cursor = text.index(after: cursor) }
    }
    return result
  }
}
