// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MallocInterposerSwift",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "MallocInterposerSwift",
            type: .dynamic,
            targets: ["MallocInterposerSwift"])
    ],
    dependencies: [
        .package(path: "../MallocInterposerC"),
        .package(url: "https://github.com/apple/swift-atomics.git", from: "1.3.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "MallocInterposerSwift",
            dependencies: [
                .product(name: "MallocInterposerC", package: "MallocInterposerC"),
                .product(name: "Atomics", package: "swift-atomics"),
            ]),
        .executableTarget(
            name: "SwiftTestClient",
            dependencies: ["MallocInterposerSwift"]
        ),
    ]
)
