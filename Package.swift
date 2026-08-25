// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "SwiftVPNKit",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "SwiftVPNKit", targets: ["SwiftVPNKit"]),
        .library(name: "SwiftVPNKitTunnel", targets: ["SwiftVPNKitTunnel"])
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
        ),
        .target(
            name: "SwiftVPNKit",
            dependencies: ["VPNKit", "VPNKitPersonal"]
        ),
        .target(
            name: "SwiftVPNKitTunnel",
            dependencies: ["VPNKitTunnel"]
        )
    ],
    swiftLanguageModes: [.v6]
)
