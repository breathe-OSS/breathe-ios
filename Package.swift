// SPDX-License-Identifier: MIT
/*
 * Package.swift
 *
 * Copyright (C) 2026           sidharthify <wednisegit@gmail.com>
 * Copyright (C) 2026           SleeperOfSaturn <sanidhya1998@icloud.com>
 */

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
    // Package.swift
targets: [
    .target(
        name: "Breathe",
        path: "Breathe",
        exclude: ["Resources", "AppIcon.png", "Assets.xcassets"] // Exclude them from SPM handling
    ),
]
)
