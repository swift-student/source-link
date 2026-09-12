import Foundation
@testable import SourceLinkCore
import Testing

struct ConfigurationTests {
  @Test func `defaults and portable paths`() throws {
    let document = try ConfigurationDocument(text: #"{"version":1}"#)
    #expect(document.settings.defaultEditor == .xcode)
    #expect(document.settings.checkouts.isEmpty)
    let home = URL(fileURLWithPath: "/Users/example")
    #expect(ConfigurationPaths.expand("~/code/a", home: home) == "/Users/example/code/a")
    #expect(ConfigurationPaths.file(environment: [:], home: home).path
      == "/Users/example/.config/source-link/config.json")
    #expect(ConfigurationPaths.file(environment: ["XDG_CONFIG_HOME": "/dotfiles"], home: home).path
      == "/dotfiles/source-link/config.json")
    #expect(ConfigurationPaths.file(environment: ["XDG_CONFIG_HOME": "relative"], home: home)
      == ConfigurationPaths.file(environment: [:], home: home))
  }

  @Test(arguments: [
    "", "{}", "[]", #"{"version":2}"#, #"{"version":true}"#, #"{"version":"1"}"#,
    #"{"version":1,"unknown":1}"#, #"{"version":1,"default_editor":"emacs"}"#,
    #"{"version":1,"executables":{"xcode":"/usr/bin/xed"}}"#,
    #"{"version":1,"executables":{"xcode":"xed"}}"#,
    #"{"version":1,"executables":{"unknown":"/bin/editor"}}"#,
    #"{"version":1,"checkouts":["bad"]}"#,
    #"{"version":1,"checkouts":[{"name":"a"}]}"#,
    #"{"version":1,"checkouts":[{"name":"","path":"/a"}]}"#,
    #"{"version":1,"checkouts":[{"name":"a","path":"relative"}]}"#,
    #"{"version":1,"checkouts":[{"name":"a","path":"/a","id":"unexpected"}]}"#,
    #"{"version":1,"checkouts":[{"name":"a","path":"/a","default":null}]}"#,
    #"{"version":1,"rules":[{"extension":"swift","editor":false}]}"#,
    #"{"version":1,"rules":[{"extension":".","editor":"xcode"}]}"#,
    #"{"version":1,"rules":[{"extension":"swift","editor":"xcode","unknown":0}]}"#,
    #"{"version":1,"executables":null}"#, #"{"version":1,"checkouts":null}"#,
    #"{"version":1,"rules":null}"#, #"{"version":1,"default_editor":null}"#,
    #"{"version":1,"checkouts":[{"name":"a","path":"/a","default":true},{"name":"A","path":"/b","default":true}]}"#,
    #"{"version":1,"executables":{"xcode":"/bin/\u0000xed"}}"#,
    #"{"version":1, broken}"#
  ])
  func `rejects invalid configuration`(_ text: String) {
    #expect(throws: ConfigurationError.self) { try ConfigurationDocument(text: text) }
  }

  @Test func `reports invalid field`() {
    do {
      _ = try ConfigurationDocument(text: #"{"version":1,"default_editor":3}"#)
      Issue.record("Expected a schema error")
    } catch {
      #expect(error.localizedDescription.contains("default_editor"))
    }
  }

  @Test func `merges separate edits and rejects conflicts`() throws {
    let base = try ConfigurationDocument(text: #"{"version":1,"default_editor":"xcode"}"#)
    var draft = base.settings
    draft.editors["zed"]?.executable = "~/bin/zed"
    let disk = try ConfigurationDocument(text: #"{"version":1,"default_editor":"cursor"}"#)
    let merged = try disk.merging(base: base.settings, draft: draft)
    #expect(merged.settings.defaultEditor == .cursor)
    #expect(merged.settings.editors["zed"]?.executable == "~/bin/zed")
    draft.defaultEditor = .zed
    #expect(throws: ConfigurationError.self) { try disk.merging(base: base.settings, draft: draft) }
  }

  @Test func `edits collections and overrides`() throws {
    var settings = SourceSettings()
    settings.checkouts = [Checkout(name: "a", path: "/a"), Checkout(name: "a", path: "/b", isDefault: true)]
    settings.editors["xcode"]?.executable = "/usr/bin/xed"
    let document = try ConfigurationDocument.initial(settings)
    var draft = document.settings
    draft.checkouts[0].isDefault = true
    draft.checkouts[1].isDefault = false
    draft.editors["xcode"] = EditorProfile.defaults["xcode"]
    draft.editors["cursor"]?.executable = "~/bin/cursor"
    let edited = try document.merging(base: document.settings, draft: draft)
    #expect(edited.settings.hasSameConfiguration(as: draft))
    draft.checkouts.removeFirst()
    draft.rules = [FileRule()]
    let removed = try edited.merging(base: edited.settings, draft: draft)
    #expect(removed.settings.hasSameConfiguration(as: draft))
    draft.checkouts.append(Checkout(name: "new", path: "~/new"))
    #expect(try removed.merging(base: removed.settings, draft: draft).settings.hasSameConfiguration(as: draft))
  }

  @Test func `concurrent collection edits conflict`() throws {
    let base = try ConfigurationDocument.initial()
    var draft = base.settings
    draft.checkouts.append(Checkout(name: "a", path: "/a"))
    var external = base.settings
    external.checkouts.append(Checkout(name: "b", path: "/b"))
    let disk = try ConfigurationDocument.initial(external)
    #expect(throws: ConfigurationError.self) { try disk.merging(base: base.settings, draft: draft) }
  }

  @Test func `round trips escapes and rule order without UII ds`() throws {
    var settings = SourceSettings()
    settings.checkouts = [Checkout(name: "a\"b\\c🐈", path: "~/code/\t\n\u{7f}")]
    var first = FileRule()
    first.editor = .cursor
    settings.rules = [first, FileRule()]
    let document = try ConfigurationDocument.initial(settings)
    #expect(document.settings.hasSameConfiguration(as: settings))
    #expect(!document.text.contains("\"id\""))
    #expect(!document.text.contains(settings.checkouts[0].id.uuidString))
    #expect(document.text.contains("\n  \"checkouts\""))
    #expect(try ConfigurationDocument.initial(document.settings).text == document.text)
  }
}
