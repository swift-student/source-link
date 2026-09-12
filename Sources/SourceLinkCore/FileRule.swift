import Foundation

public struct FileRule: Codable, Identifiable, Equatable, Sendable {
  public var id = UUID()
  public var fileExtension = "swift"
  public var editor = Editor.xcode
  public init() {}

  public var normalizedExtension: String {
    Self.normalize(fileExtension)
  }

  public static func normalize(_ fileExtension: String) -> String {
    fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: ". ")).lowercased()
  }
}
