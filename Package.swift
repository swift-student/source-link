// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "XedLinkPackage",
  platforms: [
    .macOS(.v15),
  ],
  products: [
    .library(name: "XedLinkCore", targets: ["XedLinkCore"]),
    .executable(name: "source-link", targets: ["SourceLinkCLI"]),
  ],
  targets: [
    .target(name: "CTOML", publicHeadersPath: "include"),
    .target(name: "XedLinkCore", dependencies: ["CTOML"]),
    .executableTarget(name: "SourceLinkCLI", dependencies: ["XedLinkCore"]),
    .testTarget(
      name: "XedLinkCoreTests",
      dependencies: [
        "XedLinkCore",
      ]
    ),
  ],
  swiftLanguageModes: [.v6],
  cxxLanguageStandard: .cxx17
)
