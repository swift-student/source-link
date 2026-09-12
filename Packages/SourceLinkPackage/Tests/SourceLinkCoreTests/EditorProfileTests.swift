import Foundation
@testable import SourceLinkCore
import Testing

struct EditorProfileTests {
  private let custom = """
  {"version":1,"default_editor":"custom","editors":{"custom":{
    "name":"My Editor","executable":"/custom/editor","arguments":["{file}"],
    "line_arguments":["+{line}","{file}"],
    "column_arguments":["+{line}:{column}","{file}"]}}}
  """

  @Test func `routes custom editor without reinterpreting file contents`() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appendingPathComponent("a {line};$(echo bad).txt")
    try Data().write(to: file)
    var settings = try ConfigurationDocument(text: custom).settings
    settings.checkouts = [Checkout(name: "repo", path: root.path)]
    var url = URLComponents()
    url.scheme = "source-link"
    url.host = "repo"
    url.path = "/" + file.lastPathComponent
    url.queryItems = [URLQueryItem(name: "line", value: "9"), URLQueryItem(name: "column", value: "4")]
    let link = try SourceLink(#require(url.url))
    let command = try #require(try settings.command(for: link))
    #expect(command.executable == "/custom/editor")
    #expect(command.arguments == ["+9:4", file.resolvingSymlinksInPath().path])
    #expect(settings.availableEditors.contains(settings.defaultEditor))
    #expect(settings.title(for: settings.defaultEditor) == "My Editor")
    #expect(try ConfigurationDocument.initial(settings).settings.hasSameConfiguration(as: settings))
  }

  @Test func `position fallback and executable override`() throws {
    let settings = try ConfigurationDocument(text: custom).settings
    var profile = try #require(settings.editors["custom"])
    let file = URL(fileURLWithPath: "/tmp/file")
    #expect(EditorCommand(profile: profile, file: file, line: nil, column: nil).arguments == [file.path])
    #expect(EditorCommand(profile: profile, file: file, line: 9, column: nil).arguments == ["+9", file.path])
    profile.columnArguments = nil
    #expect(EditorCommand(profile: profile, file: file, line: 9, column: 4).arguments == ["+9", file.path])
    profile.lineArguments = nil
    #expect(EditorCommand(profile: profile, file: file, line: 9, column: 4).arguments == [file.path])
    #expect(EditorCommand(profile: profile, executable: "/override", file: file, line: nil, column: nil).executable
      == "/override")
  }

  @Test(arguments: [
    #""arguments":["{file}","{unknown}"]"#, #""arguments":["{file}","{line}"]"#,
    #""arguments":[]"#, #""arguments":["{file}"],"line_arguments":["--line"]"#,
    #""arguments":["{file}"],"unexpected":true"#, #""arguments":["{file}\u0000"]"#
  ])
  func `rejects invalid profiles`(_ fields: String) {
    let text = """
    {"version":1,"editors":{"custom":{"name":"Custom","executable":"/bin/editor",\(fields)}}}
    """
    #expect(throws: ConfigurationError.self) { try ConfigurationDocument(text: text) }
  }

  @Test func `merges independent profiles and detects same profile conflict`() throws {
    let base = try ConfigurationDocument(text: custom).settings
    var draft = base
    draft.editors["custom"]?.arguments = ["--new-window", "{file}"]
    var disk = base
    disk.editors["idea"]?.executable = "/other/idea"
    let merged = try ConfigurationDocument.initial(disk).merging(base: base, draft: draft)
    #expect(merged.settings.editors["custom"] == draft.editors["custom"])
    #expect(merged.settings.editors["idea"] == disk.editors["idea"])
    disk.editors["custom"]?.arguments = ["--reuse", "{file}"]
    #expect(throws: ConfigurationError.self) {
      try ConfigurationDocument.initial(disk).merging(base: base, draft: draft)
    }
    draft.editors.removeValue(forKey: "custom")
    #expect(throws: ConfigurationError.self) { try ConfigurationDocument.initial(draft) }
  }
}
