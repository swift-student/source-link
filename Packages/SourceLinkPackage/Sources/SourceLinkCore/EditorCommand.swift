import Foundation

public struct EditorCommand: Equatable, Sendable {
  public let executable: String
  public let arguments: [String]

  public init(editor: Editor, executable: String? = nil, file: URL, line: Int?, column: Int?, project: URL? = nil) {
    self.init(profile: EditorProfile.defaults[editor.rawValue] ?? EditorProfile(
      name: editor.rawValue, executable: "", arguments: ["{file}"]
    ),
    executable: executable, file: file, line: line, column: column, project: project)
  }

  public init(
    profile: EditorProfile,
    executable: String? = nil,
    file: URL,
    line: Int?,
    column: Int?,
    project: URL? = nil
  ) {
    self.executable = ConfigurationPaths.expand(
      executable.flatMap { $0.isEmpty ? nil : $0 } ?? profile.executable
    )
    let positionTemplate = line == nil ? profile.arguments
      : (column == nil ? profile.lineArguments ?? profile.arguments
        : profile.columnArguments ?? profile.lineArguments ?? profile.arguments)
    let template = (project == nil ? [] : profile.projectArguments ?? []) + positionTemplate
    let values = [
      "project": project?.path ?? "",
      "file": file.path,
      "line": String(line ?? 1),
      "column": String(column ?? 1)
    ]
    arguments = template.map { argument in
      // Replace only template tokens, never text introduced by the file path.
      argument.split(separator: "{", omittingEmptySubsequences: false).enumerated().map { index, part in
        guard index > 0 else { return String(part) }
        guard let end = part.firstIndex(of: "}"), let value = values[String(part[..<end])] else {
          return "{" + part
        }
        return value + part[part.index(after: end)...]
      }.joined()
    }
  }

  public func run() throws {
    guard executable.hasPrefix("/"), FileManager.default.isExecutableFile(atPath: executable) else {
      throw SourceLinkError.invalidEditor
    }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { throw SourceLinkError.launchFailed }
  }
}
