// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "SourceLinkPackage",
  platforms: [
    .macOS(.v15)
  ],
  products: [
    .library(name: "SourceLinkCore", targets: ["SourceLinkCore"]),
    .executable(name: "source-link", targets: ["SourceLinkCLI"])
  ],
  targets: [
    .target(name: "SourceLinkCore", resources: [.process("Resources")]),
    .executableTarget(name: "SourceLinkCLI", dependencies: ["SourceLinkCore"]),
    .testTarget(
      name: "SourceLinkCoreTests",
      dependencies: [
        "SourceLinkCore"
      ]
    )
  ],
  swiftLanguageModes: [.v6]
)
