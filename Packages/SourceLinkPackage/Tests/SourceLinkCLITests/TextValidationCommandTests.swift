import Foundation
@testable import SourceLinkCLI
import Testing

struct TextValidationCommandTests {
  @Test(arguments: [false, true])
  func `reports text locations and applies strictness after filtering overloads`(strict: Bool) throws {
    try withCheckout { root, config in
      let arguments = ["validate", "-", "--config", config.path] + (strict ? ["--require-unique-symbols"] : [])
      let url = "source-link://repo/Store.swift?symbol=Store.commit(_:)&find="
      let result = Command.run(arguments) { Data((url + "outbox.append").utf8) }
      #expect(result.status == (strict ? 1 : 0))
      #expect(result.output == "<stdin>: 1 source links checked, \(strict ? 1 : 0) invalid, 1 ambiguous\n")
      #expect(result.diagnostics.contains("\(strict ? "error" : "warning"): symbol link matches 3 locations"))
      #expect(result.diagnostics.contains("\(root.path)/Store.swift:3:5: Store: func commit(_ value: Int)"))
      #expect(result.diagnostics.contains("\(root.path)/Store.swift:4:5: Store: func commit(_ value: Int)"))
      #expect(result.diagnostics.contains("\(root.path)/Store.swift:7:5: Store: func commit(_ value: String)"))
      #expect(result.diagnostics.contains("    outbox.append(value + 1)\n"))
      let unique = Command.run(arguments) { Data((url + "value%20%2B%201").utf8) }
      #expect(unique.status == 0)
      #expect(unique.output.contains("1 source links checked, 0 invalid, 0 ambiguous"))
      #expect(unique.diagnostics.isEmpty)
    }
  }

  @Test func `missing symbols and snippets fail with distinct diagnostics`() throws {
    try withCheckout { _, config in
      let result = Command.run(["validate", "-", "--config", config.path]) {
        Data("""
        source-link://repo/Store.swift?symbol=missing&find=outbox.append
        source-link://repo/Store.swift?symbol=Store.commit(_:)&find=outsideOnly
        """.utf8)
      }
      #expect(result.status == 1)
      #expect(result.output.contains("2 source links checked, 2 invalid, 0 ambiguous"))
      #expect(result.diagnostics.contains("No matching declaration was found"))
      #expect(result.diagnostics.contains("literal find text was not found in any matching declaration"))
    }
  }

  @Test(arguments: ["d2", "svg"])
  func `validates encoded text anchors in D2 and rendered SVG links`(fileExtension: String) throws {
    try withCheckout { root, config in
      var components = try #require(URLComponents(string: "source-link://repo/Store.swift"))
      components.queryItems = [URLQueryItem(name: "symbol", value: "Store.commit(_:)"),
                               URLQueryItem(name: "find", value: "a&b#c+%?🐱")]
      let url = try #require(components.url).absoluteString
      let escaped = url.replacingOccurrences(of: "&", with: "&amp;")
      let document = root.appendingPathComponent("diagram." + fileExtension)
      let text = fileExtension == "d2" ? "step: { link: \"\(url)\" }"
        : "<svg><a href=\"\(escaped)\" xlink:href=\"\(escaped)\">commit</a></svg>"
      try text.write(to: document, atomically: true, encoding: .utf8)
      let result = Command.run(["validate", document.path, "--config", config.path, "--require-unique-symbols"])
      #expect(result.status == 0)
      #expect(result.diagnostics.isEmpty)
      #expect(result.output.contains("\(fileExtension == "svg" ? 2 : 1) source links checked, 0 invalid, 0 ambiguous"))
    }
  }

  private func withCheckout(_ body: (URL, URL) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let config = root.appendingPathComponent("config.json")
    let json: [String: Any] = ["version": 1, "checkouts": [["name": "repo", "path": root.path]]]
    try JSONSerialization.data(withJSONObject: json).write(to: config)
    try """
    struct Store {
      func commit(_ value: Int) {
        outbox.append(value)
        outbox.append(value + 1)
      }
      func commit(_ value: String) {
        outbox.append(value)
        // a&b#c+%?🐱
      }
    }
    // outsideOnly
    """.write(to: root.appendingPathComponent("Store.swift"), atomically: true, encoding: .utf8)
    try body(root, config)
  }
}
