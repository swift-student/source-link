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
    .package(url: "https://github.com/swift-student/swift-source-symbols.git",
             revision: "45806930ed38d81167a45cb8681e00dfa8e2aabb")
  ],
  targets: [
    .target(name: "SourceLinkCore", dependencies: [
      .product(name: "SourceSymbols", package: "swift-source-symbols")
    ], resources: [.process("Resources")]),
    .executableTarget(name: "SourceLinkCLI", dependencies: ["SourceLinkCore"]),
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
