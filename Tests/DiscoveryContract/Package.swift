// swift-tools-version: 6.0
import PackageDescription

// run.py stages the unmodified production sources with a memory-only Keychain double.
let package = Package(
    name: "DiscoveryContract",
    platforms: [.macOS(.v14), .iOS(.v17)],
    targets: [
        .target(name: "DiscoveryContract", path: "Sources"),
        .testTarget(name: "DiscoveryContractTests", dependencies: ["DiscoveryContract"], path: "Tests"),
    ]
)
