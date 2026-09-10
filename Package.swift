// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "XedLinkPackage",
  platforms: [
    .macOS(.v15),
  ],
  products: [
    .library(name: "XedLinkCore", targets: ["XedLinkCore"]),
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.7.3"),
  ],
  targets: [
    .target(name: "XedLinkCore"),
    .testTarget(
      name: "XedLinkCoreTests",
      dependencies: [
        "XedLinkCore",
        .product(name: "CustomDump", package: "swift-custom-dump"),
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)
