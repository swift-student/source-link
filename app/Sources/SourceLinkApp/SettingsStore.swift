import AppKit
import SourceLinkCore
import SwiftUI

@MainActor
final class SettingsStore: ObservableObject {
  @Published var settings = SourceSettings() {
    didSet {
      guard !isAcceptingSnapshot else { return }
      scheduleAutoSave()
    }
  }

  @Published private(set) var activeSettings = SourceSettings()
  @Published private(set) var errorMessage: String? {
    didSet { presentErrorIfNeeded() }
  }

  @Published private(set) var saveError: String? {
    didSet { presentErrorIfNeeded() }
  }

  @Published var presentedError: String?
  private var reportedErrors = Set<String>()
  let repository: ConfigurationRepository
  private var base: ConfigurationSnapshot?
  private var active: ConfigurationSnapshot?
  private var watcher: Task<Void, Never>?
  private(set) var autoSave: Task<Void, Never>?
  private let autoSaveDelay: @Sendable () async throws -> Void
  private var isAcceptingSnapshot = false

  var isDirty: Bool {
    base.map { !settings.hasSameConfiguration(as: $0.document.settings) } ?? false
  }

  private func presentErrorIfNeeded() {
    guard let message = errorMessage ?? saveError else {
      reportedErrors.removeAll()
      presentedError = nil
      return
    }
    if reportedErrors.insert(message).inserted {
      presentedError = message
    }
  }

  func reportSettingsError(_ error: Error) {
    saveError = error.localizedDescription
  }

  var canSave: Bool {
    base != nil && errorMessage == nil
  }

  var setupSnapshot: ConfigurationSnapshot? {
    active
  }

  private static func defaultRepository() -> ConfigurationRepository {
    #if DEBUG
      if let path = ProcessInfo.processInfo.environment["SOURCE_LINK_TEST_SETTINGS_PATH"] {
        let file = URL(fileURLWithPath: path)
        return ConfigurationRepository(file: file)
      }
    #endif
    return ConfigurationRepository()
  }

  init(
    repository: ConfigurationRepository? = nil,
    watchForChanges: Bool = true,
    autoSaveDelay: @escaping @Sendable () async throws -> Void = {
      try await Task.sleep(for: .milliseconds(500))
    }
  ) {
    self.autoSaveDelay = autoSaveDelay
    let repository = repository ?? Self.defaultRepository()
    self.repository = repository
    do { try accept(repository.load(), discardDraft: true) } catch {
      errorMessage = error.localizedDescription
    }
    presentErrorIfNeeded()
    // Reopen the path each time: this also catches atomic replacements, parent-directory
    // replacements and symlink retargeting, including initially missing configuration files.
    guard watchForChanges else { return }
    watcher = Task { [weak self] in
      while !Task.isCancelled {
        do { try await Task.sleep(for: .seconds(1)) } catch { return }
        self?.reload()
      }
    }
  }

  #if DEBUG
    /// Canvas edits stay in memory: no configuration load, watcher, or save baseline.
    init(previewSettings: SourceSettings) {
      autoSaveDelay = {}
      repository = ConfigurationRepository(file: FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString).appendingPathComponent("preview.json"))
      settings = previewSettings
      activeSettings = previewSettings
    }
  #endif

  deinit {
    watcher?.cancel()
    autoSave?.cancel()
  }

  private func scheduleAutoSave() {
    autoSave?.cancel()
    autoSave = nil
    saveError = nil
    guard isDirty, canSave else { return }
    let delay = autoSaveDelay
    autoSave = Task { [weak self] in
      do { try await delay() } catch { return }
      guard !Task.isCancelled else { return }
      self?.save()
    }
  }

  private func accept(_ snapshot: ConfigurationSnapshot, discardDraft: Bool = false) {
    isAcceptingSnapshot = true
    defer { isAcceptingSnapshot = false }
    let dirty = isDirty
    if discardDraft {
      autoSave?.cancel()
      autoSave = nil
    }
    if discardDraft || !dirty {
      // UI-only row IDs are regenerated when configuration is decoded. Keep the
      // current values after an unchanged save so selection and focus survive.
      if !settings.hasSameConfiguration(as: snapshot.document.settings) {
        settings = snapshot.document.settings
      }
      base = snapshot
    }
    active = snapshot
    activeSettings = snapshot.document.settings
    errorMessage = nil
  }

  func reload() {
    do {
      let snapshot = try repository.load()
      if let active, active.exists, !snapshot.exists {
        throw ConfigurationError("\(repository.file.path): configuration was removed. "
          + "The last valid settings remain active. Restore the file to continue editing.")
      }
      if errorMessage != nil || snapshot.document.text != active?.document.text || snapshot.target != active?.target
        || snapshot.exists != active?.exists {
        let wasBlocked = errorMessage != nil
        accept(snapshot)
        if wasBlocked, isDirty, saveError == nil {
          scheduleAutoSave()
        }
      }
    } catch { errorMessage = error.localizedDescription }
  }

  /// Cancel pending writes; only discard the draft after successfully reading the current file.
  func discardChangesAndReload() {
    autoSave?.cancel()
    autoSave = nil
    do {
      try accept(repository.load(), discardDraft: true)
      saveError = nil
    } catch { errorMessage = error.localizedDescription }
  }

  private func save() {
    autoSave = nil
    guard canSave, isDirty, let base else { return }
    var extensions = Set<String>()
    for rule in settings.rules {
      let fileExtension = rule.normalizedExtension
      guard extensions.insert(fileExtension).inserted else {
        saveError = "Each file extension can have one rule. Remove the duplicate rule for \(fileExtension)."
        return
      }
    }
    do {
      try accept(repository.save(base: base, draft: settings), discardDraft: true)
      saveError = nil
    } catch { saveError = error.localizedDescription }
  }

  /// Flush pending edits and materialize bundled profiles before handing the file to an editor.
  func prepareConfigurationForEditing() throws -> URL {
    autoSave?.cancel()
    autoSave = nil
    reload()
    if errorMessage != nil {
      guard FileManager.default.fileExists(atPath: repository.file.path) else {
        throw ConfigurationError(errorMessage ?? "Configuration is unavailable.")
      }
      return repository.file
    }
    if isDirty {
      save()
      if let saveError {
        throw ConfigurationError(saveError)
      }
    }
    guard let base else { throw ConfigurationError("Configuration is unavailable.") }
    try accept(repository.save(base: base, draft: settings), discardDraft: true)
    return repository.file
  }

  func saveSetup(_ settings: SourceSettings, base: ConfigurationSnapshot) -> Bool {
    guard errorMessage == nil else { return false }
    do {
      try accept(repository.save(base: base, draft: settings))
      return true
    } catch { Self.show(error); return false }
  }

  static func show(_ error: Error) {
    let alert = NSAlert(error: error)
    NSApp.activate(ignoringOtherApps: true)
    alert.runModal()
  }
}
