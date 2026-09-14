import Foundation
@testable import SourceLinkCore
import Testing

struct SourceSymbolTests {
  @Test(arguments: [
    "Widget.swift", "cart.rb", "Cart.kt", "build.kts", "cart.ts", "View.tsx",
    "types.d.ts", "module.mts", "module.cts", "types.d.mts", "types.d.cts",
    "Widget.SWIFT", "cart.RB", "Cart.KT", "View.TSX"
  ])
  func `accepts supported symbol file extensions`(path: String) throws {
    let link = try SourceLink(#require(URL(string: "source-link://repo/\(path)?symbol=Widget")))
    #expect(link.path == path)
    #expect(link.symbol == "Widget")
    #expect(link.line == nil)
    #expect(link.column == nil)
  }

  @Test(arguments: ["file.txt", "file.js", "file.jsx", "file.py", "file", "file.ts.bak"])
  func `rejects unsupported symbol files but preserves line links`(path: String) throws {
    #expect(throws: SourceLinkError.invalidLink) {
      try SourceLink(#require(URL(string: "source-link://repo/\(path)?symbol=Widget")))
    }
    #expect(throws: SourceLinkError.invalidLink) {
      try SourceSymbolResolver.matches(in: URL(fileURLWithPath: path), named: "Widget")
    }
    let link = try SourceLink(#require(URL(string: "source-link://repo/\(path)?line=12&column=3")))
    #expect(link.line == 12)
    #expect(link.column == 3)
  }

  @Test(arguments: fixtures, ["\n", "\r\n"])
  func `resolves language specific names headers and editor positions`(fixture: Fixture, newline: String) throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appendingPathComponent(fixture.file)
    try fixture.source.replacingOccurrences(of: "\n", with: newline)
      .write(to: file, atomically: true, encoding: .utf8)
    let matches = try SourceSymbolResolver.matches(in: file, named: fixture.query)
    #expect(matches.map(\.line) == fixture.lines)
    #expect(matches.map(\.column) == Array(repeating: fixture.column, count: fixture.lines.count))
    #expect(matches.map(\.name) == Array(repeating: fixture.query, count: fixture.lines.count))
    #expect(Set(matches.map(\.id)).count == matches.count)
    #expect(matches.first?.signature == fixture.signature)
    #expect(try SourceSymbolResolver.matches(in: file, named: fixture.shortName) == matches)
    #expect(try SourceSymbolResolver.matches(in: file, named: "missing").isEmpty)

    var components = try #require(URLComponents(string: "source-link://repo/\(fixture.file)"))
    components.queryItems = [URLQueryItem(name: "symbol", value: fixture.query)]
    let link = try SourceLink(#require(components.url))
    #expect(link.symbol == fixture.query)
    var settings = SourceSettings()
    settings.defaultEditor = .vscode
    settings.checkouts = [Checkout(name: "repo", path: root.path)]
    #expect(throws: SourceLinkError.unresolvedSymbol) { try settings.command(for: link) }
    let selected = try #require(matches.last)
    let command = try #require(try settings.command(for: link, symbol: selected))
    #expect(command.arguments == ["--goto", file.resolvingSymlinksInPath().path
        + ":\(selected.line):\(selected.column)"])
  }

  @Test func `formats Ruby namespace headers without leftover separators`() throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".rb")
    try "module Shop\n  class Cart\n  end\nend".write(to: file, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: file) }
    let symbol = try #require(SourceSymbolResolver.matches(in: file, named: "Shop::Cart").first)
    #expect(symbol.signature == "Shop: class Cart")
  }

  struct Fixture: Sendable {
    let file: String
    let source: String
    let query: String
    let shortName: String
    let lines: [Int]
    let column: Int
    let signature: String
  }

  static let fixtures = [
    Fixture(file: "cart.rb", source: """
            module Shop
              class Cart
                def add(value)
                end
                def add(value, force: false)
                end
              end
            end
            """, query: "Shop::Cart#add", shortName: "add", lines: [3, 5], column: 9,
            signature: "Shop::Cart: def add(value)"),
    Fixture(file: "Cart.kt", source: """
            package shop
            class Cart {
              fun add(value: Int) {}
              fun add(value: String) {}
            }
            """, query: "shop.Cart.add", shortName: "add", lines: [3, 4], column: 7,
            signature: "shop.Cart: fun add(value: Int)"),
    Fixture(file: "cart.ts", source: """
            namespace Shop {
              export class Cart {
                add(value: number): void;
                add(value: string): void;
                add(value: number | string): void {}
              }
            }
            """, query: "Shop.Cart.add", shortName: "add", lines: [3, 4, 5], column: 5,
            signature: "Shop.Cart: add(value: number): void"),
    Fixture(file: "View.tsx", source: """
            namespace Shop {
              export function View(props: { title: string }): unknown;
              export function View(props: { title: string }) {
                return <section>{props.title}</section>;
              }
            }
            """, query: "Shop.View", shortName: "View", lines: [2, 3], column: 19,
            signature: "Shop: export function View(props: { title: string }): unknown")
  ]
}
