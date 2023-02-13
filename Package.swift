// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "Benchmark",
    platforms: [.macOS(.v13)],
    products: [
        .plugin(name: "Benchmark-Plugin", targets: ["Benchmark-Plugin"]),
        .library(
            name: "BenchmarkSupport",
            targets: ["BenchmarkSupport"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-system", .upToNextMajor(from: "1.2.0")),
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/apple/swift-numerics", from: "1.0.0"),
        .package(url: "https://github.com/swift-extras/swift-extras-json", .upToNextMajor(from: "0.6.0")),
        .package(url: "https://github.com/SwiftPackageIndex/SPIManifest", from: "0.12.0"),
        .package(url: "https://github.com/ordo-one/TextTable", .upToNextMajor(from: "0.0.1")),
        .package(url: "https://github.com/ordo-one/package-jemalloc", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/ordo-one/package-datetime", .upToNextMajor(from: "0.0.0")),
        .package(url: "https://github.com/ordo-one/package-histogram", .upToNextMajor(from: "0.0.1")),
    ],
    targets: [
        // Plugin used by users of the package
        .plugin(
            name: "Benchmark-Plugin",
            capability: .command(
                intent: .custom(
                    verb: "benchmark",
                    description: "Run the Benchmark performance test suite."
                )
            ),
            dependencies: [
                "BenchmarkTool",
            ],
            path: "Plugins/Benchmark"
        ),
        // Tool that the plugin executes to perform the actual work, the real benchmark driver
        .executableTarget(
            name: "BenchmarkTool",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SystemPackage", package: "swift-system"),
                .product(name: "ExtrasJSON", package: "swift-extras-json"),
                .product(name: "TextTable", package: "TextTable"),
                "Statistics",
                "Benchmark",
            ],
            path: "Plugins/BenchmarkTool"
        ),

        // Internal statistics support
        .target(
            name: "Statistics",
            dependencies: [
                .product(name: "Numerics", package: "swift-numerics"),
                .product(name: "DateTime", package: "package-datetime"),
                .product(name: "Histogram", package: "package-histogram"),
            ]
        ),

        // Benchmark package
        .target(
            name: "Benchmark",
            dependencies: [
                "Statistics",
            ]
        ),

        // Getting OS specific information
        .target(
            name: "CDarwinOperatingSystemStats",
            dependencies: [
            ],
            path: "Platform/CDarwinOperatingSystemStats"
        ),

        // Getting OS specific information
        .target(
            name: "CLinuxOperatingSystemStats",
            dependencies: [
            ],
            path: "Platform/CLinuxOperatingSystemStats"
        ),

        // Benchmark of the benchmark package
        .executableTarget(
            name: "Basic",
            dependencies: [
                "BenchmarkSupport"
            ],
            path: "Benchmarks/Basic"
        ),

        // Benchmark of the DateTime package (which can't depend on Benchmark as we'll get a circular dependency)
        .executableTarget(
            name: "BenchmarkDateTime",
            dependencies: [
                "BenchmarkSupport"
            ],
            path: "Benchmarks/DateTime"
        ),

        // Benchmark of the Histogram package
        .executableTarget(
            name: "HistogramBenchmark",
            dependencies: [
                "BenchmarkSupport",
                .product(name: "Histogram", package: "package-histogram"),
            ],
            path: "Benchmarks/Histogram"
        ),

        // Scaffolding to support benchmarks under the hood
        .target(
            name: "BenchmarkSupport",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "ExtrasJSON", package: "swift-extras-json"),
                .product(name: "SystemPackage", package: "swift-system"),
                .product(name: "jemalloc", package: "package-jemalloc"),
                .product(name: "DateTime", package: "package-datetime"),
                "Statistics",
                "Benchmark",
                .byNameItem(name: "CDarwinOperatingSystemStats", condition: .when(platforms: [.macOS])),
                .byNameItem(name: "CLinuxOperatingSystemStats", condition: .when(platforms: [.linux])),
            ]
        ),
        .testTarget(
            name: "BenchmarkTests",
            dependencies: ["BenchmarkSupport"]
        ),
    ]
)
