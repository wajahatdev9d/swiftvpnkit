// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "VPNKit",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "VPNKit", targets: ["VPNKit"]),
        .library(name: "VPNKitTunnel", targets: ["VPNKitTunnel"]),
        .library(name: "VPNKitPersonal", targets: ["VPNKitPersonal"])
    ],
    dependencies: [],
    targets: [
        .binaryTarget(
            name: "PartoutNative",
            path: "PartoutNative.xcframework"
        ),
        .target(
            name: "PartoutCore_C",
            path: "Sources/PartoutCore_C"
        ),
        .target(
            name: "PartoutCore",
            dependencies: ["PartoutCore_C"],
            path: "Sources/PartoutCore"
        ),
        .target(
            name: "PartoutRuntime",
            dependencies: ["PartoutCore", "PartoutNative"],
            path: "Sources/PartoutRuntime"
        ),
        .target(
            name: "VPNKit",
            dependencies: ["PartoutRuntime"]
        ),
        .target(
            name: "VPNKitTunnel",
            dependencies: ["PartoutRuntime", "VPNKit"]
        ),
        .target(
            name: "VPNKitPersonal",
            dependencies: []
        )
    ],
    swiftLanguageModes: [.v6]
)
