import Foundation

public struct ConfigurationSnapshot: Sendable {
  public let document: ConfigurationDocument
  public let target: URL
  public let exists: Bool
}

/// Disk access is independent of AppKit. Reads always follow the current symlink destination.
public struct ConfigurationRepository: Sendable {
  public let file: URL

  public init(file: URL = ConfigurationPaths.file()) {
    self.file = file
  }

  public func load() throws -> ConfigurationSnapshot {
    do {
      let target = file.resolvingSymlinksInPath().standardizedFileURL
      if try exists(file) {
        let document = try ConfigurationDocument(text: String(contentsOf: file, encoding: .utf8))
        return ConfigurationSnapshot(document: document, target: target, exists: true)
      }
      return try ConfigurationSnapshot(document: .initial(), target: target, exists: false)
    } catch { throw ConfigurationError("\(file.path): \(error.localizedDescription)") }
  }

  public func save(base: ConfigurationSnapshot, draft: SourceSettings) throws -> ConfigurationSnapshot {
    let latest = try load()
    guard latest.exists == base.exists, latest.target == base.target else {
      throw ConfigurationError("\(file.path): the file was created, removed, or its symlink changed. "
        + "Choose Reload from File in the settings alert before editing again.")
    }
    let merged = try latest.document.merging(base: base.document.settings, draft: draft)
    return try write(merged, replacing: latest)
  }

  /// Preserve the original beside its resolved target before installing defaults.
  /// Neither an existing backup nor a concurrently created configuration is overwritten.
  public func backUpAndReset() throws -> ConfigurationSnapshot {
    let manager = FileManager.default
    let target = file.resolvingSymlinksInPath().standardizedFileURL
    if try !exists(file) {
      let snapshot = try load()
      guard !snapshot.exists else {
        throw ConfigurationError("\(file.path): the file appeared during reset. Please try again.")
      }
      return try save(base: snapshot, draft: SourceSettings())
    }
    let attributes = try manager.attributesOfItem(atPath: target.path)
    guard attributes[.type] as? FileAttributeType == .typeRegular else {
      throw ConfigurationError("\(file.path): only a regular configuration file can be backed up and reset.")
    }
    let document = try ConfigurationDocument.initial()
    let stamp = Date().ISO8601Format().replacingOccurrences(of: ":", with: "-")
    let backup = target.deletingLastPathComponent().appendingPathComponent(
      "\(target.deletingPathExtension().lastPathComponent).backup-\(stamp)-\(UUID()).json"
    )
    let temporary = target.deletingLastPathComponent().appendingPathComponent(".source-link-\(UUID()).tmp")
    defer { try? manager.removeItem(at: temporary) }
    try Data(document.text.utf8).write(to: temporary, options: .withoutOverwriting)
    try manager.setAttributes([.posixPermissions: attributes[.posixPermissions] ?? NSNumber(value: 0o600)],
                              ofItemAtPath: temporary.path)
    // A failed backup leaves the original untouched. Symlinks remain pointed at the same target.
    try manager.moveItem(at: target, to: backup)
    guard link(temporary.path, target.path) == 0 else {
      let error = POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
      // Restore the original if the path is still free; always retain the backup.
      _ = link(backup.path, target.path)
      throw ConfigurationError("Could not create default settings: \(error.localizedDescription) "
        + "Your original configuration is preserved at \(backup.path).")
    }
    return try load()
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
          current.document.text == expected.document.text
    else {
      throw ConfigurationError(
        "\(file.path): changed again during saving. Your draft is retained. Edit the setting again to retry saving."
      )
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
