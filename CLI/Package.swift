// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ReadabilityCLI",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(path: ".."),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")
    ],
    targets: [
        .executableTarget(
            name: "ReadabilityCLI",
            dependencies: [
                .product(name: "Readability", package: "readability"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        )
    ]
)
