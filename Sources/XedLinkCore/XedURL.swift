import Foundation

public struct XedURL: Equatable, Sendable {
  public let fileURL: URL
  public let line: Int?
  public let projectURL: URL?

  public init(_ url: URL) throws {
    guard
      let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
      components.scheme?.lowercased() == "xed"
    else {
      throw XedURLError.invalidScheme
    }

    guard
      (components.host ?? "").isEmpty,
      components.user == nil,
      components.password == nil,
      components.port == nil,
      components.fragment == nil
    else {
      throw XedURLError.unsupportedURLComponent
    }

    guard components.path.hasPrefix("/"), components.path != "/" else {
      throw XedURLError.invalidPath
    }

    let queryItems = components.queryItems ?? []
    guard queryItems.allSatisfy({ $0.name == "line" || $0.name == "project" }) else {
      throw XedURLError.unsupportedURLComponent
    }

    self.fileURL = URL(fileURLWithPath: components.path).standardizedFileURL
    self.line = try Self.line(in: queryItems)
    self.projectURL = try Self.projectURL(in: queryItems)
  }

  public var xedArguments: [String] {
    var arguments: [String] = []
    if let projectURL {
      arguments += ["--project", projectURL.path]
    }
    if let line {
      arguments += ["--line", String(line)]
    }
    arguments.append(fileURL.path)
    return arguments
  }

  public func openInXcode() throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/xed")
    process.arguments = xedArguments
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
  }

  private static func line(in queryItems: [URLQueryItem]) throws -> Int? {
    guard let item = try queryItem(named: "line", in: queryItems) else {
      return nil
    }
    guard let value = item.value, let line = Int(value), line > 0 else {
      throw XedURLError.invalidLine
    }
    return line
  }

  private static func projectURL(in queryItems: [URLQueryItem]) throws -> URL? {
    guard let item = try queryItem(named: "project", in: queryItems) else {
      return nil
    }
    guard let value = item.value, value.hasPrefix("/"), value != "/" else {
      throw XedURLError.invalidProject
    }
    return URL(fileURLWithPath: value).standardizedFileURL
  }

  private static func queryItem(
    named name: String,
    in queryItems: [URLQueryItem]
  ) throws -> URLQueryItem? {
    let matches = queryItems.filter { $0.name == name }
    guard matches.count <= 1 else {
      throw XedURLError.unsupportedURLComponent
    }
    return matches.first
  }
}

public enum XedURLError: Error, Equatable, LocalizedError {
  case invalidScheme
  case unsupportedURLComponent
  case invalidPath
  case invalidLine
  case invalidProject

  public var errorDescription: String? {
    switch self {
    case .invalidScheme:
      "The URL must use the xed scheme."
    case .unsupportedURLComponent:
      "The URL contains unsupported components."
    case .invalidPath:
      "The URL must contain an absolute file path."
    case .invalidLine:
      "The line number must be a positive integer."
    case .invalidProject:
      "The project must be an absolute path."
    }
  }
}
