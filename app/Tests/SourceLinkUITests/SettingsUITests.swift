import SourceLinkCore
import XCTest

@MainActor
final class SettingsUITests: XCTestCase {
  private var app: XCUIApplication!
  private var directory: URL!

  override func setUpWithError() throws {
    continueAfterFailure = false
    directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let appURL = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("source-link.app")
    app = XCUIApplication(url: appURL)
    app.launchArguments = ["--settings"]
    app.launchEnvironment["SOURCE_LINK_TEST_SETTINGS_PATH"] =
      directory.appendingPathComponent("config.json").path
    app.launch()
  }

  override func tearDownWithError() throws {
    if let testRun, testRun.failureCount > 0, let app {
      let screenshot = XCTAttachment(screenshot: app.windows["Source Link Settings"].screenshot())
      screenshot.name = "Settings failure"
      screenshot.lifetime = .keepAlways
      add(screenshot)
    }
    app?.terminate()
    if let directory {
      try FileManager.default.removeItem(at: directory)
    }
  }

  func testEmptyRepositoriesActions() {
    let window = app.windows["Source Link Settings"]
    XCTAssertTrue(window.waitForExistence(timeout: 10))
    XCTAssertTrue(window.staticTexts["No repositories yet"].exists)
    XCTAssertTrue(window.staticTexts["Connect shared source links to folders on this Mac."].exists)
    XCTAssertEqual(window.buttons.matching(identifier: "repositories.add").count, 1)
    XCTAssertFalse(window.buttons["settings.apply"].exists)
    XCTAssertFalse(window.buttons["Save"].exists)
    XCTAssertFalse(window.buttons["Reveal File"].exists)
  }

  func testSettingsNavigationAndRulePersistence() {
    let window = app.windows["Source Link Settings"]
    XCTAssertTrue(window.waitForExistence(timeout: 10))
    for page in ["Repositories", "Editors", "File Rules"] {
      window.descendants(matching: .any)["settings.page.\(page)"].firstMatch.click()
      XCTAssertTrue(window.staticTexts["settings.heading.\(page)"].waitForExistence(timeout: 5))
    }
    window.buttons["Add Rule"].click()
    let field = window.textFields["Extension"].firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.click()
    field.typeKey("a", modifierFlags: .command)
    field.typeText("uitest")
    window.descendants(matching: .any)["settings.page.Editors"].firstMatch.click()
    waitForSavedSettings { $0.rules.contains { $0.fileExtension == "uitest" } }
    app.terminate()
    app.launch()
    XCTAssertTrue(window.waitForExistence(timeout: 10))
    window.descendants(matching: .any)["settings.page.File Rules"].firstMatch.click()
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    XCTAssertEqual(field.value as? String, "uitest")
  }

