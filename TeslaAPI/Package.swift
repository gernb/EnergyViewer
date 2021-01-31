// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TeslaAPI",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
        .macOS(.v10_15),
    ],
    products: [
        .library(
            name: "TeslaAPI",
            targets: ["TeslaAPI"]),
    ],
    dependencies: [
        .package(name: "OAuthSwift", url: "https://github.com/OAuthSwift/OAuthSwift.git", .upToNextMajor(from: "2.1.0"))
    ],
    targets: [
        .target(
            name: "TeslaAPI",
            dependencies: ["OAuthSwift"]),
    ]
)
