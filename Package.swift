// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "NCCCoding",
    platforms: [
        .iOS(.v12),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "NCCCoding",
            targets: ["NCCCoding"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "NCCCoding",
            dependencies: []),
        .testTarget(
            name: "NCCCodingTests",
            dependencies: ["NCCCoding"]),
    ]
)
