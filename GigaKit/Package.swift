// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GigaKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ProbeKit", targets: ["ProbeKit"]),
        .library(name: "GigaCore", targets: ["GigaCore"]),
    ],
    targets: [
        .target(name: "ProbeKit"),
        .target(name: "GigaCore", dependencies: ["ProbeKit"]),
        .testTarget(name: "ProbeKitTests", dependencies: ["ProbeKit"]),
        .testTarget(name: "GigaCoreTests", dependencies: ["GigaCore", "ProbeKit"]),
    ]
)
