import Foundation

// The parser handles the full TOML 1.0 grammar; this layer restricts the application schema.
enum ConfigurationSchema {
  static func decode(_ nodes: [String: TOMLNode]) throws -> SourceSettings {
    try keys(nodes, at: "", allowed: ["version", "default_editor", "executables", "checkouts", "rules"])
    guard nodes["/version"]?.integer == 1 else {
      throw issue(nodes, "/version", "must be the integer 1 (supported schema version)")
    }
    var settings = SourceSettings()
    if nodes["/default_editor"] != nil {
      settings.defaultEditor = try editor(nodes, "/default_editor")
    }
    if let executables = nodes["/executables"] {
      guard executables.kind == "table" else { throw issue(nodes, "/executables", "must be a table") }
      try keys(nodes, at: "/executables", allowed: Set(Editor.allCases.map(\.rawValue)))
      for editor in Editor.allCases where nodes["/executables/\(editor.rawValue)"] != nil {
        let key = "/executables/\(editor.rawValue)"
        let value = try string(nodes, key)
        try path(value, nodes: nodes, key: key)
        settings.executablePaths[editor.rawValue] = value
      }
    }
    for index in try indices(nodes, "/checkouts") {
      let key = "/checkouts/\(index)"
      settings.checkouts.append(try checkout(nodes, key))
    }
    let defaults = settings.checkouts.filter(\.isDefault).map { $0.name.lowercased() }
    guard Set(defaults).count == defaults.count else {
      throw issue(nodes, "/checkouts", "allows at most one default per repository")
    }
    for index in try indices(nodes, "/rules") {
      let key = "/rules/\(index)"
      try keys(nodes, at: key, allowed: ["extension", "editor"])
      var rule = FileRule()
      rule.fileExtension = try string(nodes, key + "/extension")
      guard !rule.fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: ". ")).isEmpty else {
        throw issue(nodes, key + "/extension", "must not be empty")
      }
      rule.editor = try editor(nodes, key + "/editor")
      settings.rules.append(rule)
    }
    return settings
  }

  private static func checkout(_ nodes: [String: TOMLNode], _ key: String) throws -> Checkout {
    try keys(nodes, at: key, allowed: ["name", "path", "default"])
    let name = try string(nodes, key + "/name")
    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw issue(nodes, key + "/name", "must not be empty")
    }
    let value = try string(nodes, key + "/path")
    try path(value, nodes: nodes, key: key + "/path")
    var isDefault = false
    if nodes[key + "/default"] != nil {
      guard let boolean = nodes[key + "/default"]?.boolean else {
        throw issue(nodes, key + "/default", "must be a boolean")
      }
      isDefault = boolean
    }
    return Checkout(name: name, path: value, isDefault: isDefault)
  }

  static func issue(_ nodes: [String: TOMLNode], _ key: String, _ message: String) -> ConfigurationError {
    let position = nodes[key]?.begin
    let location = position.map { "line \($0[0]), column \($0[1]): " } ?? ""
    return ConfigurationError("\(location)\(key.dropFirst().replacingOccurrences(of: "/", with: ".")) \(message).")
  }

  private static func keys(_ nodes: [String: TOMLNode], at path: String, allowed: Set<String>) throws {
    guard nodes[path]?.kind == "table" else { throw issue(nodes, path, "must be a table") }
    for key in nodes.keys where key.hasPrefix(path + "/") {
      let suffix = String(key.dropFirst(path.count + 1))
      if !suffix.contains("/"), !allowed.contains(suffix) { throw issue(nodes, key, "is an unknown key") }
    }
  }

  private static func indices(_ nodes: [String: TOMLNode], _ key: String) throws -> Range<Int> {
    guard let node = nodes[key] else { return 0..<0 }
    guard node.kind == "array" else { throw issue(nodes, key, "must be an array of tables") }
    var count = 0
    while nodes[key + "/\(count)"] != nil { count += 1 }
    return 0..<count
  }

  private static func string(_ nodes: [String: TOMLNode], _ key: String) throws -> String {
    guard let value = nodes[key]?.string else { throw issue(nodes, key, "must be a string") }
    guard !value.contains("\0") else { throw issue(nodes, key, "must not contain a null character") }
    return value
  }

  private static func editor(_ nodes: [String: TOMLNode], _ key: String) throws -> Editor {
    let value = try string(nodes, key)
    guard let editor = Editor(rawValue: value) else {
      throw issue(nodes, key, "must be xcode, vscode, cursor, or zed")
    }
    return editor
  }

  private static func path(_ value: String, nodes: [String: TOMLNode], key: String) throws {
    guard value.hasPrefix("/") || value.hasPrefix("~/") else {
      throw issue(nodes, key, "must be an absolute path or start with ~/")
    }
  }

  static func quote(_ value: String) -> String {
    var result = "\""
    for scalar in value.unicodeScalars {
      switch scalar.value {
      case 0x22: result += "\\\""
      case 0x5C: result += "\\\\"
      case 0..<0x20, 0x7F: result += String(format: "\\u%04X", scalar.value)
      default: result.unicodeScalars.append(scalar)
      }
    }
    return result + "\""
  }

  static func encode(_ settings: SourceSettings) -> String {
    var text = "version = 1\ndefault_editor = \(quote(settings.defaultEditor.rawValue))\n"
    if !settings.executablePaths.isEmpty {
      text += "\n[executables]\n"
      for key in settings.executablePaths.keys.sorted() {
        text += "\(quote(key)) = \(quote(settings.executablePaths[key] ?? ""))\n"
      }
    }
    for checkout in settings.checkouts {
      text += "\n[[checkouts]]\n" + checkoutText(checkout)
    }
    for rule in settings.rules { text += "\n[[rules]]\n" + ruleText(rule) }
    return text
  }

  static func checkoutText(_ checkout: Checkout) -> String {
    "name = \(quote(checkout.name))\npath = \(quote(checkout.path))\ndefault = \(checkout.isDefault)\n"
  }

  static func ruleText(_ rule: FileRule) -> String {
    "extension = \(quote(rule.fileExtension))\neditor = \(quote(rule.editor.rawValue))\n"
  }
}
