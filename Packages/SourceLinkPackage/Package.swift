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
             revision: "15b37e31f0682015089c194c1846e16aaf7de865")
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
