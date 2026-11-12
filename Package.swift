// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Margin",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "MarginCore", targets: ["MarginCore"]),
        .library(name: "MarginCommands", targets: ["MarginCommands"]),
        .executable(name: "margin", targets: ["margin"]),
        .executable(name: "MarginApp", targets: ["MarginApp"]),
    ],
    targets: [
        .target(name: "MarginCore"),
        .target(name: "MarginCommands", dependencies: ["MarginCore"]),
        .executableTarget(name: "margin", dependencies: ["MarginCommands"]),
        .executableTarget(name: "MarginApp", dependencies: ["MarginCore"]),
        .testTarget(name: "MarginCoreTests", dependencies: ["MarginCore"]),
        .testTarget(name: "MarginCommandsTests", dependencies: ["MarginCommands", "MarginCore"]),
    ],
    swiftLanguageModes: [.v5]
)
