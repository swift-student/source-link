import Foundation
import SourceLinkCore
import Testing

@MainActor
struct SettingsStoreTests {
  @Test func `editing configuration creates a file with all profiles`() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("config.json")
    let store = SettingsStore(repository: ConfigurationRepository(file: file), watchForChanges: false)
    #expect(try store.prepareConfigurationForEditing() == file)
    let text = try String(contentsOf: file, encoding: .utf8)
    #expect(text.contains("\"executable\""))
    #expect(text.contains("\"line_arguments\""))
    #expect(try ConfigurationDocument(text: text).settings.editors == EditorProfile.defaults)
  }

  @Test func `editing configuration flushes the draft and preserves invalid disk contents`() throws {
    let fixture = try StoreFixture()
    fixture.store.settings.defaultEditor = .cursor
    _ = try fixture.store.prepareConfigurationForEditing()
    #expect(fixture.store.autoSave == nil)
    #expect(try fixture.repository.load().document.settings.defaultEditor == .cursor)
    try Data("broken JSON".utf8).write(to: fixture.repository.file)
    #expect(try fixture.store.prepareConfigurationForEditing() == fixture.repository.file)
    #expect(try String(contentsOf: fixture.repository.file, encoding: .utf8) == "broken JSON")
  }

  @Test func `rapid edits cancel earlier saves and preserve row identities`() async throws {
    let fixture = try StoreFixture()
    let store = fixture.store
    store.settings.rules.append(FileRule())
    let rowID = try #require(store.settings.rules.first?.id)
    let first = try #require(store.autoSave)
    await fixture.delay.waitUntilScheduled()
    store.settings.defaultEditor = .cursor
    await fixture.delay.resumeNext()
    await first.value
    #expect(try fixture.repository.load().document.settings.rules.isEmpty)
    #expect(store.activeSettings.defaultEditor == .xcode)
    try await fixture.finishSave()
    #expect(try fixture.repository.load().document.settings.defaultEditor == .cursor)
    #expect(store.settings.rules.first?.id == rowID)
    #expect(!store.isDirty)
  }

  @Test func `external edits merge with a pending draft`() async throws {
    let fixture = try StoreFixture()
    fixture.store.settings.defaultEditor = .cursor
    try fixture.editDisk { $0.editors["zed"]?.executable = "/custom/zed" }
    fixture.store.reload()
    #expect(fixture.store.activeSettings.editors["zed"]?.executable == "/custom/zed")
    #expect(fixture.store.settings.defaultEditor == .cursor)
    try await fixture.finishSave()
    let saved = try fixture.repository.load().document.settings
    #expect(saved.defaultEditor == .cursor)
    #expect(saved.editors["zed"]?.executable == "/custom/zed")
    #expect(fixture.store.saveError == nil)
  }

  @Test func `conflicting edits retain the draft and recover when matched`() async throws {
    let fixture = try StoreFixture()
    fixture.store.settings.defaultEditor = .cursor
    try fixture.editDisk { $0.defaultEditor = .zed }
    // Saving must check disk even before the next watcher reload.
    try await fixture.finishSave()
    #expect(fixture.store.saveError?.contains("Conflict in default_editor") == true)
    #expect(fixture.store.settings.defaultEditor == .cursor)
    #expect(try fixture.repository.load().document.settings.defaultEditor == .zed)
    fixture.store.reload()
    #expect(fixture.store.activeSettings.defaultEditor == .zed)
    fixture.store.settings.defaultEditor = .zed
    try await fixture.finishSave()
    #expect(fixture.store.saveError == nil)
    #expect(!fixture.store.isDirty)
  }

  @Test func `invalid external configuration blocks saving and restoration resumes it`() async throws {
    let fixture = try StoreFixture()
    let original = try Data(contentsOf: fixture.repository.file)
    fixture.store.settings.defaultEditor = .cursor
    try Data("invalid JSON".utf8).write(to: fixture.repository.file)
    fixture.store.reload()
    try await fixture.finishSave()
    #expect(fixture.store.errorMessage != nil)
    #expect(fixture.store.activeSettings.defaultEditor == .xcode)
    #expect(try String(contentsOf: fixture.repository.file, encoding: .utf8) == "invalid JSON")
    try original.write(to: fixture.repository.file)
    fixture.store.reload()
    try await fixture.finishSave()
    #expect(fixture.store.errorMessage == nil)
    #expect(fixture.store.activeSettings.defaultEditor == .cursor)
    #expect(!fixture.store.isDirty)
  }

  @Test func `equivalent duplicate rules block UI saves until corrected`() async throws {
    let fixture = try StoreFixture()
    var duplicate = FileRule()
    duplicate.fileExtension = " .SWIFT "
    fixture.store.settings.rules = [FileRule(), duplicate]
    try await fixture.finishSave()
    #expect(fixture.store.saveError?.contains("duplicate rule for swift") == true)
    #expect(try fixture.repository.load().document.settings.rules.isEmpty)
    fixture.store.settings.rules.removeLast()
    try await fixture.finishSave()
    #expect(fixture.store.saveError == nil)
    #expect(try fixture.repository.load().document.settings.rules.count == 1)
  }
}

@MainActor
private final class StoreFixture {
  let directory: URL
  let repository: ConfigurationRepository
  let delay = ManualSaveDelay()
  let store: SettingsStore

  init() throws {
    directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    repository = ConfigurationRepository(file: directory.appendingPathComponent("config.json"))
    let base = try repository.load()
    _ = try repository.save(base: base, draft: base.document.settings)
    let delay = delay
    store = SettingsStore(repository: repository, watchForChanges: false, autoSaveDelay: {
      await delay.suspend()
    })
  }

  deinit {
    try? FileManager.default.removeItem(at: directory)
  }

  func editDisk(_ edit: (inout SourceSettings) -> Void) throws {
    let base = try repository.load()
    var settings = base.document.settings
    edit(&settings)
    _ = try repository.save(base: base, draft: settings)
  }

  func finishSave() async throws {
    let task = try #require(store.autoSave)
    await delay.waitUntilScheduled()
    await delay.resumeNext()
    await task.value
  }
}

/// A deliberately cancellation-insensitive delay verifies that cancelled saves
/// cannot write even if their suspended operation eventually returns normally.
private actor ManualSaveDelay {
  private var pending: [CheckedContinuation<Void, Never>] = []
  private var observer: CheckedContinuation<Void, Never>?

  func suspend() async {
    await withCheckedContinuation { continuation in
      pending.append(continuation)
      observer?.resume()
      observer = nil
    }
  }

  func waitUntilScheduled() async {
    guard pending.isEmpty else { return }
    await withCheckedContinuation { observer = $0 }
  }

  func resumeNext() {
    pending.removeFirst().resume()
  }
}
