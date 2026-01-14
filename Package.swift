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
                .product(name: "TOMLKit", package: "TOMLKit")
            ],
            path: "Sources/WorkspaceManager"
        )
    ]
)
