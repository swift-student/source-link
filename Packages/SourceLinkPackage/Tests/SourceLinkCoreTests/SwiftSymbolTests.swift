import Foundation
@testable import SourceLinkCore
import Testing

struct SwiftSymbolTests {
  @Test func `parses symbol links`() throws {
    let link = try SourceLink(#require(URL(string: "source-link://repo/Widget.swift?symbol=Widget.refresh(force:)")))
    #expect(link.symbol == "Widget.refresh(force:)")
    #expect(link.line == nil)
  }

  @Test(arguments: [
    "file.swift?symbol", "file.swift?symbol=", "file.swift?symbol=%20",
    "file.swift?symbol=a&symbol=b", "file.swift?symbol=a&line=1",
    "file.swift?symbol=a&column=1", "file.txt?symbol=a", "file.swift?symbol=a%00b"
  ])
  func `rejects invalid symbol links`(_ suffix: String) throws {
    #expect(throws: SourceLinkError.self) {
      try SourceLink(#require(URL(string: "source-link://repo/" + suffix)))
    }
  }

  @Test func `resolves qualified names overloads extensions and unicode`() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appendingPathComponent("Widget.swift")
    let source = """
    struct Widget {
      var title: String
      func refresh(force: Bool) {}
      func refresh(force: Int) {}
      struct Nested { func go() {} }
    }
    extension Widget {
      func refresh() {}
    }
    struct Other { func refresh() {} }
    /* 🐱 */ struct Café {}
    // func missing() {}
    """
    try source.write(to: file, atomically: true, encoding: .utf8)
    let overloads = try SwiftSymbolResolver.matches(in: file, named: "Widget.refresh(force:)")
    #expect(overloads.map(\.line) == [3, 4])
    #expect(Set(overloads.map(\.signature)).count == 2)
    #expect(try SwiftSymbolResolver.matches(in: file, named: "refresh").map(\.line) == [3, 4, 8, 10])
    #expect(try SwiftSymbolResolver.matches(in: file, named: "Widget.refresh()").map(\.line) == [8])
    #expect(try SwiftSymbolResolver.matches(in: file, named: "Widget.Nested.go()").map(\.line) == [5])
    #expect(try SwiftSymbolResolver.matches(in: file, named: "Widget.title").map(\.line) == [2])
    #expect(try SwiftSymbolResolver.matches(in: file, named: "missing").isEmpty)
    let unicode = try #require(SwiftSymbolResolver.matches(in: file, named: "Café").first)
    #expect(unicode.line == 11)
    #expect(unicode.column == 17)

    var settings = SourceSettings()
    settings.defaultEditor = .vscode
    settings.checkouts = [Checkout(name: "repo", path: root.path)]
    let link = try SourceLink(#require(URL(string: "source-link://repo/Widget.swift?symbol=Widget.refresh(force:)")))
    #expect(throws: SourceLinkError.self) { try settings.command(for: link) }
    let command = try #require(try settings.command(for: link, symbol: overloads.first))
    #expect(command.arguments == ["--goto", file.resolvingSymlinksInPath().path + ":3:8"])
  }
}
