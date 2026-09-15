import Foundation
@testable import SourceLinkCore
import Testing

struct BundledCLIResourcesTests {
  @Test func `finds app resources through a command symlink`() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let contents = root.appendingPathComponent("source-link.app/Contents")
    let executable = contents.appendingPathComponent("Helpers/source-link")
    let resources = contents.appendingPathComponent("Resources/SourceLinkPackage_SourceLinkCore.bundle")
    try FileManager.default.createDirectory(
      at: executable.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
    try Data().write(to: executable)
    try Data("{}".utf8).write(to: resources.appendingPathComponent("editors.json"))
    let command = root.appendingPathComponent("source-link")
    try FileManager.default.createSymbolicLink(at: command, withDestinationURL: executable)
    let bundle = try #require(EditorProfile.helperResourceBundle(executable: command))
    #expect(bundle.url(forResource: "editors", withExtension: "json")?.resolvingSymlinksInPath()
      == resources.appendingPathComponent("editors.json").resolvingSymlinksInPath())
    #expect(EditorProfile.helperResourceBundle(executable: nil) == nil)
    #expect(EditorProfile.helperResourceBundle(executable: root.appendingPathComponent("standalone")) == nil)
  }
}
