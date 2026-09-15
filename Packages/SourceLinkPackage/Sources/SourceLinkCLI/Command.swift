import Foundation
import SourceLinkCore

struct CommandResult {
  var status: Int32 = 0
  var output = ""
  var diagnostics = ""
}

enum Command {
  static let usage = """
  Usage:
    source-link config path
    source-link config validate [FILE]
    source-link validate DOCUMENT [--config FILE]

  DOCUMENT is a UTF-8 text, Markdown, D2, SVG, or HTML file. Use - for standard input.
  Validates source-link: URLs against local checkouts without launching an editor.
  Exit status: 0 valid (or no links), 1 validation/read error, 2 usage error.

  """

  static func run(_ arguments: [String], standardInput: () throws -> Data = {
    try FileHandle.standardInput.readToEnd() ?? Data()
  }) -> CommandResult {
    do {
      if arguments == ["--help"] || arguments == ["-h"] {
        return CommandResult(output: usage)
      }
      if arguments == ["config", "path"] {
        return CommandResult(output: ConfigurationPaths.file().path + "\n")
      }
      if arguments.count == 2 || arguments.count == 3, Array(arguments.prefix(2)) == ["config", "validate"] {
        let file = arguments.count == 3 ? fileURL(arguments[2]) : ConfigurationPaths.file()
        _ = try configuration(at: file)
        return CommandResult(output: "\(file.path): valid\n")
      }
      let validation = arguments.first == "links" ? Array(arguments.dropFirst()) : arguments
      if validation.count == 2 || (validation.count == 4 && validation[2] == "--config"),
         validation.first == "validate", !validation[1].hasPrefix("-") || validation[1] == "-" {
        let config = validation.count == 4 ? fileURL(validation[3]) : ConfigurationPaths.file()
        return try validateDocument(validation[1], config: config, standardInput: standardInput)
      }
      return CommandResult(status: 2, diagnostics: usage)
    } catch {
      return CommandResult(status: 1, diagnostics: error.localizedDescription + "\n")
    }
  }

  private static func validateDocument(_ path: String, config: URL,
                                       standardInput: () throws -> Data) throws -> CommandResult {
    let file = fileURL(path)
    let label = path == "-" ? "<stdin>" : file.path
    let document: String
    do {
      if path == "-" {
        guard let text = try String(data: standardInput(), encoding: .utf8) else {
          throw ConfigurationError("Document must be UTF-8 text.")
        }
        document = text
      } else {
        document = try String(contentsOf: file, encoding: .utf8)
      }
    } catch { throw ConfigurationError("\(label): \(error.localizedDescription)") }
    let markup = path == "-"
      || ["md", "markdown", "svg", "html", "htm", "xml"].contains(file.pathExtension.lowercased())
    let links = try DocumentLinks.extract(from: document, decodeEntities: markup)
    let settings = try configuration(at: config)
    let results = DocumentLinkValidation.validate(links, settings: settings)
    let failures = results.filter { $0.error != nil }
    let diagnostics = failures.map { result in
      "\(label):\(result.link.line):\(result.link.column): \(result.error ?? "") "
        + "[\(result.link.text)]\n"
    }.joined()
    let summary = if links.isEmpty {
      "no source links found"
    } else {
      "\(links.count) source links checked, \(failures.count) invalid"
    }
    return CommandResult(status: failures.isEmpty ? 0 : 1, output: "\(label): \(summary)\n", diagnostics: diagnostics)
  }

  private static func configuration(at file: URL) throws -> SourceSettings {
    do {
      return try ConfigurationDocument(text: String(contentsOf: file, encoding: .utf8)).settings
    } catch { throw ConfigurationError("\(file.path): \(error.localizedDescription)") }
  }

  private static func fileURL(_ path: String) -> URL {
    URL(fileURLWithPath: ConfigurationPaths.expand(path))
  }
}
