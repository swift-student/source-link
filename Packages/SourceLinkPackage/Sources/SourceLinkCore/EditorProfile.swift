import Foundation

public struct EditorProfile: Codable, Equatable, Sendable {
  public var name: String
  public var executable: String
  public var arguments: [String]
  public var lineArguments: [String]?
  public var columnArguments: [String]?
  public var projectArguments: [String]?

  enum CodingKeys: String, CodingKey, CaseIterable {
    case projectArguments = "project_arguments"
    case name, executable, arguments, lineArguments = "line_arguments", columnArguments = "column_arguments"
  }

  public init(name: String, executable: String, arguments: [String],
              lineArguments: [String]? = nil, columnArguments: [String]? = nil, projectArguments: [String]? = nil) {
    self.name = name
    self.executable = executable
    self.arguments = arguments
    self.lineArguments = lineArguments
    self.columnArguments = columnArguments
    self.projectArguments = projectArguments
  }

  public init(from decoder: any Decoder) throws {
    let values = try decoder.checkedContainer(keyedBy: CodingKeys.self)
    projectArguments = try values.decodeIfPresent([String].self, forKey: .projectArguments)
    name = try values.decode(String.self, forKey: .name)
    executable = try values.decode(String.self, forKey: .executable)
    arguments = try values.decode([String].self, forKey: .arguments)
    lineArguments = try values.contains(.lineArguments) ? values.decode([String].self, forKey: .lineArguments) : nil
    columnArguments = try values.contains(.columnArguments)
      ? values.decode([String].self, forKey: .columnArguments) : nil
  }

  public static let defaults: [String: EditorProfile] = {
    do {
      #if SWIFT_PACKAGE
        // Native SwiftPM builds search the app root; signed macOS apps keep bundles in Resources.
        let resources = Bundle.main.url(forResource: "SourceLinkPackage_SourceLinkCore", withExtension: "bundle")
          .flatMap(Bundle.init(url:)) ?? Bundle.module
        let url = resources.url(forResource: "editors", withExtension: "json")
      #else
        // The direct build puts resources in the app bundle and beside the CLI.
        let url = Bundle.main.url(forResource: "editors", withExtension: "json")
          ?? Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("editors.json")
      #endif
      guard let url else { throw ConfigurationError("Bundled editors.json is missing.") }
      return try JSONDecoder().decode([String: EditorProfile].self, from: Data(contentsOf: url))
    } catch {
      preconditionFailure("Unable to load bundled editor profiles: \(error)")
    }
  }()
}
