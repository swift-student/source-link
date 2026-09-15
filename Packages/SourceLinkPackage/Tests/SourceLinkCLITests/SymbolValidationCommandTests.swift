import Foundation
@testable import SourceLinkCLI
import Testing

struct SymbolValidationCommandTests {
  private func withSymbols(_ body: (URL, URL) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let config = root.appendingPathComponent("config.json")
    let json: [String: Any] = ["version": 1, "checkouts": [["name": "repo", "path": root.path]]]
    try JSONSerialization.data(withJSONObject: json).write(to: config)
    try Data("""
    struct Widget {
      func refresh(force: Bool) {}
      func refresh(force: Int) {}
    }
    """.utf8).write(to: root.appendingPathComponent("Widget.swift"))
    try body(root, config)
  }

  @Test(arguments: [false, true])
  func `reports overload candidates and applies strict mode`(strict: Bool) throws {
    try withSymbols { root, config in
      let input = "[refresh](source-link://repo/Widget.swift?symbol=Widget.refresh(force:))"
      let arguments = ["validate", "-", "--config", config.path] + (strict ? ["--require-unique-symbols"] : [])
      let result = Command.run(arguments) { Data(input.utf8) }
      #expect(result.status == (strict ? 1 : 0))
      #expect(result.output == "<stdin>: 1 source links checked, \(strict ? 1 : 0) invalid, 1 ambiguous\n")
      #expect(result.diagnostics == """
      <stdin>:1:11: \(strict ? "error" : "warning"): symbol link matches 2 declarations \
      [source-link://repo/Widget.swift?symbol=Widget.refresh(force:)]
        \(root.path)/Widget.swift:2:8: Widget: func refresh(force: Bool)
        \(root.path)/Widget.swift:3:8: Widget: func refresh(force: Int)

      """)
      let alias = Command.run(["links"] + arguments) { Data(input.utf8) }
      #expect(alias.status == result.status)
      #expect(alias.output == result.output)
      #expect(alias.diagnostics == result.diagnostics)
    }
  }

  @Test(arguments: [false, true])
  func `reports all mixed results and counts repeated ambiguous links`(strict: Bool) throws {
    try withSymbols { _, config in
      let input = """
      source-link://repo/Widget.swift?symbol=Widget.refresh(force:)
      source-link://repo/Widget.swift?symbol=Widget
      source-link://repo/Widget.swift?symbol=missing
      source-link://repo/Widget.swift?symbol=Widget.refresh(force:)
      source-link://repo/Widget.swift
      """
      let arguments = ["validate", "--config", config.path] + (strict ? ["--require-unique-symbols"] : []) + ["-"]
      let result = Command.run(arguments) { Data(input.utf8) }
      #expect(result.status == 1)
      #expect(result.output == "<stdin>: 5 source links checked, \(strict ? 3 : 1) invalid, 2 ambiguous\n")
      #expect(result.diagnostics.contains("<stdin>:1:1: \(strict ? "error" : "warning"): symbol link matches 2"))
      #expect(!result.diagnostics.contains("<stdin>:2:1:"))
      #expect(result.diagnostics.contains("<stdin>:3:1: error:"))
      #expect(result.diagnostics.contains("<stdin>:4:1: \(strict ? "error" : "warning"): symbol link matches 2"))
      #expect(!result.diagnostics.contains("<stdin>:5:1:"))
    }
  }

  @Test func `strict mode accepts a unique symbol`() throws {
    try withSymbols { _, config in
      let result = Command.run(["validate", "-", "--config", config.path, "--require-unique-symbols"]) {
        Data("source-link://repo/Widget.swift?symbol=Widget".utf8)
      }
      #expect(result.status == 0)
      #expect(result.output.contains("1 source links checked, 0 invalid, 0 ambiguous"))
      #expect(result.diagnostics.isEmpty)
    }
  }
}
