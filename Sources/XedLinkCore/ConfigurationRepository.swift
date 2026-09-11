import Foundation

public struct ConfigurationSnapshot: Sendable {
  public let document: ConfigurationDocument
  public let target: URL
  public let exists: Bool
}

/// Disk access is independent of AppKit. Reads always follow the current symlink destination.
public struct ConfigurationRepository: Sendable {
  public let file: URL
  public let legacyFile: URL

  public init(file: URL = ConfigurationPaths.file(), legacyFile: URL = URL.applicationSupportDirectory
    .appendingPathComponent("SourceLink/settings.json")) {
    self.file = file
    self.legacyFile = legacyFile
  }

  public func load() throws -> ConfigurationSnapshot {
    do {
      let target = file.resolvingSymlinksInPath().standardizedFileURL
      if try exists(file) {
        let document = try ConfigurationDocument(text: String(contentsOf: file, encoding: .utf8))
        return ConfigurationSnapshot(document: document, target: target, exists: true)
      }
      return ConfigurationSnapshot(document: try .initial(), target: target, exists: false)
    } catch { throw ConfigurationError("\(file.path): \(error.localizedDescription)") }
  }

  /// Only startup migrates. Reloading a deleted configuration file never silently resurrects legacy JSON.
  public func loadOrMigrate() throws -> ConfigurationSnapshot {
    let snapshot = try load()
    guard !snapshot.exists, try exists(legacyFile) else { return snapshot }
    do {
      var settings = try JSONDecoder().decode(SourceSettings.self, from: Data(contentsOf: legacyFile))
      settings.normalizeDefaults()
      // Empty overrides used to mean the built-in executable.
      settings.executablePaths = settings.executablePaths.filter { !$0.value.isEmpty }
      let document = try ConfigurationDocument.initial(settings)
      return try write(document, replacing: snapshot)
    } catch { throw ConfigurationError("Migration from \(legacyFile.path): \(error.localizedDescription)") }
  }

  public func save(base: ConfigurationSnapshot, draft: SourceSettings) throws -> ConfigurationSnapshot {
    let latest = try load()
    guard latest.exists == base.exists, latest.target == base.target else {
      throw ConfigurationError("\(file.path): the file was created, removed, or its symlink changed. "
        + "Use Revert to load the current file before applying your draft.")
    }
    let merged = try latest.document.merging(base: base.document.settings, draft: draft)
    return try write(merged, replacing: latest)
  }

  private func exists(_ url: URL) throws -> Bool {
    do {
      _ = try FileManager.default.attributesOfItem(atPath: url.path)
      return true
    } catch let error as NSError where error.domain == NSCocoaErrorDomain
      && (error.code == NSFileNoSuchFileError || error.code == NSFileReadNoSuchFileError) {
      return false
    }
  }

  private func write(_ document: ConfigurationDocument, replacing expected: ConfigurationSnapshot) throws
    -> ConfigurationSnapshot {
    let manager = FileManager.default
    try manager.createDirectory(at: expected.target.deletingLastPathComponent(), withIntermediateDirectories: true)
    let permissions = expected.exists
      ? try manager.attributesOfItem(atPath: expected.target.path)[.posixPermissions] : nil
    let temporary = expected.target.deletingLastPathComponent().appendingPathComponent(".source-link-\(UUID()).tmp")
    defer { try? manager.removeItem(at: temporary) }
    try Data(document.text.utf8).write(to: temporary, options: .withoutOverwriting)
    try manager.setAttributes([.posixPermissions: permissions ?? NSNumber(value: 0o600)], ofItemAtPath: temporary.path)
    // Detect changes made since the merge, immediately before committing. An unrelated writer is not locked out.
    let current = try load()
    guard current.target == expected.target, current.exists == expected.exists,
          current.document.text == expected.document.text else {
      throw ConfigurationError("\(file.path): changed again during saving. Try Apply again.")
    }
    // rename replaces the destination atomically without replacing the user's symlink.
    let status = expected.exists ? rename(temporary.path, expected.target.path)
      : link(temporary.path, expected.target.path)
    guard status == 0 else {
      throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
    return ConfigurationSnapshot(document: document, target: expected.target, exists: true)
  }
}
