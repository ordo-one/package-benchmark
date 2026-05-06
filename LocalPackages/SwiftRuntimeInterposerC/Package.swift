// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "SwiftRuntimeInterposerC",
    products: [
        .library(
            name: "SwiftRuntimeInterposerC",
            type: .dynamic,
            targets: ["SwiftRuntimeInterposerC"]
        ),
    ],
    targets: [
        .target(
            name: "SwiftRuntimeInterposerC",
            linkerSettings: [
                .linkedLibrary("dl", .when(platforms: [.linux])),
            ]
        ),
    ]
)
