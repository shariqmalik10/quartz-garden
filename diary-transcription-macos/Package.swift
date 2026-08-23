// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DiaryTranscription",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "DiaryCore", targets: ["DiaryCore"]),
        .executable(name: "DiaryTranscription", targets: ["DiaryTranscription"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/Blaizzy/mlx-audio-swift.git",
            exact: "0.1.3"
        ),
        .package(
            url: "https://github.com/huggingface/swift-huggingface.git",
            exact: "0.9.0"
        )
    ],
    targets: [
        .target(name: "DiaryCore"),
        .executableTarget(
            name: "DiaryTranscription",
            dependencies: [
                "DiaryCore",
                .product(name: "MLXAudioCore", package: "mlx-audio-swift"),
                .product(name: "MLXAudioSTT", package: "mlx-audio-swift"),
                .product(name: "HuggingFace", package: "swift-huggingface")
            ]
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
