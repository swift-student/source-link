import CustomDump
import Foundation
import Testing
@testable import XedLinkCore

@Suite
struct XedURLTests {
  @Test
  func fileLineAndProject() throws {
    let source = try XedURL(
      #require(
        URL(
          string: """
            xed:///tmp/Xed%20Link/App.swift?line=42&project=/tmp/Xed%20Link/XedLink.xcworkspace
            """
        )
      )
    )

    expectNoDifference(
      source.fileURL,
      URL(fileURLWithPath: "/tmp/Xed Link/App.swift")
    )
    expectNoDifference(source.line, 42)
    expectNoDifference(
      source.projectURL,
      URL(fileURLWithPath: "/tmp/Xed Link/XedLink.xcworkspace")
    )
    expectNoDifference(
      source.xedArguments,
      [
        "--project",
        "/tmp/Xed Link/XedLink.xcworkspace",
        "--line",
        "42",
        "/tmp/Xed Link/App.swift"
      ]
    )
  }

  @Test
  func fileOnly() throws {
    let source = try XedURL(#require(URL(string: "xed:///tmp/App.swift")))

    expectNoDifference(source.fileURL, URL(fileURLWithPath: "/tmp/App.swift"))
    expectNoDifference(source.line, nil)
    expectNoDifference(source.projectURL, nil)
    expectNoDifference(source.xedArguments, ["/tmp/App.swift"])
  }

  @Test
  func schemeIsCaseInsensitive() throws {
    let source = try XedURL(#require(URL(string: "XED:///tmp/App.swift")))

    expectNoDifference(source.fileURL, URL(fileURLWithPath: "/tmp/App.swift"))
  }

  @Test
  func rejectsInvalidScheme() throws {
    #expect(throws: XedURLError.invalidScheme) {
      try XedURL(#require(URL(string: "file:///tmp/App.swift")))
    }
  }

  @Test
  func rejectsAuthority() throws {
    #expect(throws: XedURLError.unsupportedURLComponent) {
      try XedURL(#require(URL(string: "xed://host/tmp/App.swift")))
    }
  }

  @Test
  func rejectsRootPath() throws {
    #expect(throws: XedURLError.invalidPath) {
      try XedURL(#require(URL(string: "xed:///")))
    }
  }

  @Test
  func rejectsInvalidLine() throws {
    #expect(throws: XedURLError.invalidLine) {
      try XedURL(#require(URL(string: "xed:///tmp/App.swift?line=0")))
    }
  }

  @Test
  func rejectsDuplicateLine() throws {
    #expect(throws: XedURLError.unsupportedURLComponent) {
      try XedURL(#require(URL(string: "xed:///tmp/App.swift?line=1&line=2")))
    }
  }

  @Test
  func rejectsRelativeProject() throws {
    #expect(throws: XedURLError.invalidProject) {
      try XedURL(#require(URL(string: "xed:///tmp/App.swift?project=Project.xcworkspace")))
    }
  }

  @Test
  func rejectsDuplicateProject() throws {
    #expect(throws: XedURLError.unsupportedURLComponent) {
      try XedURL(
        #require(
          URL(
            string: """
              xed:///tmp/App.swift?project=/tmp/One.xcworkspace&project=/tmp/Two.xcworkspace
              """
          )
        )
      )
    }
  }

  @Test
  func rejectsUnknownQuery() throws {
    #expect(throws: XedURLError.unsupportedURLComponent) {
      try XedURL(#require(URL(string: "xed:///tmp/App.swift?column=2")))
    }
  }

  @Test
  func rejectsFragment() throws {
    #expect(throws: XedURLError.unsupportedURLComponent) {
      try XedURL(#require(URL(string: "xed:///tmp/App.swift#symbol")))
    }
  }
}
