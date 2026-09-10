import Foundation
import Testing
@testable import XedLinkCore

@Suite struct ConfigurationRepositoryTests {
  func withDirectory(_ body: (URL) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try body(root)
  }

  @Test func migratesOnceAndKeepsJSONBackup() throws {
    try withDirectory { root in
      let repository = ConfigurationRepository(file: root.appendingPathComponent("config.toml"),
                                               legacyFile: root.appendingPathComponent("settings.json"))
      var legacy = SourceSettings()
      legacy.defaultEditor = .cursor
      legacy.checkouts = [Checkout(name: "a", path: "~/a")]
      legacy.executablePaths["xcode"] = ""
      let json = try JSONEncoder().encode(legacy)
      try json.write(to: repository.legacyFile)
      let migrated = try repository.loadOrMigrate()
      #expect(migrated.exists)
      #expect(migrated.document.settings.defaultEditor == .cursor)
      #expect(migrated.document.settings.executablePaths.isEmpty)
      #expect(try Data(contentsOf: repository.legacyFile) == json)
      try Data("version=1\ndefault_editor='zed'".utf8).write(to: repository.file)
      #expect(try repository.loadOrMigrate().document.settings.defaultEditor == .zed)
      try FileManager.default.removeItem(at: repository.file)
      #expect(try !repository.load().exists)
    }
  }

  @Test func savesThroughSymlinkAndDetectsRetargeting() throws {
    try withDirectory { root in
      let target = root.appendingPathComponent("dotfiles.toml")
      let link = root.appendingPathComponent("config.toml")
      try Data("# my dotfiles\nversion=1\n".utf8).write(to: target)
      try FileManager.default.setAttributes([.posixPermissions: 0o640], ofItemAtPath: target.path)
      try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
      let repository = ConfigurationRepository(file: link, legacyFile: root.appendingPathComponent("missing"))
      let base = try repository.load()
      var draft = base.document.settings
      draft.defaultEditor = .cursor
      let saved = try repository.save(base: base, draft: draft)
      #expect(saved.document.settings.defaultEditor == .cursor)
      #expect(try FileManager.default.destinationOfSymbolicLink(atPath: link.path) == target.path)
      #expect(try String(contentsOf: target, encoding: .utf8).contains("# my dotfiles"))
      #expect(try FileManager.default.attributesOfItem(atPath: target.path)[.posixPermissions] as? Int == 0o640)
      let other = root.appendingPathComponent("other.toml")
      try Data("version=1\n".utf8).write(to: other)
      try FileManager.default.removeItem(at: link)
      try FileManager.default.createSymbolicLink(at: link, withDestinationURL: other)
      #expect(throws: ConfigurationError.self) { try repository.save(base: saved, draft: draft) }
    }
  }

  @Test func mergesExternalReplacementAndDoesNotOverwriteBrokenOrDeletedFile() throws {
    try withDirectory { root in
      let repository = ConfigurationRepository(file: root.appendingPathComponent("config.toml"),
                                               legacyFile: root.appendingPathComponent("missing"))
      let initial = try repository.load()
      #expect(!initial.exists)
      var draft = initial.document.settings
      draft.defaultEditor = .cursor
      let base = try repository.save(base: initial, draft: draft)
      try Data("# agent\nversion=1\ndefault_editor='cursor'\n[executables]\nzed='~/zed'\n".utf8)
        .write(to: repository.file, options: .atomic)
      draft.defaultEditor = .zed
      let merged = try repository.save(base: base, draft: draft)
      #expect(merged.document.settings.executablePaths["zed"] == "~/zed")
      #expect(merged.document.text.contains("# agent"))
      let broken = Data("version = [broken".utf8)
      try broken.write(to: repository.file)
      #expect(throws: ConfigurationError.self) { try repository.save(base: merged, draft: draft) }
      #expect(try Data(contentsOf: repository.file) == broken)
      try FileManager.default.removeItem(at: repository.file)
      #expect(throws: ConfigurationError.self) { try repository.save(base: merged, draft: draft) }
      #expect(!FileManager.default.fileExists(atPath: repository.file.path))
    }
  }

  @Test func brokenTOMLAndDanglingSymlinkNeverTriggerMigration() throws {
    try withDirectory { root in
      let file = root.appendingPathComponent("config.toml")
      let legacy = root.appendingPathComponent("settings.json")
      try JSONEncoder().encode(SourceSettings()).write(to: legacy)
      let repository = ConfigurationRepository(file: file, legacyFile: legacy)
      try Data("version='bad'".utf8).write(to: file)
      #expect(throws: ConfigurationError.self) { try repository.loadOrMigrate() }
      try FileManager.default.removeItem(at: file)
      try FileManager.default.createSymbolicLink(at: file, withDestinationURL: root.appendingPathComponent("absent"))
      #expect(throws: ConfigurationError.self) { try repository.loadOrMigrate() }
      #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("absent").path))
    }
  }
}
