// swift-tools-version: 5.7

import class Foundation.ProcessInfo
import PackageDescription

// If the environment variable BENCHMARK_DISABLE_JEMALLOC is set, we'll build the package without Jemalloc support
let disableJemalloc = ProcessInfo.processInfo.environment["BENCHMARK_DISABLE_JEMALLOC"]

let package = Package(
    name: "Benchmark",
    platforms: [.macOS(.v13)],
    products: [
        .plugin(name: "BenchmarkCommandPlugin", targets: ["BenchmarkCommandPlugin"]),
        .plugin(name: "BenchmarkPlugin", targets: ["BenchmarkPlugin"]),
        .library(
            name: "Benchmark",
            targets: ["Benchmark"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-system", .upToNextMajor(from: "1.2.0")),
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMajor(from: "1.1.0")),
        .package(url: "https://github.com/swift-extras/swift-extras-json", .upToNextMajor(from: "0.6.0")),
//        .package(url: "https://github.com/SwiftPackageIndex/SPIManifest", from: "0.12.0"),
        .package(url: "https://github.com/ordo-one/TextTable", .upToNextMajor(from: "0.0.1")),
        .package(url: "https://github.com/ordo-one/package-datetime", .upToNextMajor(from: "0.0.0")),
        .package(url: "https://github.com/ordo-one/package-histogram", .upToNextMajor(from: "0.0.1")),
        .package(url: "https://github.com/ordo-one/Progress.swift", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/apple/swift-docc-plugin", .upToNextMajor(from: "1.1.0")),
        .package(url: "https://github.com/apple/swift-atomics", .upToNextMajor(from: "1.0.0")),
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
                "BenchmarkTool",
            ],
            path: "Plugins/BenchmarkCommandPlugin"
        ),

        // Plugin that generates the boilerplate needed to interface with the Benchmark infrastructure
        .plugin(
            name: "BenchmarkPlugin",
            capability: .buildTool(),
            dependencies: [
                "BenchmarkBoilerplateGenerator",
            ],
            path: "Plugins/BenchmarkPlugin"
        ),

        // Tool that the plugin executes to perform the actual work, the real benchmark driver
        .executableTarget(
            name: "BenchmarkTool",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SystemPackage", package: "swift-system"),
                .product(name: "ExtrasJSON", package: "swift-extras-json"),
                .product(name: "TextTable", package: "TextTable"),
                "Benchmark",
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
            ],
            path: "Plugins/BenchmarkHelpGenerator"
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

        // Hooks for ARC
        .target(name: "SwiftRuntimeHooks"),

        .testTarget(
            name: "BenchmarkTests",
            dependencies: ["Benchmark"]
        ),
    ]
)
// Check if this is a SPI build, then we need to disable jemalloc for macOS

let macOSSPIBuild: Bool // Disables jemalloc for macOS SPI builds as the infrastructure doesn't have jemalloc there

#if os(macOS)
if let spiBuildEnvironment = ProcessInfo.processInfo.environment["SPI_BUILD"], spiBuildEnvironment == "1" {
    macOSSPIBuild = true
    print("Building for SPI@macOS, disabling Jemalloc")
} else {
    macOSSPIBuild = false
}
#else
macOSSPIBuild = false
#endif

// Add Benchmark target dynamically

// Shared dependencies
var dependencies: [PackageDescription.Target.Dependency] = [
    .product(name: "Histogram", package: "package-histogram"),
    .product(name: "ArgumentParser", package: "swift-argument-parser"),
    .product(name: "ExtrasJSON", package: "swift-extras-json"),
    .product(name: "SystemPackage", package: "swift-system"),
    .product(name: "DateTime", package: "package-datetime"),
    .product(name: "Progress", package: "Progress.swift"),
    .byNameItem(name: "CDarwinOperatingSystemStats", condition: .when(platforms: [.macOS])),
    .byNameItem(name: "CLinuxOperatingSystemStats", condition: .when(platforms: [.linux])),
    .product(name: "Atomics", package: "swift-atomics"),
    "SwiftRuntimeHooks",
]

if macOSSPIBuild == false { // jemalloc always disable for macOSSPIBuild
    if let disableJemalloc, disableJemalloc != "false", disableJemalloc != "0" {
        print("Jemalloc disabled through environment variable.")
    } else {
        package.dependencies += [.package(url: "https://github.com/ordo-one/package-jemalloc", .upToNextMajor(from: "1.0.0"))]
        dependencies += [.product(name: "jemalloc", package: "package-jemalloc")]
    }
}

package.targets += [.target(name: "Benchmark", dependencies: dependencies)]

// Add benchmark targets separately

// Benchmark of the DateTime package (which can't depend on Benchmark as we'll get a circular dependency)
package.targets += [
    .executableTarget(
        name: "BenchmarkDateTime",
        dependencies: [
            "Benchmark",
        ],
        path: "Benchmarks/DateTime",
        plugins: [
            "BenchmarkPlugin"
        ]
    )
]

// Benchmark of the benchmark package
package.targets += [
    .executableTarget(
        name: "Basic",
        dependencies: [
            "Benchmark",
        ],
        path: "Benchmarks/Basic",
        plugins: [
            "BenchmarkPlugin"
        ]
    ),
]

// Benchmark of the Histogram package
package.targets += [
    .executableTarget(
        name: "HistogramBenchmark",
        dependencies: [
            "Benchmark",
            .product(name: "Histogram", package: "package-histogram"),
        ],
        path: "Benchmarks/Histogram",
        plugins: [
            "BenchmarkPlugin"
        ]
    ),
]
