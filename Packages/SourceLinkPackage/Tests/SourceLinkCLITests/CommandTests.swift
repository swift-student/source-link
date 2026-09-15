import Foundation
@testable import SourceLinkCLI
import Testing

struct CommandTests {
  private func withFiles(_ body: (URL, URL, URL) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let config = root.appendingPathComponent("config.json")
    let document = root.appendingPathComponent("document.md")
    let json: [String: Any] = ["version": 1, "checkouts": [["name": "repo", "path": root.path]]]
    try JSONSerialization.data(withJSONObject: json).write(to: config)
    try Data("abc\n".utf8).write(to: root.appendingPathComponent("file.swift"))
    try Data("[file](source-link://repo/file.swift?line=1&column=2)".utf8).write(to: document)
    try body(root, config, document)
  }

  @Test func `validates a document using an explicit config without writing files`() throws {
    try withFiles { root, config, document in
      let before = try Data(contentsOf: config)
      let result = Command.run(["validate", document.path, "--config", config.path])
      #expect(result.status == 0)
      #expect(result.output == "\(document.path): 1 source links checked, 0 invalid, 0 ambiguous\n")
      #expect(result.diagnostics.isEmpty)
      #expect(try Data(contentsOf: config) == before)
      #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).count == 3)
    }
  }

  @Test func `standard input reports each error and preserves summary`() throws {
    try withFiles { _, config, _ in
      let input = "source-link://repo/missing\nsource-link://repo/file.swift?line=99\nsource-link://repo/file.swift"
      let result = Command.run(["validate", "-", "--config", config.path]) { Data(input.utf8) }
      #expect(result.status == 1)
      #expect(result.output == "<stdin>: 3 source links checked, 2 invalid, 0 ambiguous\n")
      #expect(result.diagnostics.contains("<stdin>:1:1:"))
      #expect(result.diagnostics.contains("<stdin>:2:1:"))
      #expect(!result.diagnostics.contains("<stdin>:3:1:"))
    }
  }

  @Test func `no links is an explicit successful result`() throws {
    try withFiles { _, config, _ in
      let result = Command.run(["validate", "-", "--config", config.path]) { Data("https://example.com".utf8) }
      #expect(result.status == 0)
      #expect(result.output.contains("no source links found"))
    }
  }

  @Test func `read and configuration failures include their paths`() throws {
    try withFiles { root, config, document in
      let missing = root.appendingPathComponent("missing.md")
      let result = Command.run(["validate", missing.path, "--config", config.path])
      #expect(result.status == 1)
      #expect(result.diagnostics.contains(missing.path))
      try Data("invalid JSON".utf8).write(to: config)
      let broken = Command.run(["validate", document.path, "--config", config.path])
      #expect(broken.status == 1)
      #expect(broken.diagnostics.contains(config.path))
      try FileManager.default.removeItem(at: config)
      #expect(Command.run(["validate", document.path, "--config", config.path]).status == 1)
      let binary = Command.run(["validate", "-", "--config", config.path]) { Data([0xFF]) }
      #expect(binary.status == 1)
      #expect(binary.diagnostics.contains("<stdin>: Document must be UTF-8 text."))
    }
  }

  @Test(arguments: [
    ["validate"], ["links", "validate"], ["validate", "--bad"],
    ["validate", "file", "--config"], ["validate", "file", "--unknown", "config"],
    ["validate", "one", "two"], ["config", "validate", "one", "two"]
  ])
  func `usage errors return status two`(_ arguments: [String]) {
    let result = Command.run(arguments)
    #expect(result.status == 2)
    #expect(result.diagnostics.contains("Usage: source-link"))
    #expect(result.output.isEmpty)
  }

  @Test func `existing config commands and help remain available`() throws {
    try withFiles { _, config, _ in
      #expect(Command.run(["config", "path"]).status == 0)
      let result = Command.run(["config", "validate", config.path])
      #expect(result.status == 0)
      #expect(result.output == "\(config.path): valid\n")
      #expect(Command.run(["--help"]).output.contains("USAGE: source-link"))
    }
  }

  @Test func `links validate remains an alias for validate`() throws {
    try withFiles { _, config, document in
      let arguments = ["validate", document.path, "--config", config.path]
      let primary = Command.run(arguments)
      let alias = Command.run(["links"] + arguments)
      #expect(alias.status == primary.status)
      #expect(alias.output == primary.output)
      #expect(alias.diagnostics == primary.diagnostics)
    }
  }

  @Test func `options may precede the document`() throws {
    try withFiles { _, config, document in
      let result = Command.run(["validate", "--require-unique-symbols", "--config", config.path, document.path])
      #expect(result.status == 0)
      #expect(result.output.contains("1 source links checked, 0 invalid, 0 ambiguous"))
      #expect(result.diagnostics.isEmpty)
    }
  }

  @Test(arguments: [
    ["validate", "--help"], ["help", "validate"], ["links", "validate", "-h"]
  ])
  func `document help describes the options without reading input`(_ arguments: [String]) {
    let result = Command.run(arguments) {
      Issue.record("Help must not read standard input.")
      return Data()
    }
    #expect(result.status == 0)
    #expect(result.output.contains("--require-unique-symbols"))
    #expect(result.output.contains("--config"))
    #expect(result.output.contains("standard input"))
    #expect(result.diagnostics.isEmpty)
  }

  @Test(arguments: [["config", "--help"], ["config", "validate", "--help"], ["config", "path", "-h"]])
  func `config subcommands support help`(_ arguments: [String]) {
    let result = Command.run(arguments)
    #expect(result.status == 0)
    #expect(result.output.contains("USAGE: source-link config"))
    #expect(result.diagnostics.isEmpty)
  }

  @Test(arguments: [[], ["config"], ["links"]])
  func `command groups without a subcommand display help`(_ arguments: [String]) {
    let result = Command.run(arguments)
    #expect(result.status == 0)
    #expect(result.output.contains("USAGE: source-link"))
    #expect(result.diagnostics.isEmpty)
  }

  @Test func `usage errors explain missing values and unknown options`() {
    let missing = Command.run(["validate", "document.md", "--config"])
    #expect(missing.diagnostics.contains("Missing value for '--config"))
    let unknown = Command.run(["validate", "document.md", "--unknown"])
    #expect(unknown.diagnostics.contains("Unknown option '--unknown'"))
  }

  @Test func `argument separator supports document names beginning with a dash`() throws {
    let parsed = try ValidateDocument.parse(["--config", "config.json", "--", "-notes.md"])
    #expect(parsed.document == "-notes.md")
    #expect(parsed.config == "config.json")
  }

  @Test func `generates shell completion without running validation`() {
    let result = Command.run(["--generate-completion-script", "zsh"])
    #expect(result.status == 0)
    #expect(result.output.contains("--require-unique-symbols"))
    #expect(result.diagnostics.isEmpty)
  }
}
