// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Tipsy",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(
            name: "TipsyKit",
            path: "Sources/TipsyKit"
        ),
        .executableTarget(
            name: "Tipsy",
            dependencies: ["TipsyKit"],
            path: "Sources/Tipsy"
        ),
        .executableTarget(
            name: "TipsyCheck",
            dependencies: ["TipsyKit"],
            path: "Tests/TipsyCheck"
        )
    ]
)
