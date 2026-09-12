import Foundation

public struct EditorCommand: Equatable, Sendable {
  public let executable: String
  public let arguments: [String]

  public init(
    editor: Editor, executable: String? = nil, file: URL, line: Int?, column: Int?,
    project: URL? = nil
  ) {
    self.executable = ConfigurationPaths.expand(
      executable.flatMap { $0.isEmpty ? nil : $0 } ?? editor.defaultExecutable
    )
    switch editor {
    case .xcode:
      arguments = (project.map { ["-p", $0.path] } ?? [])
        + (line.map { ["--line", String($0)] } ?? []) + [file.path]
    case .vscode, .cursor:
      arguments = ["--goto", file.path + (line.map { ":\($0):\(column ?? 1)" } ?? "")]
    case .zed:
      arguments = [file.path + (line.map { ":\($0):\(column ?? 1)" } ?? "")]
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
