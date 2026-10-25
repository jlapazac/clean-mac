// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "CleanMac",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CleanMac", targets: ["CleanMac"]),
        .library(name: "CleanMacCore", targets: ["CleanMacCore"]),
    ],
    targets: [
        .target(name: "CleanMacCore"),
        .executableTarget(name: "CleanMac", dependencies: ["CleanMacCore"]),
        .testTarget(name: "CleanMacCoreTests", dependencies: ["CleanMacCore"]),
    ]
)
