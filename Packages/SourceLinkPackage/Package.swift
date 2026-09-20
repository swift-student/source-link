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
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.8.2"),
    .package(url: "https://github.com/swift-student/swift-source-symbols.git",
             from: "0.1.0")
  ],
  targets: [
    .target(name: "SourceLinkCore", dependencies: [
      .product(name: "SourceSymbols", package: "swift-source-symbols")
    ], resources: [.process("Resources")]),
    .executableTarget(name: "SourceLinkCLI", dependencies: [
      "SourceLinkCore",
      .product(name: "ArgumentParser", package: "swift-argument-parser")
    ]),
    .testTarget(name: "SourceLinkCLITests", dependencies: ["SourceLinkCLI"]),
    .testTarget(
      name: "SourceLinkCoreTests",
      dependencies: [
        "SourceLinkCore"
      ]
    )
  ],
  swiftLanguageModes: [.v6]
)
