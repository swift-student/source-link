import Foundation
@testable import SourceLinkCore
import Testing

struct XcodeProjectDiscoveryTests {
  @Test(arguments: [
    (["App.xcworkspace", "App.xcodeproj", "Package.swift"], "App.xcworkspace"),
    (["App.xcodeproj", "Package.swift"], "App.xcodeproj"),
    (["Package.swift"], "Package.swift"),
    ([], nil),
    (["One.xcworkspace", "Two.xcworkspace", "App.xcodeproj"], nil),
    (["One.xcodeproj", "Two.xcodeproj", "Package.swift"], nil),
    (["Nested/App.xcworkspace"], nil)
  ] as [([String], String?)])
  func `routes xcode through preferred root context`(entries: [String], expected: String?) throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    for entry in entries {
      let url = root.appendingPathComponent(entry)
      if entry == "Package.swift" {
        try Data().write(to: url)
      } else {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
      }
    }
    let file = root.appendingPathComponent("A File.swift")
    try Data().write(to: file)
    let link = try SourceLink(#require(URL(string: "source-link://repo/A%20File.swift?line=10")))
    var settings = SourceSettings()
    settings.checkouts = [Checkout(name: "repo", path: root.path)]
    let command = try #require(try settings.command(for: link))
    #expect(command.executable == "/usr/bin/xed")
    let projectArguments = expected.map {
      ["-p", root.appendingPathComponent($0).resolvingSymlinksInPath().path]
    } ?? []
    #expect(command.arguments == projectArguments + ["--line", "10", file.resolvingSymlinksInPath().path])

    settings.defaultEditor = .vscode
    #expect(try settings.command(for: link)?.arguments == [
      "--goto", file.resolvingSymlinksInPath().path + ":10:1"
    ])
  }

  @Test func `ignores invalid project types`() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try Data().write(to: root.appendingPathComponent("NotABundle.xcworkspace"))
    try FileManager.default.createDirectory(
      at: root.appendingPathComponent("Package.swift"), withIntermediateDirectories: true
    )
    #expect(XcodeProjectDiscovery.project(in: root) == nil)
    #expect(XcodeProjectDiscovery.project(in: root.appendingPathComponent("Missing")) == nil)
  }
}
