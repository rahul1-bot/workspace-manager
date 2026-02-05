// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WorkspaceManager",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "WorkspaceManager", targets: ["WorkspaceManager"])
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.2.0"),
        .package(url: "https://github.com/LebJe/TOMLKit.git", from: "0.6.0")
    ],
    targets: [
        .executableTarget(
            name: "WorkspaceManager",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm"),
                .product(name: "TOMLKit", package: "TOMLKit"),
                "GhosttyKit"
            ],
            path: "Sources/WorkspaceManager",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("CoreText"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("Foundation"),
                .linkedFramework("Carbon"),
                .linkedFramework("AppKit"),
                .linkedFramework("IOKit"),
                .linkedFramework("CoreServices"),
                .linkedLibrary("z"),
                .linkedLibrary("c++")
            ]
        ),
        .testTarget(
            name: "WorkspaceManagerTests",
            dependencies: ["WorkspaceManager"]
        ),
        .binaryTarget(
            name: "GhosttyKit",
            path: "Frameworks/GhosttyKit.xcframework"
        )
    ]
)
