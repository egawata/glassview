// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GlassView",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "GlassView",
            targets: ["TransparentWindowCapture"]
        ),
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "TransparentWindowCapture",
            dependencies: [],
            path: "TransparentWindowCapture"
        ),
    ]
)
