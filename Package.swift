// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Benchmark",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .plugin(name: "BenchmarkCommandPlugin", targets: ["BenchmarkCommandPlugin"]),
        .plugin(name: "BenchmarkPlugin", targets: ["BenchmarkPlugin"]),
        .library(
            name: "Benchmark",
            targets: ["Benchmark"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-system.git", .upToNextMajor(from: "1.1.0")),
        .package(url: "https://github.com/apple/swift-argument-parser.git", .upToNextMajor(from: "1.1.0")),
        .package(url: "https://github.com/ordo-one/TextTable.git", .upToNextMajor(from: "0.0.1")),
        .package(url: "https://github.com/HdrHistogram/hdrhistogram-swift.git", .upToNextMajor(from: "0.1.0")),
        .package(url: "https://github.com/apple/swift-atomics.git", .upToNextMajor(from: "1.0.0")),
        .package(path: "LocalPackages/MallocInterposerSwift")
    ],
    targets: [
        // Plugins used by users of the package

        // The actual 'benchmark' command plugin
        .plugin(
            name: "BenchmarkCommandPlugin",
            capability: .command(
                intent: .custom(
                    verb: "benchmark",
                    description: "Run the Benchmark performance test suite."
                )
            ),
            dependencies: [
                "BenchmarkTool"
            ],
            path: "Plugins/BenchmarkCommandPlugin"
        ),

        // Plugin that generates the boilerplate needed to interface with the Benchmark infrastructure
        .plugin(
            name: "BenchmarkPlugin",
            capability: .buildTool(),
            dependencies: [
                "BenchmarkBoilerplateGenerator"
            ],
            path: "Plugins/BenchmarkPlugin"
        ),

        // Tool that the plugin executes to perform the actual work, the real benchmark driver
        .executableTarget(
            name: "BenchmarkTool",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SystemPackage", package: "swift-system"),
                .product(name: "TextTable", package: "TextTable"),
                "Benchmark",
                "BenchmarkShared",
            ],
            path: "Plugins/BenchmarkTool"
        ),

        // Tool that generates the boilerplate
        .executableTarget(
            name: "BenchmarkBoilerplateGenerator",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SystemPackage", package: "swift-system"),
            ],
            path: "Plugins/BenchmarkBoilerplateGenerator"
        ),

        // Tool that simply generates the man page for the BenchmarkPlugin as we can't use SAP in it... :-/
        .executableTarget(
            name: "BenchmarkHelpGenerator",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "BenchmarkShared",
            ],
            path: "Plugins/BenchmarkHelpGenerator"
        ),

        // Getting OS specific information
        .target(
            name: "CDarwinOperatingSystemStats",
            dependencies: [],
            path: "Platform/CDarwinOperatingSystemStats"
        ),

        // Getting OS specific information
        .target(
            name: "CLinuxOperatingSystemStats",
            dependencies: [],
            path: "Platform/CLinuxOperatingSystemStats"
        ),

        // Hooks for ARC
        .target(name: "SwiftRuntimeHooks"),

        // Shared definitions
        .target(name: "BenchmarkShared"),

        .testTarget(
            name: "BenchmarkTests",
            dependencies: ["Benchmark"]
        ),
    ]
)

// Add Benchmark target dynamically
// Shared dependencies
var dependencies: [PackageDescription.Target.Dependency] = [
    .product(name: "Histogram", package: "hdrhistogram-swift"),
    .product(name: "ArgumentParser", package: "swift-argument-parser"),
    .product(name: "SystemPackage", package: "swift-system"),
    .byNameItem(name: "CDarwinOperatingSystemStats", condition: .when(platforms: [.macOS, .iOS])),
    .byNameItem(name: "CLinuxOperatingSystemStats", condition: .when(platforms: [.linux])),
    .product(name: "Atomics", package: "swift-atomics"),
    "SwiftRuntimeHooks",
    "BenchmarkShared",
    "MallocInterposerSwift"
]

package.targets += [.target(name: "Benchmark", dependencies: dependencies)]
