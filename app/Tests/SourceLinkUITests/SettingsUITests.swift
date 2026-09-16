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

  func testConfigurationErrorAlertAndRecovery() throws {
    let window = app.windows["Source Link Settings"]
    XCTAssertTrue(window.waitForExistence(timeout: 10))
    XCTAssertFalse(window.staticTexts["settings.save.status"].exists)
    XCTAssertFalse(window.buttons["settings.discard"].exists)
    let file = directory.appendingPathComponent("config.json")
    try Data("invalid JSON".utf8).write(to: file)
    let reset = window.sheets.buttons.matching(identifier: "Back Up & Reset Settings").firstMatch
    XCTAssertTrue(reset.waitForExistence(timeout: 5))
    XCTAssertTrue(window.sheets.buttons["Open Configuration…"].exists)
    let screenshot = XCTAttachment(screenshot: window.screenshot())
    screenshot.name = "Settings recovery alert"
    screenshot.lifetime = .keepAlways
    add(screenshot)
    reset.click()
    waitForSavedSettings { $0.hasSameConfiguration(as: SourceSettings()) }
    XCTAssertTrue(reset.waitForNonExistence(timeout: 5))
    let backups = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
      .filter { $0.lastPathComponent.contains(".backup-") }
    XCTAssertEqual(backups.count, 1)
    XCTAssertEqual(try String(contentsOf: XCTUnwrap(backups.first), encoding: .utf8), "invalid JSON")
    app.terminate()
    app.launch()
    XCTAssertTrue(window.waitForExistence(timeout: 10))
    XCTAssertFalse(reset.exists)
  }

  func testSettingsNavigationAndRulePersistence() {
    let window = app.windows["Source Link Settings"]
    XCTAssertTrue(window.waitForExistence(timeout: 10))
    for page in ["Repositories", "Editors"] {
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
    window.descendants(matching: .any)["settings.page.Editors"].firstMatch.click()
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
    XCTAssertFalse(window.buttons["Remove Rule"].isEnabled)
    window.textFields["File extension for rule 2"].click()
    XCTAssertTrue(window.buttons["Remove Rule"].isEnabled)
    XCTAssertEqual(window.textFields["File extension for rule 1"].value as? String, "swift")
    waitForSavedSettings { $0.checkouts.map(\.isDefault) == [false, true] }
    app.terminate()
    app.launch()
    XCTAssertTrue(window.waitForExistence(timeout: 10))
    let saved = try ConfigurationDocument(text:
      String(contentsOf: directory.appendingPathComponent("config.json"), encoding: .utf8))
    XCTAssertEqual(saved.settings.checkouts.map(\.isDefault), [false, true])
    window.descendants(matching: .any)["settings.page.Editors"].firstMatch.click()
    XCTAssertEqual(window.textFields["File extension for rule 2"].value as? String, "md")
    window.textFields["File extension for rule 2"].click()
    window.buttons["Remove Rule"].click()
    XCTAssertEqual(window.textFields["File extension for rule 1"].value as? String, "swift")
    window.textFields["File extension for rule 1"].click()
    window.buttons["Remove Rule"].click()
    XCTAssertTrue(window.staticTexts["No File Rules"].waitForExistence(timeout: 5))
    XCTAssertFalse(window.buttons["Remove Rule"].isEnabled)
  }

  func testDefaultEditorPersistence() {
    let window = app.windows["Source Link Settings"]
    XCTAssertTrue(window.waitForExistence(timeout: 10))
    window.descendants(matching: .any)["settings.page.Editors"].firstMatch.click()
    let picker = window.popUpButtons["Default editor"]
    XCTAssertTrue(picker.waitForExistence(timeout: 5))
    XCTAssertTrue(window.buttons["Edit Configuration…"].exists)
    XCTAssertFalse(window.textFields["Xcode executable path"].exists)
    picker.click()
    app.menuItems["Cursor"].click()
    waitForSavedSettings { $0.defaultEditor == .cursor }
    app.terminate()
    app.launch()
    XCTAssertTrue(window.waitForExistence(timeout: 10))
    window.descendants(matching: .any)["settings.page.Editors"].firstMatch.click()
    XCTAssertEqual(picker.value as? String, "Cursor")
    XCTAssertTrue(window.staticTexts["All other files"].exists)
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
