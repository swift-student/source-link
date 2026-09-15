import ArgumentParser
import Foundation
import SourceLinkCore

struct CommandResult {
  var status: Int32 = 0
  var output = ""
  var diagnostics = ""
}

/// Keeps command execution testable without exiting the process or replacing global input/output handles.
protocol CommandOperation: ParsableCommand {
  func execute(standardInput: () throws -> Data) throws -> CommandResult
}

enum Command {
  static func run(_ arguments: [String], standardInput: () throws -> Data = {
    try FileHandle.standardInput.readToEnd() ?? Data()
  }) -> CommandResult {
    let operation: any CommandOperation
    do {
      var parsed = try SourceLinkCommand.parseAsRoot(arguments)
      guard let command = parsed as? any CommandOperation else {
        // ArgumentParser's built-in help and completion commands throw clean exits.
        try parsed.run()
        return CommandResult()
      }
      operation = command
    } catch {
      let message = SourceLinkCommand.fullMessage(for: error) + "\n"
      // Preserve the CLI's documented usage status instead of ArgumentParser's platform-specific value.
      return SourceLinkCommand.exitCode(for: error).isSuccess
        ? CommandResult(output: message)
        : CommandResult(status: 2, diagnostics: message)
    }
    do {
      return try operation.execute(standardInput: standardInput)
    } catch {
      return CommandResult(status: 1, diagnostics: error.localizedDescription + "\n")
    }
  }
}

private struct SourceLinkCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "source-link",
    abstract: "Open and validate portable links to local source files.",
    discussion: "Exit status: 0 valid (or no links), 1 validation/read error, 2 usage error.",
    subcommands: [ValidateDocument.self, Config.self, Links.self]
  )
}

private struct Config: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Locate or validate the Source Link configuration.",
    subcommands: [ConfigPath.self, ConfigValidate.self]
  )
}

private struct Links: ParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Validate document links (alias for source-link validate).",
    shouldDisplay: false,
    subcommands: [ValidateDocument.self]
  )
}

private struct ConfigPath: CommandOperation {
  static let configuration = CommandConfiguration(commandName: "path", abstract: "Print the configuration path.")

  func execute(standardInput _: () throws -> Data) throws -> CommandResult {
    CommandResult(output: ConfigurationPaths.file().path + "\n")
  }
}

private struct ConfigValidate: CommandOperation {
  static let configuration = CommandConfiguration(commandName: "validate", abstract: "Validate a configuration file.")

  @Argument(help: "Configuration file; defaults to the app's saved configuration.", completion: .file())
  var file: String?

  func execute(standardInput _: () throws -> Data) throws -> CommandResult {
    let url = file.map(CommandFiles.fileURL) ?? ConfigurationPaths.file()
    _ = try CommandFiles.configuration(at: url)
    return CommandResult(output: "\(url.path): valid\n")
  }
}

enum CommandFiles {
  static func configuration(at file: URL) throws -> SourceSettings {
    do {
      return try ConfigurationDocument(text: String(contentsOf: file, encoding: .utf8)).settings
    } catch { throw ConfigurationError("\(file.path): \(error.localizedDescription)") }
  }

  static func fileURL(_ path: String) -> URL {
    URL(fileURLWithPath: ConfigurationPaths.expand(path))
  }
}
