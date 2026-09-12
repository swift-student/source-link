import Foundation

public struct Editor: RawRepresentable, Codable, Hashable, Identifiable, Sendable {
  public let rawValue: String
  public var id: String {
    rawValue
  }

  public init?(rawValue: String) {
    guard !rawValue.isEmpty, rawValue.utf8.allSatisfy({
      (97 ... 122).contains($0) || (48 ... 57).contains($0) || $0 == 45 || $0 == 95
    }) else { return nil }
    self.rawValue = rawValue
  }

  private init(_ value: String) {
    rawValue = value
  }

  public static let xcode = Editor("xcode")
  public static let vscode = Editor("vscode")
  public static let cursor = Editor("cursor")
  public static let zed = Editor("zed")
  public static let androidStudio = Editor("android-studio")
  public static let idea = Editor("idea")
  public static let sublime = Editor("sublime")
  public static var allCases: [Editor] {
    EditorProfile.defaults.keys.sorted().compactMap(Editor.init(rawValue:))
  }

  public var title: String {
    EditorProfile.defaults[rawValue]?.name ?? rawValue
  }

  public var defaultExecutable: String {
    EditorProfile.defaults[rawValue]?.executable ?? ""
  }

  public init(from decoder: any Decoder) throws {
    let value = try decoder.singleValueContainer().decode(String.self)
    guard let editor = Editor(rawValue: value) else { throw ConfigurationError("Invalid editor identifier: \(value)") }
    self = editor
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}
