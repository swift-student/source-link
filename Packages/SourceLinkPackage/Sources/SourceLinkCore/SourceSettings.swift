import Foundation

public struct SourceSettings: Codable, Equatable, Sendable {
  public var checkouts: [Checkout] = []
  public var defaultEditor = Editor.xcode
  public var rules: [FileRule] = []
  public var editors: [String: EditorProfile] = EditorProfile.defaults
  public var availableEditors: [Editor] {
    Editor.allCases.filter { editors[$0.rawValue] != nil }
      + editors.keys.sorted().compactMap(Editor.init(rawValue:)).filter { !Editor.allCases.contains($0) }
  }

  public func title(for editor: Editor) -> String {
    editors[editor.rawValue]?.name ?? editor.title
  }

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

  public func command(for link: SourceLink, symbol: SwiftSymbol? = nil) throws -> EditorCommand? {
    guard link.symbol == nil || symbol != nil else { throw SourceLinkError.unresolvedSymbol }
    guard let checkout = checkout(for: link.repository) else { return nil }
    let root = URL(fileURLWithPath: ConfigurationPaths.expand(checkout.path))
    let file = try link.resolve(root: root)
    let editor = editor(for: file)
    guard let profile = editors[editor.rawValue] else { throw SourceLinkError.invalidEditor }
    return EditorCommand(profile: profile,
                         file: file, line: symbol?.line ?? link.line, column: symbol?.column ?? link.column,
                         project: editor == .xcode
                           ? XcodeProjectDiscovery.project(in: root)?.resolvingSymlinksInPath() : nil)
  }
}
