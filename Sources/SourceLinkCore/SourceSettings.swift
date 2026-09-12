import Foundation

public struct SourceSettings: Codable, Equatable, Sendable {
  public var checkouts: [Checkout] = []
  public var defaultEditor = Editor.xcode
  public var rules: [FileRule] = []
  public var executablePaths: [String: String] = [:]
  public init() {}

  public func checkout(for name: String) -> Checkout? {
    let matches = checkouts(for: name)
    if matches.count == 1 {
      return matches.first
    }
    let defaults = matches.filter(\.isDefault)
    return defaults.count == 1 ? defaults.first : nil
  }

  public func editor(for file: URL) -> Editor {
    rules.first {
      $0.normalizedExtension
        == file.pathExtension.lowercased()
    }?.editor ?? defaultEditor
  }

  public func command(for link: SourceLink) throws -> EditorCommand? {
    guard let checkout = checkout(for: link.repository) else { return nil }
    let root = URL(fileURLWithPath: ConfigurationPaths.expand(checkout.path))
    let file = try link.resolve(root: root)
    let editor = editor(for: file)
    return EditorCommand(editor: editor, executable: executablePaths[editor.rawValue],
                         file: file, line: link.line, column: link.column,
                         project: editor == .xcode
                           ? XcodeProjectDiscovery.project(in: root)?.resolvingSymlinksInPath() : nil)
  }
}
