import AppKit
import SwiftUI
import XedLinkCore

@MainActor
final class SettingsStore: ObservableObject {
  @Published var settings = SourceSettings()
  private let storage: URL

  init() {
    #if DEBUG
    if let path = ProcessInfo.processInfo.environment["SOURCE_LINK_TEST_SETTINGS_PATH"] {
      storage = URL(fileURLWithPath: path)
    } else {
      storage = URL.applicationSupportDirectory.appendingPathComponent("SourceLink/settings.json")
    }
    #else
    storage = URL.applicationSupportDirectory.appendingPathComponent("SourceLink/settings.json")
    #endif
    do {
      if FileManager.default.fileExists(atPath: storage.path) {
        settings = try JSONDecoder().decode(SourceSettings.self, from: Data(contentsOf: storage))
        let previous = settings
        settings.normalizeDefaults()
        if settings != previous { save() }
      }
    } catch { Self.show(error) }
  }

  func save() {
    do {
      try FileManager.default.createDirectory(at: storage.deletingLastPathComponent(),
                                             withIntermediateDirectories: true)
      try JSONEncoder().encode(settings).write(to: storage, options: .atomic)
    } catch { Self.show(error) }
  }

  static func show(_ error: Error) {
    let alert = NSAlert(error: error)
    NSApp.activate(ignoringOtherApps: true)
    alert.runModal()
  }
}
