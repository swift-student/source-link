import ArgumentParser
import Foundation
import SourceLinkCore

struct ValidateDocument: CommandOperation {
  static let configuration = CommandConfiguration(
    commandName: "validate",
    abstract: "Validate source-link: URLs in a document without launching an editor.",
    discussion: "Ambiguous symbol or text matches produce warnings by default. "
      + "Use --require-unique-symbols to reject them."
  )

  @Argument(help: "UTF-8 text, Markdown, D2, SVG, or HTML file. Use - for standard input.", completion: .file())
  var document: String

  @Option(help: "Configuration file; defaults to the app's saved configuration.", completion: .file())
  var config: String?

  @Flag(help: "Fail when a symbol link resolves to multiple destinations, after any find filtering.")
  var requireUniqueSymbols = false

  func execute(standardInput: () throws -> Data) throws -> CommandResult {
    let file = CommandFiles.fileURL(document)
    let label = document == "-" ? "<stdin>" : file.path
    let text: String
    do {
      if document == "-" {
        guard let input = try String(data: standardInput(), encoding: .utf8) else {
          throw ConfigurationError("Document must be UTF-8 text.")
        }
        text = input
      } else {
        text = try String(contentsOf: file, encoding: .utf8)
      }
    } catch { throw ConfigurationError("\(label): \(error.localizedDescription)") }
    let markup = document == "-"
      || ["md", "markdown", "svg", "html", "htm", "xml"].contains(file.pathExtension.lowercased())
    let links = try DocumentLinks.extract(from: text, decodeEntities: markup)
    let settings = try CommandFiles.configuration(at: config.map(CommandFiles.fileURL) ?? ConfigurationPaths.file())
    let results = DocumentLinkValidation.validate(links, settings: settings)
    let ambiguousCount = results.filter(\.isAmbiguous).count
    let invalidCount = results.filter { $0.error != nil }.count + (requireUniqueSymbols ? ambiguousCount : 0)
    let diagnostics = results.map { diagnostic(for: $0, label: label) }.joined()
    let summary = if links.isEmpty {
      "no source links found"
    } else {
      "\(links.count) source links checked, \(invalidCount) invalid, \(ambiguousCount) ambiguous"
    }
    return CommandResult(status: invalidCount == 0 ? 0 : 1, output: "\(label): \(summary)\n", diagnostics: diagnostics)
  }

  private func diagnostic(for result: DocumentLinkValidation, label: String) -> String {
    let location = "\(label):\(result.link.line):\(result.link.column)"
    if let error = result.error {
      return "\(location): error: \(error) [\(result.link.text)]\n"
    }
    guard result.isAmbiguous, let file = result.resolvedFile else { return "" }
    let severity = requireUniqueSymbols ? "error" : "warning"
    let candidates = result.symbolMatches.map { symbol in
      "  \(file.path):\(symbol.line):\(symbol.column): \(symbol.signature)\n"
        + (symbol.matchedLine.map { "    \($0)\n" } ?? "")
    }.joined()
    let kind = result.symbolMatches.first?.matchedLine == nil ? "declarations" : "locations"
    return "\(location): \(severity): symbol link matches \(result.symbolMatches.count) \(kind) "
      + "[\(result.link.text)]\n" + candidates
  }
}
