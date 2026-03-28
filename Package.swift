// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CopilotAccountant",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "CopilotAccountant",
            targets: ["CopilotAccountant"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "CopilotAccountant",
            dependencies: [],
            path: "Sources")
    ]
)
