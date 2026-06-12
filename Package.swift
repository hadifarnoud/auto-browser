// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "AutoBrowser",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(name: "AutoBrowserCore"),
        .executableTarget(
            name: "AutoBrowser",
            dependencies: ["AutoBrowserCore"]
        ),
        .testTarget(
            name: "AutoBrowserCoreTests",
            dependencies: ["AutoBrowserCore"]
        ),
    ]
)
