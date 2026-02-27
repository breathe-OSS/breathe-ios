// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Breathe",
    platforms: [
        .iOS(.v16),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "Breathe",
            targets: ["Breathe"]
        ),
    ],
    targets: [
        .target(
            name: "Breathe",
            path: "Breathe"
        ),
    ]
)
