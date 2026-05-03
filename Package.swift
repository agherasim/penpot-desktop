// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PenpotDesktop",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "DockerStats",
            path: "Sources/DockerStats"
        ),
        .testTarget(
            name: "DockerStatsTests",
            dependencies: ["DockerStats"],
            path: "Tests/DockerStatsTests"
        ),
    ]
)
