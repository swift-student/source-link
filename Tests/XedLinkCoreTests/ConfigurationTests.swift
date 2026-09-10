import Foundation
import Testing
@testable import XedLinkCore

@Suite struct ConfigurationTests {
  @Test func defaultsAndPortablePaths() throws {
    let document = try ConfigurationDocument(text: "version = 1\n")
    #expect(document.settings.defaultEditor == .xcode)
    #expect(document.settings.checkouts.isEmpty)
    let home = URL(fileURLWithPath: "/Users/example")
    #expect(ConfigurationPaths.expand("~/code/a", home: home) == "/Users/example/code/a")
    #expect(ConfigurationPaths.file(environment: [:], home: home).path
      == "/Users/example/.config/source-link/config.toml")
    #expect(ConfigurationPaths.file(environment: ["XDG_CONFIG_HOME": "/dotfiles"], home: home).path
      == "/dotfiles/source-link/config.toml")
    #expect(ConfigurationPaths.file(environment: ["XDG_CONFIG_HOME": "relative"], home: home)
      == ConfigurationPaths.file(environment: [:], home: home))
  }

  @Test(arguments: [
    "", "version = 2", "version = true", "version = '1'", "version = 1\nunknown = 1",
    "version = 1\ndefault_editor = 'emacs'", "version = 1\n[executables]\nxcode = 'xed'",
    "version = 1\n[executables]\nunknown = '/bin/editor'", "version = 1\ncheckouts = ['bad']",
    "version = 1\n[[checkouts]]\nname = 'a'", "version = 1\n[[checkouts]]\nname = ''\npath = '/a'",
    "version = 1\n[[checkouts]]\nname = 'a'\npath = 'relative'",
    "version = 1\n[[rules]]\nextension = 'swift'\neditor = false",
    "version = 1\n[[rules]]\nextension = '.'\neditor = 'xcode'",
    "version = 1\nversion = 1", "version = 1\n[broken",
    "version = 1\n[[checkouts]]\nname='a'\npath='/a'\ndefault=true\n"
      + "[[checkouts]]\nname='A'\npath='/b'\ndefault=true"
  ])
  func rejectsInvalidConfiguration(_ text: String) {
    #expect(throws: ConfigurationError.self) { try ConfigurationDocument(text: text) }
  }

  @Test func acceptsTOMLSyntaxAndReportsLocations() throws {
    let text = #"""
    version = 0x1
    default_editor = 'cursor'
    executables = { xcode = '/usr/bin/xed' }
    checkouts = [{ name = "répo", path = """~/code/
    rêpo""" }]
    rules = [{ extension = 'swift', editor = 'xcode' }]
    """#
    let document = try ConfigurationDocument(text: text)
    #expect(document.settings.checkouts.first?.path == "~/code/\nrêpo")
    #expect(document.settings.rules.first?.editor == .xcode)
    do {
      _ = try ConfigurationDocument(text: "version = 1\ndefault_editor = 3")
      Issue.record("Expected a schema error")
    } catch {
      #expect(error.localizedDescription.contains("line 2"))
      #expect(error.localizedDescription.contains("default_editor"))
    }
  }

  @Test func editsOnlyValuesIncludingUnicodeAndMultilineStrings() throws {
    let text = #"""
    # Personal settings 🐈
    version = 1
    default_editor = 'cursor' # keep this
    [executables]
    xcode = '/usr/bin/xed'
    [[checkouts]] # favorite
    name = "répo🐈" # name
    path = """~/old
    path""" # keep path comment

    """#
    let document = try ConfigurationDocument(text: text)
    var draft = document.settings
    draft.defaultEditor = .zed
    draft.checkouts[0].path = "~/new"
    let edited = try document.merging(base: document.settings, draft: draft)
    #expect(edited.text == text.replacingOccurrences(of: "'cursor'", with: "\"zed\"")
      .replacingOccurrences(of: "\"\"\"~/old\npath\"\"\"", with: "\"~/new\""))
    #expect(edited.settings.hasSameConfiguration(as: draft))
  }

  @Test func mergesSeparateEditsAndRejectsConflicts() throws {
    let base = try ConfigurationDocument(text: "version=1\ndefault_editor='xcode'\n")
    var draft = base.settings
    draft.executablePaths["zed"] = "~/bin/zed"
    let disk = try ConfigurationDocument(text: "# agent\nversion=1\ndefault_editor='cursor'\n")
    let merged = try disk.merging(base: base.settings, draft: draft)
    #expect(merged.settings.defaultEditor == .cursor)
    #expect(merged.settings.executablePaths["zed"] == "~/bin/zed")
    #expect(merged.text.contains("# agent"))
    draft.defaultEditor = .zed
    #expect(throws: ConfigurationError.self) { try disk.merging(base: base.settings, draft: draft) }
  }

  @Test func insertsOptionalKeysAndRemovesOverrides() throws {
    for source in [
      "version=1\n[executables] # comment\nxcode='/usr/bin/xed' # path\n",
      "version=1\nexecutables = {xcode='/usr/bin/xed'}\n",
      "version=1\nexecutables.xcode='/usr/bin/xed' # dotted\n"
    ] {
      let document = try ConfigurationDocument(text: source)
      var draft = document.settings
      draft.executablePaths["cursor"] = "~/bin/cursor"
      draft.executablePaths["xcode"] = nil
      draft.defaultEditor = .cursor
      let edited = try document.merging(base: document.settings, draft: draft)
      #expect(edited.settings.hasSameConfiguration(as: draft))
    }
  }

  @Test func editsArraysAndPreservesComments() throws {
    for source in [
      "version=1\n[[checkouts]] # first\nname='one'\npath='/one' # path\n"
        + "[executables]\nxcode='/usr/bin/xed'\n[[checkouts]]\nname='two'\npath='/two'\n",
      "version=1\ncheckouts=[ # first\n{name='one',path='/one'}, # path\n{name='two',path='/two'}]\n"
        + "[executables]\nxcode='/usr/bin/xed'\n"
    ] {
      let document = try ConfigurationDocument(text: source)
      var draft = document.settings
      draft.checkouts.removeFirst()
      let edited = try document.merging(base: document.settings, draft: draft)
      #expect(edited.settings.hasSameConfiguration(as: draft))
      #expect(edited.text.contains("# first"))
      #expect(edited.text.contains("# path"))
      #expect(edited.text.contains("xcode='/usr/bin/xed'"))
      draft.checkouts.append(Checkout(name: "three", path: "~/three"))
      let added = try edited.merging(base: edited.settings, draft: draft)
      #expect(added.settings.hasSameConfiguration(as: draft))
      draft.checkouts = []
      #expect(try added.merging(base: added.settings, draft: draft).settings.checkouts.isEmpty)
    }
  }

  @Test func canSwitchDefaultWithoutRejectingIntermediateState() throws {
    let source = "version=1\n[[checkouts]]\nname='a'\npath='/a'\ndefault=false\n"
      + "[[checkouts]]\nname='a'\npath='/b'\ndefault=true\n"
    let document = try ConfigurationDocument(text: source)
    var draft = document.settings
    draft.checkouts[0].isDefault = true
    draft.checkouts[1].isDefault = false
    #expect(try document.merging(base: document.settings, draft: draft).settings.hasSameConfiguration(as: draft))
  }

  @Test func roundTripsEscapesWithoutUIIDs() throws {
    var settings = SourceSettings()
    settings.checkouts = [Checkout(name: "a\"b\\c🐈", path: "~/code/\t\n\u{7f}")]
    let document = try ConfigurationDocument.initial(settings)
    #expect(document.settings.hasSameConfiguration(as: settings))
    #expect(!document.text.contains("id ="))
  }
}
