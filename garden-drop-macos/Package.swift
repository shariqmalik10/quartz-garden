// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "GardenDrop",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "GardenDrop",
            targets: ["GardenDrop"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "GardenDrop",
            path: "Sources/GardenDrop"
        ),
        .testTarget(
            name: "GardenDropTests",
            dependencies: ["GardenDrop"],
            path: "Tests/GardenDropTests"
        ),
    ]
)
