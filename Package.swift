// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Breathe",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(
            name: "Breathe",
            targets: ["Breathe"]
        ),
    ],
    // Package.swift
targets: [
    .target(
        name: "Breathe",
        path: "Breathe",
        exclude: ["Resources", "AppIcon.png", "Assets.xcassets"] // Exclude them from SPM handling
    ),
]
)
