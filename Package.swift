// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "soundcore-pull",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "soundcore-pull", path: "Sources/soundcore-pull"),
        .testTarget(name: "soundcore-pullTests", dependencies: ["soundcore-pull"], path: "Tests/soundcore-pullTests"),
    ]
)
