import AppKit
import SwiftUI
import XedLinkCore

@MainActor
final class SettingsStore: ObservableObject {
  @Published var settings = SourceSettings()
  @Published private(set) var activeSettings = SourceSettings()
  @Published private(set) var errorMessage: String?
  @Published private(set) var saveError: String?
  let repository: ConfigurationRepository
  private var base: ConfigurationSnapshot?
  private var active: ConfigurationSnapshot?
  private var watcher: Task<Void, Never>?

  var isDirty: Bool { base.map { !settings.hasSameConfiguration(as: $0.document.settings) } ?? false }
  var canApply: Bool { base != nil && errorMessage == nil }
  var setupSnapshot: ConfigurationSnapshot? { active }

  private static func defaultRepository() -> ConfigurationRepository {
    #if DEBUG
    if let path = ProcessInfo.processInfo.environment["SOURCE_LINK_TEST_SETTINGS_PATH"] {
      let file = URL(fileURLWithPath: path)
      return ConfigurationRepository(file: file)
    }
    #endif
    return ConfigurationRepository()
  }

  init(repository: ConfigurationRepository? = nil) {
    let repository = repository ?? Self.defaultRepository()
    self.repository = repository
    do { accept(try repository.load(), discardDraft: true) } catch {
      errorMessage = error.localizedDescription
    }
    // Reopen the path each time: this also catches atomic replacements, parent-directory
    // replacements and symlink retargeting, including initially missing configuration files.
    watcher = Task { [weak self] in
      while !Task.isCancelled {
        do { try await Task.sleep(for: .seconds(1)) } catch { return }
        self?.reload()
      }
    }
  }

  deinit { watcher?.cancel() }

  private func accept(_ snapshot: ConfigurationSnapshot, discardDraft: Bool = false) {
    let dirty = isDirty
    if discardDraft || !dirty {
      if discardDraft || !settings.hasSameConfiguration(as: snapshot.document.settings) {
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
        accept(snapshot)
      }
    } catch { errorMessage = error.localizedDescription }
  }

  func revert() {
    do {
      let snapshot = try repository.load()
      guard snapshot.exists || active?.exists != true else {
        throw ConfigurationError("Restore the missing configuration file before reverting.")
      }
      accept(snapshot, discardDraft: true)
      saveError = nil
    } catch { errorMessage = error.localizedDescription }
  }

  func save() {
    guard let base else { return }
    do {
      accept(try repository.save(base: base, draft: settings), discardDraft: true)
      saveError = nil
    } catch { saveError = error.localizedDescription }
  }

  func saveSetup(_ settings: SourceSettings, base: ConfigurationSnapshot) -> Bool {
    guard errorMessage == nil else { return false }
    do {
      accept(try repository.save(base: base, draft: settings))
      return true
    } catch { Self.show(error); return false }
  }

  static func show(_ error: Error) {
    let alert = NSAlert(error: error)
    NSApp.activate(ignoringOtherApps: true)
    alert.runModal()
  }
}
