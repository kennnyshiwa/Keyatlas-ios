// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KeyAtlas",
    platforms: [
        .iOS(.v17),
    ],
    dependencies: [
        .package(url: "https://github.com/kean/Nuke.git", from: "12.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "KeyAtlas",
            dependencies: [
                .product(name: "Nuke", package: "Nuke"),
                .product(name: "NukeUI", package: "Nuke"),
            ],
            path: "Sources/KeyAtlas",
            resources: [
                .process("Resources")
            ]
        ),
    ]
)
