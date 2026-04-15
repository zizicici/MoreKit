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
        .package(url: "https://github.com/zizicici/AppInfo", .upToNextMajor(from: "1.3.0")),
    ],
    targets: [
        .target(
            name: "MoreKit",
            dependencies: ["SnapKit", "AppInfo"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "MoreKitTests",
            dependencies: ["MoreKit"]
        ),
    ]
)
