import Foundation
@testable import SourceLinkCore
import Testing

struct SymbolTextTests {
  @Test(arguments: ["outbox.append", " a&b#c+%?🐱 ", "%20", "\n\t", " "])
  func `preserves decoded literal query text`(snippet: String) throws {
    var url = try #require(URLComponents(string: "source-link://repo/Store.swift"))
    url.queryItems = [URLQueryItem(name: "symbol", value: "Store.commit(_:)"),
                      URLQueryItem(name: "find", value: snippet)]
    let link = try SourceLink(#require(url.url))
    #expect(link.find == snippet)
    #expect(link.symbol == "Store.commit(_:)")
    #expect(link.line == nil)
    #expect(link.column == nil)
    #expect(try SourceLink(#require(URL(string: "source-link://repo/Store.swift?symbol=Store"))).find == nil)
  }

  @Test(arguments: [
    "find=x", "find", "find=", "find=x&line=1", "symbol=run&find", "symbol=run&find=",
    "symbol=run&find=x&find=y", "symbol=run&find=x&line=1", "symbol=run&find=x&column=1"
  ])
  func `rejects invalid text anchors`(query: String) throws {
    #expect(throws: SourceLinkError.invalidLink) {
      try SourceLink(#require(URL(string: "source-link://repo/File.swift?" + query)))
    }
  }

  @Test(arguments: [0, 4])
  func `finds a statement across overloads after line insertions`(insertedLines: Int) throws {
    let prefix = String(repeating: "// inserted\n", count: insertedLines)
    let source = prefix + """
    struct Store {
      func commit(_ value: Int) {
        prepare(value)
        outbox.append(value)
      }
      func commit(_ value: String) { print(value) }
    }
    outbox.append(0)
    """
    try withSource(source) { file in
      #expect(try SourceSymbolResolver.matches(in: file, named: "Store.commit(_:)").count == 2)
      let matches = try SourceSymbolResolver.matches(in: file, named: "Store.commit(_:)", find: "outbox.append")
      let match = try #require(matches.first)
      #expect(matches.count == 1)
      #expect(match.line == 4 + insertedLines)
      #expect(match.column == 5)
      #expect(match.matchedLine == "outbox.append(value)")
      var settings = SourceSettings()
      settings.defaultEditor = .vscode
      settings.checkouts = [Checkout(name: "repo", path: file.deletingLastPathComponent().path)]
      let link = try SourceLink(#require(URL(string:
        "source-link://repo/\(file.lastPathComponent)?symbol=Store.commit(_:)&find=outbox.append")))
      let command = try #require(try settings.command(for: link, symbol: match))
      #expect(command.arguments == ["--goto", file.resolvingSymlinksInPath().path + ":\(4 + insertedLines):5"])
      try source.replacingOccurrences(of: "    outbox", with: "    // inserted inside\n    outbox")
        .write(to: file, atomically: true, encoding: .utf8)
      #expect(try SourceSymbolResolver.matches(in: file, named: "Store.commit(_:)", find: "outbox.append")
        .map(\.line) == [5 + insertedLines])
    }
  }

  @Test(arguments: [
    ("rb", "class Store\n  def commit(value); prepare(value); end\n  def commit(value); target(value); end\nend"),
    ("kt", "class Store {\n  fun commit(value: Int) {}\n  fun commit(value: String) { target(value) }\n}"),
    ("ts", "class Store {\n  commit(value: number): void;\n  commit(value: number) { target(value); }\n}"),
    ("tsx", "function commit(): unknown;\nfunction commit() { return <div>{target(value)}</div>; }")
  ])
  func `searches overloads in every supported language`(fixture: (String, String)) throws {
    try withSource(fixture.1, extension: fixture.0) { file in
      #expect(try SourceSymbolResolver.matches(in: file, named: "commit").count == 2)
      let matches = try SourceSymbolResolver.matches(in: file, named: "commit", find: "target(value)")
      #expect(matches.count == 1)
      #expect(matches.first?.line == (fixture.0 == "tsx" ? 2 : 3))
    }
  }

  @Test func `returns every occurrence in source order including repeated statements and overlaps`() throws {
    try withSource("""
    func run(_ value: Int) { target(); target() }
    func run(_ value: String) {
      target()
      // banana
    }
    """) { file in
      let matches = try SourceSymbolResolver.matches(in: file, named: "run", find: "target()")
      #expect(matches.map(\.line) == [1, 1, 3])
      #expect(matches.map(\.column) == [26, 36, 3])
      #expect(Set(matches.map(\.id)).count == 3)
      let overlaps = try SourceSymbolResolver.matches(in: file, named: "run", find: "ana")
      #expect(overlaps.map(\.line) == [4, 4])
      #expect(overlaps.map(\.column) == [7, 9])
    }
  }

  @Test func `searches headers comments strings and nested declarations and deduplicates shared ranges`() throws {
    try withSource("""
    func run() {
      // comment marker
      let value = "string marker"
      func run() { target() }
    }
    """) { file in
      #expect(try SourceSymbolResolver.matches(in: file, named: "run", find: "func run").map(\.line) == [1, 4])
      #expect(try SourceSymbolResolver.matches(in: file, named: "run", find: "comment marker").map(\.line) == [2])
      #expect(try SourceSymbolResolver.matches(in: file, named: "run", find: "string marker").map(\.line) == [3])
      let nested = try SourceSymbolResolver.matches(in: file, named: "run", find: "target()")
      #expect(nested.count == 1)
      #expect(nested.first?.line == 4)
      #expect(nested.first?.name == "run().run()")
    }
  }

  @Test func `distinguishes missing symbols and snippets without searching outside the range`() throws {
    try withSource("func run() {}\nfunc other() { target() }") { file in
      let missing = try SourceSymbolResolver.matches(in: file, named: "missing", find: "target")
      #expect(missing.isEmpty)
      for snippet in ["target", "}\nfunc other", "RUN", "r.n"] {
        #expect(throws: SourceLinkError.missingText) {
          try SourceSymbolResolver.matches(in: file, named: "run", find: snippet)
        }
      }
      #expect(throws: SourceLinkError.invalidLink) {
        try SourceSymbolResolver.matches(in: file, named: "run", find: "")
      }
    }
  }

  @Test(arguments: ["\n", "\r\n"])
  func `maps exact unicode and multiline snippets to UTF16 editor positions`(newline: String) throws {
    let source = "// before" + newline + "func run() { /* 🐱e\u{301} */ target(\"a&b#c+%?🐱\")" + newline + "}"
    try withSource(source) { file in
      let matches = try SourceSymbolResolver.matches(in: file, named: "run", find: "target(\"a&b#c+%?🐱\")")
      #expect(matches.map(\.line) == [2])
      #expect(matches.map(\.column) == [25])
      let multiline = try SourceSymbolResolver.matches(in: file, named: "run", find: newline + "}")
      #expect(multiline.count == 1)
      #expect(multiline.first?.line == 2)
      #expect(throws: SourceLinkError.missingText) {
        try SourceSymbolResolver.matches(in: file, named: "run", find: "é")
      }
      #expect(try SourceSymbolResolver.matches(in: file, named: "run", find: "e\u{301}").count == 1)
      if newline == "\r\n" {
        let startsAtLF = try SourceSymbolResolver.matches(in: file, named: "run", find: "\n}")
        #expect(startsAtLF.first?.line == 2)
        #expect(startsAtLF.first?.matchedLine == matches.first?.matchedLine)
        #expect(throws: SourceLinkError.missingText) {
          try SourceSymbolResolver.matches(in: file, named: "run", find: "🐱\")\n}")
        }
      }
    }
  }

  @Test func `uses recovered declarations when unrelated syntax is incomplete`() throws {
    try withSource("struct Store { func commit() { target(); let unfinished = } }") { file in
      let matches = try SourceSymbolResolver.matches(in: file, named: "Store.commit()", find: "target()")
      #expect(matches.count == 1)
    }
  }

  private func withSource(_ source: String, extension fileExtension: String = "swift",
                          perform: (URL) throws -> Void) throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + fileExtension)
    try source.write(to: file, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: file) }
    try perform(file)
  }
}
