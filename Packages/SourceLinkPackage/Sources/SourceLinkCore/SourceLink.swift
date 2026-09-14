import Foundation

public struct SourceLink: Equatable, Sendable {
  public let repository: String
  public let path: String
  public let line: Int?
  public let column: Int?
  public let symbol: String?

  public init(_ url: URL) throws {
    guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
          parts.scheme?.lowercased() == "source-link",
          let host = parts.host, !host.isEmpty,
          parts.user == nil, parts.password == nil, parts.port == nil, parts.fragment == nil
    else { throw SourceLinkError.invalidLink }
    let path = String(parts.path.dropFirst())
    guard parts.path.hasPrefix("/"), !path.isEmpty,
          !path.hasPrefix("/"), !path.contains("\0"),
          !path.split(separator: "/", omittingEmptySubsequences: false).contains(where: {
            $0 == ".." || $0 == "." || $0.isEmpty
          })
    else { throw SourceLinkError.invalidLink }
    let items = parts.queryItems ?? []
    guard items.allSatisfy({ $0.name == "line" || $0.name == "column" || $0.name == "symbol" }) else {
      throw SourceLinkError.invalidLink
    }
    let symbols = items.filter { $0.name == "symbol" }
    if let item = symbols.first {
      guard symbols.count == 1, let value = item.value,
            !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
            path.hasSuffix(".swift"),
            !items.contains(where: { $0.name == "line" || $0.name == "column" })
      else { throw SourceLinkError.invalidLink }
      symbol = value
    } else {
      symbol = nil
    }
    repository = host
    self.path = path
    line = try Self.position("line", in: items)
    column = try Self.position("column", in: items)
    guard column == nil || line != nil else { throw SourceLinkError.invalidLink }
  }

  private static func position(_ name: String, in items: [URLQueryItem]) throws -> Int? {
    let matches = items.filter { $0.name == name }
    guard !matches.isEmpty else { return nil }
    guard matches.count == 1, let text = matches[0].value,
          !text.isEmpty, text.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }),
          let value = Int(text), value > 0
    else { throw SourceLinkError.invalidLink }
    return value
  }

  public func resolve(root: URL) throws -> URL {
    let base = root.standardizedFileURL.resolvingSymlinksInPath()
    let file = base.appendingPathComponent(path).standardizedFileURL.resolvingSymlinksInPath()
    guard file.path.hasPrefix(base.path.hasSuffix("/") ? base.path : base.path + "/"),
          file.path != base.path else { throw SourceLinkError.outsideRepository }
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: file.path, isDirectory: &isDirectory),
          !isDirectory.boolValue else { throw SourceLinkError.missingFile }
    return file
  }
}
