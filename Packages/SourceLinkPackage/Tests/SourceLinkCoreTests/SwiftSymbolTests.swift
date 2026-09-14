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

  @Test(arguments: ["\n", "\r\n"])
  func `resolves qualified names overloads extensions and unicode`(newline: String) throws {
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
    try source.replacingOccurrences(of: "\n", with: newline).write(to: file, atomically: true, encoding: .utf8)
    let overloads = try SwiftSymbolResolver.matches(in: file, named: "Widget.refresh(force:)")
    #expect(overloads.map(\.line) == [3, 4])
    #expect(overloads.map(\.signature) == ["Widget: func refresh(force: Bool)", "Widget: func refresh(force: Int)"])
    #expect(try SwiftSymbolResolver.matches(in: file, named: "Widget").map(\.line) == [1, 7])
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

  @Test func `matches enum cases and labeled enclosing callables`() throws {
    try withSource("""
    enum Event {
      case ready, payload(value: Int)
      case payload(text: String)
    }
    struct Host {
      func outer(value: Int) { func inner() {}; let local = value }
      func outer(text: String) { func inner() {} }
      func outer(value: String) { func inner() {} }
    }
    """) { file in
      let payload = try SwiftSymbolResolver.matches(in: file, named: "Event.payload(value:)")
      #expect(payload.map(\.name) == ["Event.payload(value:)"])
      #expect(payload.map(\.line) == [2])
      #expect(try SwiftSymbolResolver.matches(in: file, named: "payload").map(\.line) == [2, 3])
      #expect(try SwiftSymbolResolver.matches(in: file, named: "Event.ready()").isEmpty)
      #expect(try SwiftSymbolResolver.matches(in: file, named: "Host.outer(value:).inner()").map(\.line) == [6, 8])
      #expect(try SwiftSymbolResolver.matches(in: file, named: "Host.outer(text:).inner").map(\.line) == [7])
      #expect(try SwiftSymbolResolver.matches(in: file, named: "inner()").map(\.line) == [6, 7, 8])
      #expect(try SwiftSymbolResolver.matches(in: file, named: "Host.outer(value:).local").count == 1)
      #expect(try SwiftSymbolResolver.matches(in: file, named: "value").isEmpty)
      #expect(try SwiftSymbolResolver.matches(in: file, named: "Host.outer(value:).value").isEmpty)
    }
  }

  @Test func `picker headers preserve syntax without callable bodies`() throws {
    try withSource("""
    struct Store {
      @available(*, deprecated)
      public func transform<T>(
        _ value: T, using callback: (T) -> String = { _ in "{}" }
      ) async throws -> String where T: Equatable { fatalError("body") }
      init?(value: Int) {}
      subscript(index: Int) -> Int { index }
      var computed: Int { 42 }
    }
    """) { file in
      let function = try #require(SwiftSymbolResolver.matches(in: file, named: "Store.transform(_:using:)").first)
      #expect(function.signature == "Store: @available(*, deprecated) public func transform<T>( "
        + "_ value: T, using callback: (T) -> String = { _ in \"{}\" } "
        + ") async throws -> String where T: Equatable")
      #expect(function.line == 3)
      let initializer = try #require(SwiftSymbolResolver.matches(in: file, named: "Store.init(value:)").first)
      #expect(initializer.signature == "Store: init?(value: Int)")
      let subscriptSymbol = try #require(SwiftSymbolResolver.matches(in: file, named: "Store.subscript(_:)").first)
      #expect(subscriptSymbol.signature == "Store: subscript(index: Int) -> Int")
      let property = try #require(SwiftSymbolResolver.matches(in: file, named: "Store.computed").first)
      #expect(property.signature == "Store: var computed: Int")
    }
  }

  @Test func `recovered and noncontiguous headers fall back to qualified names`() throws {
    try withSource("""
    struct Host {
      var first = 0 { didSet {} }, second = 1
      func broken(value: ) {}
      func sound(value: Int) { let unfinished = }
    }
    """) { file in
      let first = try #require(SwiftSymbolResolver.matches(in: file, named: "Host.first").first)
      #expect(first.signature == "Host.first")
      let second = try #require(SwiftSymbolResolver.matches(in: file, named: "Host.second").first)
      #expect(second.signature == "Host.second")
      let broken = try #require(SwiftSymbolResolver.matches(in: file, named: "Host.broken").first)
      #expect(broken.signature == "Host.broken")
      #expect(try SwiftSymbolResolver.matches(in: file, named: "Host.broken(value:)").isEmpty)
      let sound = try #require(SwiftSymbolResolver.matches(in: file, named: "Host.sound(value:)").first)
      #expect(sound.signature == "Host: func sound(value: Int)")
    }
  }

  @Test func `operator and top level names match once in source order`() throws {
    try withSource("""
    struct First { static func + (lhs: First, rhs: First) -> First { lhs } }
    struct Second { static func + (lhs: Second, rhs: Second) -> Second { lhs } }
    func top() {}
    """) { file in
      let operators = try SwiftSymbolResolver.matches(in: file, named: "+(_:_:)")
      #expect(operators.map(\.line) == [1, 2])
      #expect(try SwiftSymbolResolver.matches(in: file, named: "First.+(_:_:)").map(\.line) == [1])
      #expect(try SwiftSymbolResolver.matches(in: file, named: "top()").map(\.line) == [3])
      #expect(try SwiftSymbolResolver.matches(in: file, named: "top").map(\.line) == [3])
    }
  }

  private func withSource(_ source: String, perform: (URL) throws -> Void) throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".swift")
    try source.write(to: file, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: file) }
    try perform(file)
  }
}
