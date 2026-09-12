import Foundation
@testable import SourceLinkCore
import Testing

struct SourceLinkTests {
  @Test func `parses portable link`() throws {
    let link = try SourceLink(#require(URL(string: "source-link://MyRepo/Sources/My%20File.swift?line=42&column=3")))
    #expect(link.repository.lowercased() == "myrepo")
    #expect(link.path == "Sources/My File.swift")
    #expect(link.line == 42)
    #expect(link.column == 3)
  }

  @Test(arguments: [
    "source-link://repo/../secret", "source-link://repo/%2e%2e/secret",
    "source-link://repo//tmp/file", "source-link://repo/file?line=0",
    "source-link://repo/file?line=-1", "source-link://repo/file?line=1&line=2",
    "source-link://repo/file?column=2", "source-link://repo/file?line=1&column=0",
    "source-link://repo/file?line=99999999999999999999999999",
    "source-link://repo/file?unknown=1", "source-link://repo/file#fragment",
    "source-link://user@repo/file", "source-link://repo:80/file",
    "source-link://repo/", "xed:///tmp/file", "source-link://repo/a%00b"
  ])
  func `rejects invalid links`(_ value: String) throws {
    #expect(throws: (any Error).self) { try SourceLink(#require(URL(string: value))) }
  }

  @Test func `resolves files and rejects escaping symlinks`() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try Data("hello".utf8).write(to: root.appendingPathComponent("file.swift"))
    let link = try SourceLink(#require(URL(string: "source-link://repo/file.swift")))
    #expect(try link.resolve(root: root) == root.appendingPathComponent("file.swift").resolvingSymlinksInPath())
    let missing = try SourceLink(#require(URL(string: "source-link://repo/missing")))
    #expect(throws: (any Error).self) { try missing.resolve(root: root) }
    try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("escape"),
                                               withDestinationURL: root.deletingLastPathComponent())
    let escape = try SourceLink(#require(URL(string: "source-link://repo/escape/anything")))
    #expect(throws: (any Error).self) { try escape.resolve(root: root) }
  }

  @Test func `requires setup for unknown or ambiguous repositories`() {
    var settings = SourceSettings()
    #expect(settings.checkout(for: "repo") == nil)
    settings.checkouts = [Checkout(name: "Repo", path: "/one")]
    #expect(settings.checkout(for: "repo")?.path == "/one")
    settings.checkouts.append(Checkout(name: "repo", path: "/two"))
    #expect(settings.checkout(for: "repo") == nil)
    settings.checkouts[1].isDefault = true
    #expect(settings.checkout(for: "repo")?.path == "/two")
    settings.checkouts[0].isDefault = true
    #expect(settings.checkout(for: "repo") == nil)
  }

  @Test func `settings round trip and editor selection`() throws {
    var settings = SourceSettings()
    settings.defaultEditor = .vscode
    var rule = FileRule()
    rule.fileExtension = ".SWIFT"
    settings.rules = [rule]
    settings.checkouts = [Checkout(name: "repo", path: "/tmp", isDefault: true)]
    #expect(settings.editor(for: URL(fileURLWithPath: "/tmp/file.swift")) == .xcode)
    #expect(settings.editor(for: URL(fileURLWithPath: "/tmp/file.md")) == .vscode)
    #expect(try JSONDecoder().decode(SourceSettings.self, from: JSONEncoder().encode(settings)) == settings)
  }

  @Test func `editor arguments do not use shell interpolation`() {
    let file = URL(fileURLWithPath: "/tmp/a file;$(echo bad).swift")
    let xcode = EditorCommand(editor: .xcode, file: file, line: 12, column: 3)
    #expect(xcode.arguments == ["--line", "12", file.path])
    for editor in [Editor.vscode, .cursor] {
      let command = EditorCommand(editor: editor, file: file, line: 12, column: 3)
      #expect(command.arguments == ["--goto", file.path + ":12:3"])
    }
    #expect(EditorCommand(editor: .zed, file: file, line: 12, column: nil).arguments == [file.path + ":12:1"])
  }

  @Test(arguments: [nil, 42] as [Int?])
  func `xcode uses xed without forcing another workspace`(line: Int?) throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appendingPathComponent("My File.swift")
    try Data().write(to: file)
    let query = line.map { "?line=\($0)&column=3" } ?? ""
    let link = try SourceLink(#require(URL(string: "source-link://repo/My%20File.swift\(query)")))
    var settings = SourceSettings()
    settings.checkouts = [Checkout(name: "repo", path: root.path)]

    let command = try #require(try settings.command(for: link))

    #expect(command.executable == "/usr/bin/xed")
    #expect(command.arguments == (line.map { ["--line", String($0)] } ?? [])
      + [file.resolvingSymlinksInPath().path])
  }

  @Test func `rejects missing executable`() {
    let command = EditorCommand(editor: .vscode, executable: "/nonexistent/editor",
                                file: URL(fileURLWithPath: "/tmp/file"), line: nil, column: nil)
    #expect(throws: (any Error).self) { try command.run() }
  }

  @Test func `observes editor exit status`() throws {
    let file = URL(fileURLWithPath: "/tmp/file.swift")
    try EditorCommand(editor: .xcode, executable: "/usr/bin/true",
                      file: file, line: nil, column: nil).run()
    let failure = EditorCommand(editor: .xcode, executable: "/usr/bin/false",
                                file: file, line: nil, column: nil)
    #expect(throws: (any Error).self) { try failure.run() }
  }

  @Test func `resolves then routes an existing file`() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appendingPathComponent("README.md")
    try Data("hello".utf8).write(to: file)
    let link = try SourceLink(#require(URL(string: "source-link://repo/README.md?line=1&column=2")))
    var settings = SourceSettings()
    #expect(try settings.command(for: link) == nil)
    settings.checkouts = [Checkout(name: "repo", path: root.path)]
    settings.defaultEditor = .vscode
    settings.editors[Editor.vscode.rawValue]?.executable = "/custom/code"
    let command = try #require(try settings.command(for: link))
    #expect(command.executable == "/custom/code")
    #expect(command.arguments == ["--goto", file.resolvingSymlinksInPath().path + ":1:2"])
  }
}
