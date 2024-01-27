// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TeslaAPI",
    platforms: [
        .iOS(.v17),
        .tvOS(.v16),
        .watchOS(.v7),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "TeslaAPI",
            targets: ["TeslaAPI"]
        ),
    ],
    targets: [
        .target(
            name: "TeslaAPI",
            dependencies: []
        ),
    ]
)
