// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DiaryTranscription",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "DiaryCore", targets: ["DiaryCore"]),
        .executable(name: "DiaryTranscription", targets: ["DiaryTranscription"])
    ],
    targets: [
        .target(name: "DiaryCore"),
        .executableTarget(
            name: "DiaryTranscription",
            dependencies: ["DiaryCore"]
        ),
        .testTarget(
            name: "DiaryCoreTests",
            dependencies: ["DiaryCore"]
        ),
        .testTarget(
            name: "DiaryTranscriptionTests",
            dependencies: ["DiaryTranscription", "DiaryCore"]
        )
    ]
)
