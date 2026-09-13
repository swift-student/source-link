internal import SourceKittenFramework
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
    try SwiftToolchain.validate()
    let structure = try Structure(file: File(contents: contents)).dictionary
    let bytes = Array(contents.utf8)
    var result: [SwiftSymbol] = []
    collect(structure, parents: [], query: query, bytes: bytes, result: &result)
    return result.sorted { $0.id < $1.id }
  }

  private static func collect(
    _ node: [String: any SourceKitRepresentable], parents: [String], query: String,
    bytes: [UInt8], result: inout [SwiftSymbol]
  ) {
    let kind = node["key.kind"] as? String ?? ""
    let name = node["key.name"] as? String
    let isDeclaration = kind.hasPrefix("source.lang.swift.decl.")
    var scope = parents
    if isDeclaration, let name {
      let qualified = (parents + [name]).joined(separator: ".")
      let base = String(name.prefix { $0 != "(" })
      let qualifiedBase = (parents + [base]).joined(separator: ".")
      if [name, base, qualified, qualifiedBase].contains(query),
         let offset = node["key.nameoffset"] as? Int64,
         offset >= 0, offset <= bytes.count {
        let prefix = bytes.prefix(Int(offset))
        let line = prefix.filter { $0 == 10 }.count + 1
        let start = prefix.lastIndex(of: 10).map { $0 + 1 } ?? 0
        let column = (String(bytes: bytes[start ..< Int(offset)], encoding: .utf8) ?? "").utf16.count + 1
        let end = (node["key.bodyoffset"] as? Int64).map { Int($0) - 1 }
          ?? (node["key.offset"] as? Int64).flatMap { start in
            (node["key.length"] as? Int64).map { Int(start + $0) }
          } ?? Int(offset)
        let declaration = (String(
          bytes: bytes[Int(offset) ..< max(Int(offset), min(end, bytes.count))],
          encoding: .utf8
        ) ?? name)
          .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let signature = (parents + [declaration.isEmpty ? name : declaration]).joined(separator: ".")
        result.append(SwiftSymbol(
          name: qualified, signature: signature,
          line: line, column: column, offset: Int(offset)
        ))
      }
      scope.append(name)
    }
    for child in node["key.substructure"] as? [[String: any SourceKitRepresentable]] ?? [] {
      collect(child, parents: scope, query: query, bytes: bytes, result: &result)
    }
  }
}
