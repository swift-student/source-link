import Foundation
import Testing
@testable import XedLinkCore

struct ConfigurationRepositoryTests {
  func withDirectory(_ body: (URL) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try body(root)
  }

  @Test func `missing configuration uses defaults without creating file`() throws {
    try withDirectory { root in
      let file = root.appendingPathComponent("config.json")
      let snapshot = try ConfigurationRepository(file: file).load()
      #expect(!snapshot.exists)
      #expect(snapshot.document.settings.hasSameConfiguration(as: SourceSettings()))
      #expect(!FileManager.default.fileExists(atPath: file.path))
    }
  }

  @Test func `saves through symlink and detects retargeting`() throws {
    try withDirectory { root in
      let target = root.appendingPathComponent("dotfiles.json")
      let link = root.appendingPathComponent("config.json")
      try Data("{\"version\": 1}".utf8).write(to: target)
      try FileManager.default.setAttributes([.posixPermissions: 0o640], ofItemAtPath: target.path)
      try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
      let repository = ConfigurationRepository(file: link)
      let base = try repository.load()
      var draft = base.document.settings
      draft.defaultEditor = .cursor
      let saved = try repository.save(base: base, draft: draft)
      #expect(saved.document.settings.defaultEditor == .cursor)
      #expect(try FileManager.default.destinationOfSymbolicLink(atPath: link.path) == target.path)
      #expect(try FileManager.default.attributesOfItem(atPath: target.path)[.posixPermissions] as? Int == 0o640)
      let other = root.appendingPathComponent("other.json")
      try Data("{\"version\": 1}".utf8).write(to: other)
      try FileManager.default.removeItem(at: link)
      try FileManager.default.createSymbolicLink(at: link, withDestinationURL: other)
      #expect(throws: ConfigurationError.self) { try repository.save(base: saved, draft: draft) }
    }
  }

  @Test func `merges external replacement and does not overwrite broken or deleted file`() throws {
    try withDirectory { root in
      let repository = ConfigurationRepository(file: root.appendingPathComponent("config.json"))
      let initial = try repository.load()
      #expect(!initial.exists)
      var draft = initial.document.settings
      draft.defaultEditor = .cursor
      let base = try repository.save(base: initial, draft: draft)
      try Data("{\"version\": 1, \"default_editor\": \"cursor\", \"executables\": {\"zed\": \"~/zed\"}}".utf8)
        .write(to: repository.file, options: .atomic)
      draft.defaultEditor = .zed
      let merged = try repository.save(base: base, draft: draft)
      #expect(merged.document.settings.executablePaths["zed"] == "~/zed")
      let broken = Data("{\"version\": [broken".utf8)
      try broken.write(to: repository.file)
      #expect(throws: ConfigurationError.self) { try repository.save(base: merged, draft: draft) }
      #expect(try Data(contentsOf: repository.file) == broken)
      try FileManager.default.removeItem(at: repository.file)
      #expect(throws: ConfigurationError.self) { try repository.save(base: merged, draft: draft) }
      #expect(!FileManager.default.fileExists(atPath: repository.file.path))
    }
  }

  @Test func `rejects broken JSON and dangling symlink`() throws {
    try withDirectory { root in
      let file = root.appendingPathComponent("config.json")
      let repository = ConfigurationRepository(file: file)
      try Data("{\"version\": \"bad\"}".utf8).write(to: file)
      #expect(throws: ConfigurationError.self) { try repository.load() }
      try FileManager.default.removeItem(at: file)
      try FileManager.default.createSymbolicLink(at: file, withDestinationURL: root.appendingPathComponent("absent"))
      #expect(throws: ConfigurationError.self) { try repository.load() }
      #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("absent").path))
    }
  }
}
