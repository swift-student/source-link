import CTOML
import Foundation

public struct ConfigurationError: LocalizedError, Sendable {
  public let message: String
  public init(_ message: String) { self.message = message }
  public var errorDescription: String? { message }
}

struct TOMLNode: Decodable, Sendable {
  let path: String
  let begin: [Int]
  let end: [Int]
  let keyBegin: [Int]?
  let keyEnd: [Int]?
  let kind: String
  let string: String?
  let integer: Int64?
  let boolean: Bool?
}

/// The original text and parser-provided source ranges are kept alongside the typed settings.
public struct ConfigurationDocument: Sendable {
  public let text: String
  public let settings: SourceSettings
  let nodes: [String: TOMLNode]

  public init(text: String) throws {
    try self.init(text: text, settingsOverride: nil)
  }

  init(text: String, settingsOverride: SourceSettings?) throws {
    struct ParseResult: Decodable {
      let nodes: [TOMLNode]?
      let error: String?
      let position: [Int]?
    }
    let bytes = Array(text.utf8)
    let pointer = bytes.withUnsafeBytes { buffer in
      sl_toml_parse(buffer.baseAddress?.assumingMemoryBound(to: CChar.self), buffer.count)
    }
    guard let pointer else { throw ConfigurationError("Unable to allocate TOML parser output.") }
    defer { sl_toml_free(pointer) }
    let result = try JSONDecoder().decode(ParseResult.self, from: Data(String(cString: pointer).utf8))
    if let error = result.error {
      let location = result.position.map { "line \($0[0]), column \($0[1]): " } ?? ""
      throw ConfigurationError(location + error)
    }
    self.text = text
    nodes = Dictionary(uniqueKeysWithValues: (result.nodes ?? []).map { ($0.path, $0) })
    settings = try settingsOverride ?? ConfigurationSchema.decode(nodes)
  }

  public static func initial(_ settings: SourceSettings = SourceSettings()) throws -> Self {
    try Self(text: ConfigurationSchema.encode(settings))
  }
}

/// IDs are presentation state, not part of the on-disk schema or conflict comparison.
extension SourceSettings {
  public func hasSameConfiguration(as other: Self) -> Bool {
    defaultEditor == other.defaultEditor && executablePaths == other.executablePaths
      && checkouts.map { CheckoutFields($0) } == other.checkouts.map { CheckoutFields($0) }
      && rules.map { RuleFields($0) } == other.rules.map { RuleFields($0) }
  }
}

struct CheckoutFields: Equatable {
  let name: String
  let path: String
  let isDefault: Bool
  init(_ checkout: Checkout) {
    name = checkout.name; path = checkout.path; isDefault = checkout.isDefault
  }
}

struct RuleFields: Equatable {
  let fileExtension: String
  let editor: Editor
  init(_ rule: FileRule) { fileExtension = rule.fileExtension; editor = rule.editor }
}

/// Paths are expanded only when used, so portable spelling survives UI edits.
public enum ConfigurationPaths {
  public static func file(environment: [String: String] = ProcessInfo.processInfo.environment,
                          home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
    let directory: URL
    if let configured = environment["XDG_CONFIG_HOME"], configured.hasPrefix("/") {
      directory = URL(fileURLWithPath: configured, isDirectory: true)
    } else {
      directory = home.appendingPathComponent(".config", isDirectory: true)
    }
    return directory.appendingPathComponent("source-link/config.toml")
  }

  public static func expand(_ path: String, home: URL = FileManager.default.homeDirectoryForCurrentUser) -> String {
    path.hasPrefix("~/") ? home.appendingPathComponent(String(path.dropFirst(2))).path : path
  }
}
