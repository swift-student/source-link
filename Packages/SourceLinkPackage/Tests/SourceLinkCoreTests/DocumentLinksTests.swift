import Foundation
@testable import SourceLinkCore
import Testing

struct DocumentLinksTests {
  @Test func `extracts document literals in order with locations`() throws {
    let document = """
    # References
    🦊 [one](source-link://Repo/My%20File.swift?line=2&column=3)
    [two](source-link://repo/Folder/a(b).swift "Title")
    [ref]: <SOURCE-LINK://repo/other.swift>
    link: "source-link://repo/d2.swift"
    <a href='source-link://repo/svg.swift?line=1&amp;column=2'>
    See (source-link://repo/plain.swift), then `source-link://repo/code.swift`.
    """
    let links = try DocumentLinks.extract(from: document, decodeEntities: true)
    #expect(links.map(\.text) == [
      "source-link://Repo/My%20File.swift?line=2&column=3",
      "source-link://repo/Folder/a(b).swift", "SOURCE-LINK://repo/other.swift",
      "source-link://repo/d2.swift", "source-link://repo/svg.swift?line=1&amp;column=2",
      "source-link://repo/plain.swift", "source-link://repo/code.swift"
    ])
    #expect(links[0].line == 2)
    #expect(links[0].column == 9)
    #expect(links[4].urlText == "source-link://repo/svg.swift?line=1&column=2")
    #expect(links[5].line == 7)
  }

  @Test func `preserves quoted punctuation and malformed URLs for validation`() throws {
    let links = try DocumentLinks.extract(from: """
    "source-link://repo/a)." <source-link://repo/a b.swift>
    source-link:/missing-host source-link://repo/file?line=0
    source-link://repo/bad%GG source-link://repo/../escape
    """)
    #expect(links.map(\.text) == [
      "source-link://repo/a).", "source-link://repo/a b.swift",
      "source-link:/missing-host", "source-link://repo/file?line=0",
      "source-link://repo/bad%GG", "source-link://repo/../escape"
    ])
  }

  @Test func `keeps duplicate occurrences and handles CRLF and Unicode columns`() throws {
    let links = try DocumentLinks.extract(from: "\r\n🦊 é source-link://repo/a\r\nsource-link://repo/a")
    #expect(links.count == 2)
    #expect(links[0].line == 2)
    #expect(links[0].column == 5)
    #expect(links[1].line == 3)
    #expect(links[1].column == 1)
  }

  @Test func `decodes markup entities once and preserves literal code`() throws {
    let document = """
    <a href="source-link://repo/a?line=1&#38;column=2">
    <a href="source-link://repo/a?line=1&#x26;column=2">
    <a href="source-link://repo/a&amp;amp;b">
    `source-link://repo/a&amp;b`
    """
    let links = try DocumentLinks.extract(from: document, decodeEntities: true)
    #expect(links[0].urlText == "source-link://repo/a?line=1&column=2")
    #expect(links[1].urlText == links[0].urlText)
    #expect(links[2].urlText == "source-link://repo/a&amp;b")
    #expect(links[3].urlText == "source-link://repo/a&amp;b")
    let literal = try DocumentLinks.extract(from: "source-link://repo/a&amp;b")
    #expect(literal[0].urlText == "source-link://repo/a&amp;b")
  }

  @Test func `ignores other schemes and embedded scheme names`() throws {
    let links = try DocumentLinks.extract(from: "https://example.com file:///tmp/a not-source-link://repo/a")
    #expect(links.isEmpty)
  }

  @Test func `does not repair punctuation in explicit link destinations`() throws {
    let document = """
    [invalid](source-link://repo/a?line=1!)
    [punctuation](source-link://repo/a.)
    <a href=source-link://repo/a?line=1!>
    See source-link://repo/a.
    """
    let links = try DocumentLinks.extract(from: document)
    #expect(links.map(\.text) == [
      "source-link://repo/a?line=1!", "source-link://repo/a.",
      "source-link://repo/a?line=1!", "source-link://repo/a"
    ])
  }
}
