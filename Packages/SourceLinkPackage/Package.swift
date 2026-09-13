// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "SourceLinkPackage",
  platforms: [
    .macOS(.v15)
  ],
  products: [
    .library(name: "SourceLinkCore", type: .static, targets: ["SourceLinkCore"]),
    .executable(name: "source-link", targets: ["SourceLinkCLI"])
  ],
  dependencies: [
    .package(url: "https://github.com/jpsim/SourceKitten.git", from: "0.38.0")
  ],
  targets: [
    .target(name: "SourceLinkCore", dependencies: [
      .product(name: "SourceKittenFramework", package: "SourceKitten")
    ], resources: [.process("Resources")]),
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
