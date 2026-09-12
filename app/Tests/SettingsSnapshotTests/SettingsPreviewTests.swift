#if DEBUG
  import Foundation
  import SourceLinkCore
  import Testing

  @MainActor
  struct SettingsPreviewTests {
    @Test
    func `preview edits remain in memory without creating configuration`() async throws {
      let store = SettingsStore(previewSettings: SourceSettings())
      let file = store.repository.file
      let directory = file.deletingLastPathComponent()
      // Make the isolated destination writable so a broken autosave cannot fail silently.
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      defer { try? FileManager.default.removeItem(at: directory) }
      #expect(!FileManager.default.fileExists(atPath: file.path))
      #expect(!store.canSave)
      #expect(store.setupSnapshot == nil)

      store.settings.defaultEditor = .vscode
      store.settings.checkouts.append(Checkout(name: "example", path: "/workspace/example", isDefault: true))
      store.settings.rules.append(FileRule())
      store.settings.editors[Editor.xcode.rawValue]?.executable = "/usr/local/bin/custom-xed"

      // Pass both the 500 ms autosave debounce and the 1 second watcher interval.
      try await Task.sleep(for: .milliseconds(1200))

      #expect(store.settings.defaultEditor == .vscode)
      #expect(store.settings.checkouts.count == 1)
      #expect(store.settings.rules.count == 1)
      #expect(store.settings.editors[Editor.xcode.rawValue]?.executable == "/usr/local/bin/custom-xed")
      #expect(!store.canSave)
      #expect(store.setupSnapshot == nil)
      #expect(store.errorMessage == nil)
      #expect(store.saveError == nil)
      #expect(!FileManager.default.fileExists(atPath: file.path))
    }
  }
#endif
