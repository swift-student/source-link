import Foundation
@testable import SourceLinkCore
import Testing

struct DocumentLinkValidationTests {
  private func withCheckout(_ body: (URL, SourceSettings) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try Data("abc\r\n🦊é\n".utf8).write(to: root.appendingPathComponent("file.swift"))
    var settings = SourceSettings()
    settings.checkouts = [Checkout(name: "Repo", path: root.path)]
    settings.editors["xcode"]?.executable = "/nonexistent/editor"
    try body(root, settings)
  }

  @Test func `validates positions with empty last line and end of line caret`() throws {
    try withCheckout { _, settings in
      let links = try DocumentLinks.extract(from: """
      source-link://repo/file.swift
      source-link://REPO/file.swift?line=1&column=4
      source-link://repo/file.swift?line=2&column=3
      source-link://repo/file.swift?line=3&column=1
      """)
      #expect(DocumentLinkValidation.validate(links, settings: settings).allSatisfy { $0.error == nil })
    }
  }

  @Test func `reports all bad links without stopping after a failure`() throws {
    try withCheckout { root, settings in
      let outside = root.deletingLastPathComponent().appendingPathComponent(UUID().uuidString)
      try Data("outside".utf8).write(to: outside)
      defer { try? FileManager.default.removeItem(at: outside) }
      try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("escape"),
                                                 withDestinationURL: outside)
      let links = try DocumentLinks.extract(from: """
      source-link://repo/file.swift?line=0
      source-link://repo/file.swift?line=4
      source-link://repo/file.swift?line=2&column=4
      source-link://repo/missing.swift
      source-link://unknown/file.swift
      source-link://repo/escape
      source-link://repo/../outside
      source-link://repo/bad%GG
      <source-link://repo/a b.swift>
      source-link://repo/file.swift
      """)
      let results = DocumentLinkValidation.validate(links, settings: settings)
      #expect(results.count == 10)
      #expect(results.dropLast().allSatisfy { $0.error != nil })
      #expect(results[1].error?.contains("Line 4") == true)
      #expect(results[2].error?.contains("Column 4") == true)
      #expect(results[4].error?.contains("not configured") == true)
      #expect(results[5].error == SourceLinkError.outsideRepository.localizedDescription)
      #expect(results[9].error == nil)
    }
  }

  @Test func `uses selected checkout and reports ambiguity without prompting`() throws {
    try withCheckout { _, original in
      var settings = original
      settings.checkouts.append(Checkout(name: "repo", path: "/nonexistent"))
      let links = try DocumentLinks.extract(from: "source-link://repo/file.swift")
      #expect(DocumentLinkValidation.validate(links, settings: settings)[0].error?.contains("default checkout") == true)
      settings.checkouts[0].isDefault = true
      #expect(DocumentLinkValidation.validate(links, settings: settings)[0].error == nil)
      settings.checkouts[0].isDefault = false
      settings.checkouts[1].isDefault = true
      #expect(DocumentLinkValidation.validate(links, settings: settings)[0].error != nil)
    }
  }

  @Test func `binary files allow file links but cannot validate text positions`() throws {
    try withCheckout { root, settings in
      try Data([0xFF, 0xFE, 0xFF]).write(to: root.appendingPathComponent("image.bin"))
      let links = try DocumentLinks.extract(from: """
      source-link://repo/image.bin
      source-link://repo/image.bin?line=1
      source-link://repo/image.bin?line=2
      """)
      let results = DocumentLinkValidation.validate(links, settings: settings)
      #expect(results[0].error == nil)
      #expect(results[1].error != nil)
      #expect(results[2].error == results[1].error)
    }
  }

  @Test func `validates symbol matches without opening a picker`() throws {
    try withCheckout { root, settings in
      try Data("""
      struct Widget {
        func refresh(force: Bool) {}
        func refresh(force: Int) {}
      }
      """.utf8)
        .write(to: root.appendingPathComponent("Widget.swift"))
      let links = try DocumentLinks.extract(from: """
      [overloads](source-link://repo/Widget.swift?symbol=Widget.refresh(force:))
      source-link://repo/Widget.swift?symbol=Widget
      source-link://repo/Widget.swift?symbol=missing
      """)
      let results = DocumentLinkValidation.validate(links, settings: settings)
      #expect(results[0].error == nil)
      #expect(results[0].isAmbiguous)
      #expect(results[0].resolvedFile == root.appendingPathComponent("Widget.swift"))
      #expect(results[0].symbolMatches.map(\.line) == [2, 3])
      #expect(results[0].symbolMatches.map(\.column) == [8, 8])
      #expect(results[0].symbolMatches.map(\.signature) == [
        "Widget: func refresh(force: Bool)", "Widget: func refresh(force: Int)"
      ])
      #expect(results[1].error == nil)
      #expect(!results[1].isAmbiguous)
      #expect(results[1].symbolMatches.count == 1)
      #expect(results[2].error == SourceLinkError.missingSymbol.localizedDescription)
      #expect(!results[2].isAmbiguous)
      #expect(results[2].symbolMatches.isEmpty)
    }
  }
}
