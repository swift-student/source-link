import Foundation
import Testing
@testable import XedLinkCore

@Suite
struct RepositorySettingsTests {
  @Test func worktreesKeepTheSharedRootName() throws {
    var settings = SourceSettings()
    settings.addCheckout(root: URL(fileURLWithPath: "/workspace/source-link"))
    settings.addCheckout(root: URL(fileURLWithPath: "/worktrees/settings-redesign"), repository: "source-link")
    #expect(settings.repositoryNames == ["source-link"])
    #expect(settings.checkouts.map(\.folderName) == ["source-link", "settings-redesign"])
    #expect(settings.checkout(for: "SOURCE-LINK")?.path == "/workspace/source-link")
    settings.setDefaultCheckout(settings.checkouts[1].id)
    let link = try SourceLink(#require(URL(string: "source-link://source-link/Sources/App.swift")))
    #expect(settings.checkout(for: link.repository)?.path == "/worktrees/settings-redesign")
    #expect(settings.checkouts.filter(\.isDefault).count == 1)
    #expect(settings.checkout(for: "settings-redesign") == nil)
  }

  @Test func removingDefaultPromotesAnotherCheckout() {
    var settings = SourceSettings()
    settings.addCheckout(root: URL(fileURLWithPath: "/workspace/repo"))
    settings.addCheckout(root: URL(fileURLWithPath: "/worktrees/feature"), repository: "repo")
    settings.addCheckout(root: URL(fileURLWithPath: "/workspace/other"))
    settings.removeCheckout(settings.checkouts[0].id)
    #expect(settings.checkout(for: "repo")?.folderName == "feature")
    #expect(settings.checkout(for: "repo")?.isDefault == true)
    #expect(settings.checkout(for: "other")?.isDefault == true)
    settings.removeRepository("REPO")
    #expect(settings.repositoryNames == ["other"])
  }

  @Test func normalizesDefaultsWithoutRenamingRepositories() throws {
    var settings = SourceSettings()
    settings.checkouts = [
      Checkout(name: "ExistingAlias", path: "/one"),
      Checkout(name: "existingalias", path: "/two"),
      Checkout(name: "Other", path: "/three", isDefault: true),
      Checkout(name: "other", path: "/four", isDefault: true)
    ]
    settings.normalizeDefaults()
    #expect(settings.checkouts.map(\.isDefault) == [true, false, true, false])
    #expect(settings.repositoryNames == ["ExistingAlias", "Other"])
    let normalized = settings
    settings.normalizeDefaults()
    #expect(settings == normalized)
    #expect(try JSONDecoder().decode(SourceSettings.self, from: JSONEncoder().encode(settings)) == normalized)
  }

  @Test func addingDuplicateDoesNotChangeDefault() {
    var settings = SourceSettings()
    settings.addCheckout(root: URL(fileURLWithPath: "/workspace/repo"))
    settings.addCheckout(root: URL(fileURLWithPath: "/worktrees/feature"), repository: "repo")
    settings.setDefaultCheckout(settings.checkouts[1].id)
    settings.addCheckout(root: URL(fileURLWithPath: "/workspace/repo"), repository: "REPO")
    #expect(settings.checkouts.count == 2)
    #expect(settings.checkout(for: "repo")?.folderName == "feature")
  }

  @Test func reorderedRulesChangePrecedenceAndPersist() throws {
    var settings = SourceSettings()
    var first = FileRule()
    first.fileExtension = ".SWIFT"
    var second = FileRule()
    second.fileExtension = "swift"
    second.editor = .cursor
    settings.rules = [first, second]
    let file = URL(fileURLWithPath: "/repo/File.swift")
    #expect(settings.editor(for: file) == .xcode)
    settings.rules.swapAt(0, 1)
    let restored = try JSONDecoder().decode(SourceSettings.self, from: JSONEncoder().encode(settings))
    #expect(restored.editor(for: file) == .cursor)
  }
}
