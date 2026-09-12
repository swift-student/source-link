import Foundation

/// The disk schema is versioned separately from UI models and never stores row IDs.
enum ConfigurationSchema {
  static func decode(_ data: Data) throws -> SourceSettings {
    do {
      let configuration = try JSONDecoder().decode(Configuration.self, from: data)
      let settings = configuration.settings
      try validate(settings)
      return settings
    } catch let error as DecodingError {
      let context: DecodingError.Context
      switch error {
      case let .dataCorrupted(value), let .keyNotFound(_, value),
           let .typeMismatch(_, value), let .valueNotFound(_, value): context = value
      @unknown default: throw ConfigurationError("Invalid JSON configuration.")
      }
      let path = context.codingPath.map(\.stringValue).joined(separator: ".")
      throw ConfigurationError("\(path.isEmpty ? "Configuration" : path): \(context.debugDescription)")
    }
  }

  static func encode(_ settings: SourceSettings) throws -> String {
    try validate(settings)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(Configuration(settings))
    guard let text = String(data: data, encoding: .utf8) else {
      throw ConfigurationError("Unable to encode configuration as UTF-8.")
    }
    return text + "\n"
  }

  private static func validate(_ settings: SourceSettings) throws {
    for (key, value) in settings.executablePaths {
      guard Editor(rawValue: key) != nil else { throw ConfigurationError("executables.\(key) is an unknown key.") }
      try path(value, key: "executables.\(key)")
    }
    for (index, checkout) in settings.checkouts.enumerated() {
      guard !checkout.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !checkout.name.contains("\0")
      else {
        throw ConfigurationError("checkouts.\(index).name must not be empty or contain null characters.")
      }
      try path(checkout.path, key: "checkouts.\(index).path")
    }
    let defaults = settings.checkouts.filter(\.isDefault).map { $0.name.lowercased() }
    guard Set(defaults).count == defaults.count else {
      throw ConfigurationError("checkouts allows at most one default per repository.")
    }
    for (index, rule) in settings.rules.enumerated() {
      guard !rule.fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: ". ")).isEmpty,
            !rule.fileExtension.contains("\0")
      else {
        throw ConfigurationError("rules.\(index).extension must not be empty or contain null characters.")
      }
    }
  }

  private static func path(_ value: String, key: String) throws {
    guard value.hasPrefix("/") || value.hasPrefix("~/"), !value.contains("\0") else {
      throw ConfigurationError("\(key) must be an absolute path or start with ~/ and contain no null characters.")
    }
  }
}

private struct Configuration: Codable {
  var version = 1
  var defaultEditor: Editor
  var executables: [String: String]
  var checkouts: [ConfigurationCheckout]
  var rules: [ConfigurationRule]

  enum CodingKeys: String, CodingKey, CaseIterable {
    case version, defaultEditor = "default_editor", executables, checkouts, rules
  }

  init(_ settings: SourceSettings) {
    defaultEditor = settings.defaultEditor
    executables = settings.executablePaths
    checkouts = settings.checkouts.map(ConfigurationCheckout.init)
    rules = settings.rules.map { ConfigurationRule(extension: $0.fileExtension, editor: $0.editor) }
  }

  init(from decoder: any Decoder) throws {
    let values = try decoder.checkedContainer(keyedBy: CodingKeys.self)
    version = try values.decode(Int.self, forKey: .version)
    guard version == 1 else { throw ConfigurationError("version must be the integer 1 (supported schema version).") }
    defaultEditor = try values.contains(.defaultEditor) ? values.decode(Editor.self, forKey: .defaultEditor) : .xcode
    executables = try values.contains(.executables) ? values.decode([String: String].self, forKey: .executables) : [:]
    checkouts = try values.contains(.checkouts) ? values.decode([ConfigurationCheckout].self, forKey: .checkouts) : []
    rules = try values.contains(.rules) ? values.decode([ConfigurationRule].self, forKey: .rules) : []
  }

  var settings: SourceSettings {
    var settings = SourceSettings()
    settings.defaultEditor = defaultEditor
    settings.executablePaths = executables
    settings.checkouts = checkouts.map { Checkout(name: $0.name, path: $0.path, isDefault: $0.isDefault) }
    settings.rules = rules.map {
      var rule = FileRule()
      rule.fileExtension = $0.extension
      rule.editor = $0.editor
      return rule
    }
    return settings
  }
}

private struct ConfigurationCheckout: Codable {
  var name: String
  var path: String
  var isDefault: Bool

  enum CodingKeys: String, CodingKey, CaseIterable { case name, path, isDefault = "default" }

  init(_ checkout: Checkout) {
    name = checkout.name
    path = checkout.path
    isDefault = checkout.isDefault
  }

  init(from decoder: any Decoder) throws {
    let values = try decoder.checkedContainer(keyedBy: CodingKeys.self)
    name = try values.decode(String.self, forKey: .name)
    path = try values.decode(String.self, forKey: .path)
    isDefault = try values.contains(.isDefault) ? values.decode(Bool.self, forKey: .isDefault) : false
  }
}

private struct ConfigurationRule: Codable {
  var `extension`: String
  var editor: Editor

  enum CodingKeys: String, CodingKey, CaseIterable { case `extension`, editor }

  init(extension: String, editor: Editor) {
    self.extension = `extension`
    self.editor = editor
  }

  init(from decoder: any Decoder) throws {
    let values = try decoder.checkedContainer(keyedBy: CodingKeys.self)
    self.extension = try values.decode(String.self, forKey: .extension)
    editor = try values.decode(Editor.self, forKey: .editor)
  }
}

private struct ConfigurationKey: CodingKey {
  let stringValue: String
  var intValue: Int? {
    nil
  }

  init?(stringValue: String) {
    self.stringValue = stringValue
  }

  init?(intValue _: Int) {
    nil
  }
}

private extension Decoder {
  func checkedContainer<Key: CodingKey & CaseIterable>(keyedBy type: Key.Type)
    throws -> KeyedDecodingContainer<Key> {
    let keys = try container(keyedBy: ConfigurationKey.self).allKeys
    let allowed = Set(Key.allCases.map(\.stringValue))
    for key in keys where !allowed.contains(key.stringValue) {
      let path = (codingPath + [key]).map(\.stringValue).joined(separator: ".")
      throw ConfigurationError("\(path) is an unknown key.")
    }
    return try container(keyedBy: type)
  }
}
