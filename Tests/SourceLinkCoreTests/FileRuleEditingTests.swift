import Foundation
@testable import SourceLinkCore
import Testing

struct FileRuleEditingTests {
  @Test func `new rules avoid normalized extension collisions`() {
    var settings = SourceSettings()
    for value in [".SWIFT", ".TXT", "Extension2", "extension3"] {
      var rule = FileRule()
      rule.fileExtension = value
      settings.rules.append(rule)
    }
    let original = settings.rules
    let added = settings.addFileRule()
    #expect(added.fileExtension == "extension4")
    #expect(settings.rules.dropLast() == original[...])
    #expect(settings.rules.last?.id == added.id)
    #expect(settings.addFileRule().fileExtension == "extension5")
  }

  @Test func `first rule uses the default extension`() {
    var settings = SourceSettings()
    #expect(settings.addFileRule().fileExtension == FileRule().fileExtension)
  }
}
