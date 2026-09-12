import Foundation

public struct ConfigurationError: LocalizedError, Sendable {
  public let message: String
  public init(_ message: String) {
    self.message = message
  }

  public var errorDescription: String? {
    message
  }
}

/// Retains the original bytes for optimistic concurrency checks; saves use canonical JSON.
public struct ConfigurationDocument: Sendable {
  public let text: String
  public let settings: SourceSettings

  public init(text: String) throws {
    self.text = text
    settings = try ConfigurationSchema.decode(Data(text.utf8))
  }

  public static func initial(_ settings: SourceSettings = SourceSettings()) throws -> Self {
    try Self(text: ConfigurationSchema.encode(settings))
  }
}

/// IDs are presentation state, not part of the on-disk schema or conflict comparison.
public extension SourceSettings {
  func hasSameConfiguration(as other: Self) -> Bool {
    defaultEditor == other.defaultEditor && executablePaths == other.executablePaths
      && editors == other.editors
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
  init(_ rule: FileRule) {
    fileExtension = rule.fileExtension; editor = rule.editor
  }
}

/// Paths are expanded only when used, so portable spelling survives UI edits.
public enum ConfigurationPaths {
  public static func file(environment: [String: String] = ProcessInfo.processInfo.environment,
                          home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
    let directory: URL = if let configured = environment["XDG_CONFIG_HOME"], configured.hasPrefix("/") {
      URL(fileURLWithPath: configured, isDirectory: true)
    } else {
      home.appendingPathComponent(".config", isDirectory: true)
    }
    return directory.appendingPathComponent("source-link/config.json")
  }

  public static func expand(_ path: String, home: URL = FileManager.default.homeDirectoryForCurrentUser) -> String {
    path.hasPrefix("~/") ? home.appendingPathComponent(String(path.dropFirst(2))).path : path
  }
}
