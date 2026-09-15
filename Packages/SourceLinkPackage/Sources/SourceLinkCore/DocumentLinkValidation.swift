import Foundation

public struct DocumentLinkValidation: Sendable {
  public let link: DocumentLink
  public let resolvedFile: URL?
  public let symbolMatches: [SourceSymbol]
  public let error: String?

  public var isAmbiguous: Bool {
    symbolMatches.count > 1
  }

  public static func validate(_ links: [DocumentLink], settings: SourceSettings) -> [Self] {
    // Repeated SVG href/xlink:href attributes still get individual results, but share file reads.
    var contents: [URL: Result<[Substring], any Error>] = [:]
    return links.map { occurrence in
      do {
        guard let url = URL(string: occurrence.urlText, encodingInvalidCharacters: false) else {
          throw SourceLinkError.invalidLink
        }
        let link = try SourceLink(url)
        guard let checkout = settings.checkout(for: link.repository) else {
          let known = settings.checkouts.contains { $0.name.caseInsensitiveCompare(link.repository) == .orderedSame }
          throw DocumentLinkError(known
            ? "Repository '\(link.repository)' has no unique default checkout. Set a default in the configuration."
            : "Repository '\(link.repository)' is not configured. Add a checkout to the configuration.")
        }
        let file = try link.resolve(root: URL(fileURLWithPath: ConfigurationPaths.expand(checkout.path)))
        var matches: [SourceSymbol] = []
        if let symbol = link.symbol {
          matches = try SourceSymbolResolver.matches(in: file, named: symbol)
          guard !matches.isEmpty else { throw SourceLinkError.missingSymbol }
        }
        if let line = link.line {
          if contents[file] == nil {
            contents[file] = Result {
              try String(contentsOf: file, encoding: .utf8)
                .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            }
          }
          let lines = try contents[file, default: .success([])].get()
          guard line <= lines.count else {
            throw DocumentLinkError("Line \(line) is beyond the end of \(file.path) (\(lines.count) lines).")
          }
          // Columns count Unicode characters, with tabs counting as one; the position after the last character is
          // valid.
          if let column = link.column, column > lines[line - 1].count + 1 {
            throw DocumentLinkError("Column \(column) is beyond the end of line \(line) in \(file.path) "
              + "(maximum \(lines[line - 1].count + 1)).")
          }
        }
        return Self(link: occurrence, resolvedFile: file, symbolMatches: matches, error: nil)
      } catch {
        return Self(link: occurrence, resolvedFile: nil, symbolMatches: [], error: error.localizedDescription)
      }
    }
  }
}

private struct DocumentLinkError: LocalizedError {
  let message: String
  init(_ message: String) {
    self.message = message
  }

  var errorDescription: String? {
    message
  }
}
