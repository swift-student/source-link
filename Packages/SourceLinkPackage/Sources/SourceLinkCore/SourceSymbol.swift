internal import SourceSymbols
import Foundation

public struct SourceSymbol: Equatable, Sendable, Identifiable {
  public let name: String
  public let signature: String
  public let line: Int
  public let column: Int
  /// The source line containing a literal match; nil for declaration-only navigation.
  public let matchedLine: String?
  public var id: Int {
    offset
  }

  private let offset: Int

  init(name: String, signature: String, line: Int, column: Int, offset: Int, matchedLine: String? = nil) {
    self.name = name
    self.signature = signature
    self.line = line
    self.column = column
    self.offset = offset
    self.matchedLine = matchedLine
  }
}

/// Resolves declarations in supported source files without building or indexing their project.
public enum SourceSymbolResolver {
  public static func matches(in file: URL, named query: String, find: String? = nil) throws -> [SourceSymbol] {
    guard let language = language(for: file.path) else { throw SourceLinkError.invalidLink }
    guard find == nil || find?.isEmpty == false else { throw SourceLinkError.invalidLink }
    let contents = try String(contentsOf: file, encoding: .utf8)
    let snapshot = SourceSnapshot(text: contents, language: language)
    let result = try extractor(for: language).extract(from: snapshot)
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
    return try locations(for: matches, in: snapshot, find: find)
  }

  private static func locations(for declarations: [Declaration], in snapshot: SourceSnapshot,
                                find: String?) throws -> [SourceSymbol] {
    let positions = SourcePositionIndex(snapshot: snapshot)
    let search = find.map { LiteralSourceSearch(source: snapshot.text, snippet: $0) }
    var seen = Set<Int>()
    // Prefer the innermost matching declaration's context when ranges overlap.
    let ordered = declarations.sorted {
      if $0.declarationRange.utf8Offsets.count != $1.declarationRange.utf8Offsets.count {
        return $0.declarationRange.utf8Offsets.count < $1.declarationRange.utf8Offsets.count
      }
      return $0.identifierRange.utf8Offsets.lowerBound < $1.identifierRange.utf8Offsets.lowerBound
    }
    let matches = try ordered.flatMap { declaration -> [SourceSymbol] in
      let offsets = search?.offsets(in: declaration.declarationRange.utf8Offsets)
        ?? [declaration.identifierRange.utf8Offsets.lowerBound]
      return try offsets.compactMap { offset in
        guard seen.insert(offset).inserted else { return nil }
        guard let position = positions.position(atUTF8Offset: offset, columnEncoding: .utf16) else {
          throw ExtractionError.invalidRanges
        }
        return SourceSymbol(
          name: declaration.qualifiedCallableName ?? declaration.qualifiedName,
          signature: signature(for: declaration, in: snapshot),
          line: position.line, column: position.column, offset: offset,
          matchedLine: search?.line(at: offset)
        )
      }
    }
    if find != nil, !declarations.isEmpty, matches.isEmpty {
      throw SourceLinkError.missingText
    }
    return matches.sorted { $0.id < $1.id }
  }

  static func supports(path: String) -> Bool {
    language(for: path) != nil
  }

  private static func language(for path: String) -> SourceLanguage? {
    switch (path as NSString).pathExtension.lowercased() {
    case "swift": .swift
    case "rb": .ruby
    case "kt", "kts": .kotlin
    case "ts", "mts", "cts": .typescript
    case "tsx": .tsx
    default: nil
    }
  }

  private static func extractor(for language: SourceLanguage) -> any DeclarationExtractor {
    switch language {
    case .swift: TreeSitterSwiftExtractor()
    case .ruby: TreeSitterRubyExtractor()
    case .kotlin: TreeSitterKotlinExtractor()
    case .typescript, .tsx: TreeSitterTypeScriptExtractor()
    }
  }

  private static func signature(for declaration: Declaration, in snapshot: SourceSnapshot) -> String {
    guard let header = declaration.headerRange.flatMap({ snapshot.text(in: $0) }) else {
      return declaration.qualifiedCallableName ?? declaration.qualifiedName
    }
    let title = header.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    let prefix = declaration.qualifiedName.dropLast(declaration.name.count)
    let context = prefix.dropLast(prefix.hasSuffix("::") ? 2 : 1)
    return context.isEmpty ? title : "\(context): \(title)"
  }
}
