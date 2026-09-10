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
      directory.appendingPathComponent("settings.json").path
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

  func testSettingsNavigationAndRulePersistence() {
    let window = app.windows["Source Link Settings"]
    XCTAssertTrue(window.waitForExistence(timeout: 10))
    for page in ["Repositories", "Editors", "File Rules"] {
      window.descendants(matching: .any)["settings.page.\(page)"].firstMatch.click()
      XCTAssertTrue(window.staticTexts["settings.heading.\(page)"].waitForExistence(timeout: 5))
      let snapshot = XCTAttachment(screenshot: app.windows["Source Link Settings"].screenshot())
      snapshot.name = page
      snapshot.lifetime = .keepAlways
      add(snapshot)
    }
    window.buttons["Add Rule"].click()
    let field = window.textFields["Extension"].firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.click()
    field.typeText("uitest")
    window.descendants(matching: .any)["settings.page.Editors"].firstMatch.click()
    app.terminate()
    app.launch()
    XCTAssertTrue(window.waitForExistence(timeout: 10))
    window.descendants(matching: .any)["settings.page.File Rules"].firstMatch.click()
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    XCTAssertEqual(field.value as? String, "uitest")
  }

  func testPopulatedSettingsActionsAndPersistence() throws {
    app.terminate()
    let fixture: [String: Any] = [
      "checkouts": [
        ["id": UUID().uuidString, "name": "source-link", "path": "/workspace/source-link", "isDefault": true],
        ["id": UUID().uuidString, "name": "source-link", "path": "/worktrees/settings", "isDefault": false]
      ],
      "defaultEditor": "xcode", "executablePaths": [:],
      "rules": [
        ["id": UUID().uuidString, "fileExtension": "swift", "editor": "xcode"],
        ["id": UUID().uuidString, "fileExtension": "md", "editor": "vscode"]
      ]
    ]
    try JSONSerialization.data(withJSONObject: fixture).write(to: directory.appendingPathComponent("settings.json"))
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
    window.descendants(matching: .any)["Actions for rule 2"].firstMatch.click()
    app.menuItems["Move Up"].click()
    XCTAssertEqual(window.textFields["File extension for rule 1"].value as? String, "md")
    capture(window, name: "File Rules populated")
    app.terminate()
    app.launch()
    XCTAssertTrue(window.waitForExistence(timeout: 10))
    let saved = try XCTUnwrap(JSONSerialization.jsonObject(with:
      Data(contentsOf: directory.appendingPathComponent("settings.json"))) as? [String: Any])
    let checkouts = try XCTUnwrap(saved["checkouts"] as? [[String: Any]])
    XCTAssertEqual(checkouts.map { $0["isDefault"] as? Bool }, [false, true])
    window.descendants(matching: .any)["settings.page.Editors"].firstMatch.click()
    XCTAssertTrue(executable.waitForExistence(timeout: 5))
    XCTAssertEqual(executable.value as? String, "/tmp/custom-xed")
    capture(window, name: "Editors populated")
    window.descendants(matching: .any)["Use Default Path"].firstMatch.click()
    XCTAssertEqual(executable.value as? String, "/usr/bin/xed")
    window.descendants(matching: .any)["settings.page.File Rules"].firstMatch.click()
    XCTAssertEqual(window.textFields["File extension for rule 1"].value as? String, "md")
    window.descendants(matching: .any)["Actions for rule 1"].firstMatch.click()
    app.menuItems["Remove Rule"].click()
    XCTAssertEqual(window.textFields["File extension for rule 1"].value as? String, "swift")
  }

  private func capture(_ window: XCUIElement, name: String) {
    let snapshot = XCTAttachment(screenshot: window.screenshot())
    snapshot.name = name
    snapshot.lifetime = .keepAlways
    add(snapshot)
  }

}
