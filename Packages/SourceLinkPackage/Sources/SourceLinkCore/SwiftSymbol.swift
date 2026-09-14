internal import SourceSymbols
import Foundation

public struct SwiftSymbol: Equatable, Sendable, Identifiable {
  public let name: String
  public let signature: String
  public let line: Int
  public let column: Int
  public var id: Int {
    offset
  }

  private let offset: Int

  init(name: String, signature: String, line: Int, column: Int, offset: Int) {
    self.name = name
    self.signature = signature
    self.line = line
    self.column = column
    self.offset = offset
  }
}

/// Resolves declarations written in a Swift file without building or indexing its project.
public enum SwiftSymbolResolver {
  public static func matches(in file: URL, named query: String) throws -> [SwiftSymbol] {
    let contents = try String(contentsOf: file, encoding: .utf8)
    let snapshot = SourceSnapshot(text: contents, language: .swift)
    let result = try TreeSitterSwiftExtractor().extract(from: snapshot)
    // Navigation uses recovered declarations even when unrelated syntax has diagnostics.
    // Try both spellings: dots can also belong to an operator's short name.
    let names: [DeclarationQuery.Name] = [.short(query), .qualified(query)]
    let matches = names.flatMap { name -> [Declaration] in
      switch DeclarationMatcher.match(DeclarationQuery(name: name), in: result.declarations) {
      case .missing: []
      case let .unique(declaration): [declaration]
      case let .ambiguous(declarations): declarations
      }
    }
    let positions = SourcePositionIndex(snapshot: snapshot)
    var seen = Set<Int>()
    return try matches.sorted {
      $0.identifierRange.utf8Offsets.lowerBound < $1.identifierRange.utf8Offsets.lowerBound
    }.compactMap { declaration in
      let offset = declaration.identifierRange.utf8Offsets.lowerBound
      guard seen.insert(offset).inserted else { return nil }
      guard let position = positions.position(in: declaration.identifierRange, columnEncoding: .utf16) else {
        throw ExtractionError.invalidRanges
      }
      return SwiftSymbol(
        name: declaration.qualifiedCallableName ?? declaration.qualifiedName,
        signature: signature(for: declaration, in: snapshot),
        line: position.line, column: position.column, offset: offset
      )
    }
  }

  private static func signature(for declaration: Declaration, in snapshot: SourceSnapshot) -> String {
    guard let header = declaration.headerRange.flatMap({ snapshot.text(in: $0) }) else {
      return declaration.qualifiedCallableName ?? declaration.qualifiedName
    }
    let title = header.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    let context = declaration.qualifiedName.dropLast(declaration.name.count).dropLast()
    return context.isEmpty ? title : "\(context): \(title)"
  }
}
