// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "MoreKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "MoreKit",
            targets: ["MoreKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/SnapKit/SnapKit", .upToNextMajor(from: "5.7.0")),
    ],
    targets: [
        .target(
            name: "MoreKit",
            dependencies: ["SnapKit"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "MoreKitTests",
            dependencies: ["MoreKit"]
        ),
    ]
)
