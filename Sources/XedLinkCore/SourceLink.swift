import Foundation

public struct SourceLink: Equatable, Sendable {
  public let repository: String
  public let path: String
  public let line: Int?
  public let column: Int?

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
    guard items.allSatisfy({ $0.name == "line" || $0.name == "column" }) else {
      throw SourceLinkError.invalidLink
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

public enum SourceLinkError: LocalizedError {
  case invalidLink, outsideRepository, missingFile, invalidEditor, launchFailed

  public var errorDescription: String? {
    switch self {
    case .invalidLink: "Invalid source link. Use a repository, relative file path, and positive line/column numbers."
    case .outsideRepository: "The requested file is outside the selected repository."
    case .missingFile: "The requested file does not exist in this checkout."
    case .invalidEditor: "The editor executable is missing. Set its executable path in Settings."
    case .launchFailed: "The editor could not open the file. Check the editor installation and selected checkout."
    }
  }
}

public struct Checkout: Codable, Identifiable, Equatable, Sendable {
  public var id = UUID()
  public var name = ""
  public var path = ""
  public var isDefault = false
  public init(name: String = "", path: String = "", isDefault: Bool = false) {
    self.name = name
    self.path = path
    self.isDefault = isDefault
  }
}

public enum Editor: String, Codable, CaseIterable, Identifiable, Sendable {
  case xcode, vscode, cursor, zed
  public var id: String { rawValue }
  public var title: String {
    switch self {
    case .xcode: "Xcode"
    case .vscode: "Visual Studio Code"
    case .cursor: "Cursor"
    case .zed: "Zed"
    }
  }
  public var defaultExecutable: String {
    switch self {
    case .xcode: "/usr/bin/xed"
    case .vscode: "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
    case .cursor: "/Applications/Cursor.app/Contents/Resources/app/bin/cursor"
    case .zed: "/Applications/Zed.app/Contents/MacOS/cli"
    }
  }
}

public struct FileRule: Codable, Identifiable, Equatable, Sendable {
  public var id = UUID()
  public var fileExtension = "swift"
  public var editor = Editor.xcode
  public init() {}
}

public struct SourceSettings: Codable, Equatable, Sendable {
  public var checkouts: [Checkout] = []
  public var defaultEditor = Editor.xcode
  public var rules: [FileRule] = []
  public var executablePaths: [String: String] = [:]
  public init() {}

  public func checkout(for name: String) -> Checkout? {
    let matches = checkouts.filter { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    if matches.count == 1 { return matches.first }
    let defaults = matches.filter(\.isDefault)
    return defaults.count == 1 ? defaults.first : nil
  }

  public func editor(for file: URL) -> Editor {
    rules.first {
      $0.fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: ". ")).lowercased()
        == file.pathExtension.lowercased()
    }?.editor ?? defaultEditor
  }

  public func command(for link: SourceLink) throws -> EditorCommand? {
    guard let checkout = checkout(for: link.repository) else { return nil }
    let file = try link.resolve(root: URL(fileURLWithPath: ConfigurationPaths.expand(checkout.path)))
    let editor = editor(for: file)
    return EditorCommand(editor: editor, executable: executablePaths[editor.rawValue],
                         file: file, line: link.line, column: link.column)
  }
}

public struct EditorCommand: Equatable, Sendable {
  public let executable: String
  public let arguments: [String]

  public init(editor: Editor, executable: String? = nil, file: URL, line: Int?, column: Int?) {
    self.executable = ConfigurationPaths.expand(
      executable.flatMap { $0.isEmpty ? nil : $0 } ?? editor.defaultExecutable
    )
    switch editor {
    case .xcode:
      arguments = (line.map { ["--line", String($0)] } ?? []) + [file.path]
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
