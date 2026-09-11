import XCTest
import XedLinkCore

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
    if let directory { try FileManager.default.removeItem(at: directory) }
  }

  func testEmptyRepositoriesSnapshot() {
    let window = app.windows["Source Link Settings"]
    XCTAssertTrue(window.waitForExistence(timeout: 10))
    XCTAssertTrue(window.staticTexts["No repositories yet"].exists)
    XCTAssertTrue(window.staticTexts["Connect shared source links to folders on this Mac."].exists)
    XCTAssertEqual(window.buttons.matching(identifier: "repositories.add").count, 1)
    XCTAssertFalse(window.buttons["settings.apply"].exists)
    XCTAssertFalse(window.buttons["Save"].exists)
    XCTAssertTrue(window.buttons["Reveal Configuration"].exists)
    capture(window, name: "Repositories clean empty state")
  }

  func testSettingsNavigationAndRulePersistence() {
    let window = app.windows["Source Link Settings"]
    XCTAssertTrue(window.waitForExistence(timeout: 10))
    for page in ["Repositories", "Editors", "File Rules"] {
      window.descendants(matching: .any)["settings.page.\(page)"].firstMatch.click()
      XCTAssertTrue(window.staticTexts["settings.heading.\(page)"].waitForExistence(timeout: 5))
      capture(window, name: page)
    }
    window.buttons["Add Rule"].click()
    let field = window.textFields["Extension"].firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.click()
    field.typeKey("a", modifierFlags: .command)
    field.typeText("uitest")
    window.descendants(matching: .any)["settings.page.Editors"].firstMatch.click()
    let savedStatus = window.staticTexts["settings.saveStatus"]
    let saved = NSPredicate(
      format: "label BEGINSWITH %@ OR value BEGINSWITH %@", "All changes saved", "All changes saved")
    expectation(for: saved, evaluatedWith: savedStatus)
    waitForExpectations(timeout: 5)
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
    capture(window, name: "Repositories populated")
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
    capture(window, name: "File Rules populated")
    let savedStatus = window.staticTexts["settings.saveStatus"]
    let savedPredicate = NSPredicate(
      format: "label BEGINSWITH %@ OR value BEGINSWITH %@", "All changes saved", "All changes saved")
    expectation(for: savedPredicate, evaluatedWith: savedStatus)
    waitForExpectations(timeout: 5)
    app.terminate()
    app.launch()
    XCTAssertTrue(window.waitForExistence(timeout: 10))
    let saved = try ConfigurationDocument(text:
      String(contentsOf: directory.appendingPathComponent("config.json"), encoding: .utf8))
    XCTAssertEqual(saved.settings.checkouts.map(\.isDefault), [false, true])
    window.descendants(matching: .any)["settings.page.Editors"].firstMatch.click()
    XCTAssertTrue(executable.waitForExistence(timeout: 5))
    XCTAssertEqual(executable.value as? String, "/tmp/custom-xed")
    capture(window, name: "Editors populated")
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

  private func capture(_ window: XCUIElement, name: String) {
    XCTAssertTrue(window.staticTexts["All changes saved"].waitForExistence(timeout: 5))
    SettingsSnapshots.verify(window.screenshot(), named: name, in: self)
  }

}
