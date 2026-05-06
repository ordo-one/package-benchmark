// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "SwiftRuntimeInterposerSwift",
    products: [
        .library(
            name: "SwiftRuntimeInterposerSwift",
            type: .dynamic,
            targets: ["SwiftRuntimeInterposerSwift"]
        ),
    ],
    dependencies: [
        .package(path: "../SwiftRuntimeInterposerC"),
    ],
    targets: [
        .target(
            name: "SwiftRuntimeInterposerSwift",
            dependencies: [
                .product(name: "SwiftRuntimeInterposerC", package: "SwiftRuntimeInterposerC"),
            ]
        ),
    ]
)