  func testPopulatedSettingsActionsAndPersistence() throws {
    app.terminate()
    try writeFixture()
    app.launch()
    let window = app.windows["Source Link Settings"]
    XCTAssertTrue(window.waitForExistence(timeout: 10))
    window.descendants(matching: .any)["Make Default"].firstMatch.click()
    window.descendants(matching: .any)["settings.page.Editors"].firstMatch.click()
    let executable = window.textFields["Xcode executable path"]
    XCTAssertTrue(executable.waitForExistence(timeout: 5))
    executable.click()
    executable.typeKey("a", modifierFlags: .command)
    executable.typeText("/tmp/custom-xed")
    window.descendants(matching: .any)["settings.page.File Rules"].firstMatch.click()
    XCTAssertFalse(window.buttons["Remove Rule"].isEnabled)
    window.textFields["File extension for rule 2"].click()
    XCTAssertTrue(window.buttons["Remove Rule"].isEnabled)
    XCTAssertEqual(window.textFields["File extension for rule 1"].value as? String, "swift")
    waitForSavedSettings { $0.executablePaths["xcode"] == "/tmp/custom-xed" }
    app.terminate()
    app.launch()
    XCTAssertTrue(window.waitForExistence(timeout: 10))
    let saved = try ConfigurationDocument(text:
      String(contentsOf: directory.appendingPathComponent("config.json"), encoding: .utf8))
    XCTAssertEqual(saved.settings.checkouts.map(\.isDefault), [false, true])
    window.descendants(matching: .any)["settings.page.Editors"].firstMatch.click()
    XCTAssertTrue(executable.waitForExistence(timeout: 5))
    XCTAssertEqual(executable.value as? String, "/tmp/custom-xed")
    window.descendants(matching: .any)["Use Default Path"].firstMatch.click()
    XCTAssertEqual(executable.value as? String, "/usr/bin/xed")
    window.descendants(matching: .any)["settings.page.File Rules"].firstMatch.click()
    XCTAssertEqual(window.textFields["File extension for rule 2"].value as? String, "md")
    window.textFields["File extension for rule 2"].click()
    window.buttons["Remove Rule"].click()
    XCTAssertEqual(window.textFields["File extension for rule 1"].value as? String, "swift")
    window.textFields["File extension for rule 1"].click()
    window.buttons["Remove Rule"].click()
    XCTAssertTrue(window.staticTexts["No File Rules"].exists)
    XCTAssertFalse(window.buttons["Remove Rule"].isEnabled)
  }

  func testEditorRowDisclosureAndDefaultPersistence() {
    let window = app.windows["Source Link Settings"]
    XCTAssertTrue(window.waitForExistence(timeout: 10))
    window.descendants(matching: .any)["settings.page.Editors"].firstMatch.click()
    XCTAssertFalse(window.popUpButtons["Default editor"].exists)
    let collapse = window.buttons["Collapse Xcode"]
    XCTAssertTrue(collapse.waitForExistence(timeout: 5))
    XCTAssertGreaterThanOrEqual(collapse.frame.width, 36)
    XCTAssertGreaterThanOrEqual(collapse.frame.height, 44)
    // Click away from the glyph to exercise the expanded hit target.
    collapse.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)).click()
    XCTAssertFalse(window.textFields["Xcode executable path"].exists)
    window.buttons["Expand Xcode"].click()
    XCTAssertTrue(window.textFields["Xcode executable path"].exists)
    window.buttons["editors.makeDefault.cursor"].click()
    XCTAssertTrue(window.buttons["Expand Cursor"].exists)
    waitForSavedSettings { $0.defaultEditor == .cursor }
    app.terminate()
    app.launch()
    XCTAssertTrue(window.waitForExistence(timeout: 10))
    window.descendants(matching: .any)["settings.page.Editors"].firstMatch.click()
    XCTAssertTrue(window.textFields["Cursor executable path"].waitForExistence(timeout: 5))
    XCTAssertFalse(window.buttons["editors.makeDefault.cursor"].exists)
    window.descendants(matching: .any)["settings.page.File Rules"].firstMatch.click()
    XCTAssertFalse(window.staticTexts["All other files"].exists)
  }

  private func waitForSavedSettings(_ matches: @escaping (SourceSettings) -> Bool) {
    let file = directory.appendingPathComponent("config.json")
    let saved = NSPredicate { _, _ in
      guard let text = try? String(contentsOf: file, encoding: .utf8),
            let document = try? ConfigurationDocument(text: text) else { return false }
      return matches(document.settings)
    }
    expectation(for: saved, evaluatedWith: nil)
    waitForExpectations(timeout: 5)
  }

  private func writeFixture() throws {
    let fixture = """
    {
      "version": 1,
      "checkouts": [
        {
          "name": "source-link",
          "path": "/workspace/source-link",
          "default": true
        },
        {
          "name": "source-link",
          "path": "/worktrees/settings"
        }
      ],
      "rules": [
        {
          "extension": "swift",
          "editor": "xcode"
        },
        {
          "extension": "md",
          "editor": "vscode"
        }
      ]
    }
    """
    try Data(fixture.utf8).write(to: directory.appendingPathComponent("config.json"))
  }
}
