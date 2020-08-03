// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TITransitions",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "TITransitions",
            targets: ["TITransitions"]),
    ],
    targets: [
        .target(
            name: "TITransitions",
            path: "Sources"),
    ]
)
