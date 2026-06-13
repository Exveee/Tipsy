// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Tipsy",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Tipsy",
            path: "Sources/Tipsy"
        ),
        .testTarget(
            name: "TipsyTests",
            dependencies: ["Tipsy"],
            path: "Tests/TipsyTests"
        )
    ]
)
