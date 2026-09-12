import Foundation
import SourceLinkCore
import Testing

struct FirstLinkSetupTests {
  @Test(arguments: ["swift", ".SWIFT", " .Swift. "])
  func `extension spelling shares routing and setup identity`(_ spelling: String) throws {
    var settings = SourceSettings()
    var rule = FileRule()
    rule.fileExtension = spelling
    settings.rules = [rule, FileRule()]
    #expect(rule.normalizedExtension == "swift")
    #expect(settings.editor(for: URL(fileURLWithPath: "/repo/File.SWIFT")) == .xcode)
    let link = try SourceLink(#require(URL(string: "source-link://repo/File.SWIFT")))
    settings.configure(link, root: URL(fileURLWithPath: "/repo"), editor: .cursor)
    #expect(settings.rules.count == 1)
    #expect(settings.rules.first?.fileExtension == "swift")
    #expect(settings.editor(for: URL(fileURLWithPath: "/repo/File.swift")) == .cursor)
  }

  @Test func `setup reuses a checkout and preserves unrelated settings`() throws {
    var settings = SourceSettings()
    settings.checkouts = [
      Checkout(name: "Repo", path: "/main", isDefault: true),
      Checkout(name: "Repo", path: "/worktree"),
      Checkout(name: "other", path: "/other", isDefault: true)
    ]
    let original = settings.checkouts
    var unrelated = FileRule()
    unrelated.fileExtension = "md"
    settings.rules = [unrelated]
    settings.executablePaths["cursor"] = "/custom/cursor"
    let link = try SourceLink(#require(URL(string: "source-link://REPO/File.swift")))
    settings.configure(link, root: URL(fileURLWithPath: "/worktree"), editor: .cursor)
    #expect(settings.checkouts.map(\.id) == original.map(\.id))
    #expect(settings.checkouts.map(\.name) == original.map(\.name))
    #expect(settings.checkouts.map(\.isDefault) == [false, true, true])
    #expect(settings.rules.last == unrelated)
    #expect(settings.executablePaths["cursor"] == "/custom/cursor")
    #expect(settings.defaultEditor == .xcode)
  }

  @Test func `extensionless setup adds a checkout and changes the fallback editor`() throws {
    var settings = SourceSettings()
    settings.rules = [FileRule()]
    let rules = settings.rules
    let link = try SourceLink(#require(URL(string: "source-link://repo/Makefile")))
    settings.configure(link, root: URL(fileURLWithPath: "/feature"), editor: .zed)
    #expect(settings.checkout(for: "repo")?.path == "/feature")
    #expect(settings.checkout(for: "repo")?.isDefault == true)
    #expect(settings.defaultEditor == .zed)
    #expect(settings.rules == rules)
  }
}
