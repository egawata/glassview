// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TransparentWindowCapture",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "TransparentWindowCapture",
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
