// swift-tools-version: 5.9

import class Foundation.ProcessInfo
import PackageDescription

// If the environment variable BENCHMARK_DISABLE_JEMALLOC is set, we'll build the package without Jemalloc support
let disableJemalloc = ProcessInfo.processInfo.environment["BENCHMARK_DISABLE_JEMALLOC"]

let package = Package(
    name: "Benchmarks",
    platforms: [.macOS(.v14), .iOS(.v17)],
    dependencies: [
        .package(path: "../"),
        .package(url: "https://github.com/ordo-one/package-datetime", .upToNextMajor(from: "1.0.1")),
        .package(url: "https://github.com/HdrHistogram/hdrhistogram-swift", .upToNextMajor(from: "0.1.0"))
    ],
    targets: []
)

// Add benchmark targets separately

// Benchmark of the DateTime package (which can't depend on Benchmark as we'll get a circular dependency)
package.targets += [
    .executableTarget(
        name: "BenchmarkDateTime",
        dependencies: [
            .product(name: "Benchmark", package: "package-benchmark"),
            .product(name: "DateTime", package: "package-datetime")
        ],
        path: "Benchmarks/DateTime",
        plugins: [
            .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
        ]
    )
]

// Benchmark of the benchmark package
package.targets += [
    .executableTarget(
        name: "Basic",
        dependencies: [
            .product(name: "Benchmark", package: "package-benchmark")
        ],
        path: "Benchmarks/Basic",
        plugins: [
            .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
        ]
    )
]

// Benchmark of the Histogram package
package.targets += [
    .executableTarget(
        name: "HistogramBenchmark",
        dependencies: [
            .product(name: "Benchmark", package: "package-benchmark"),
            .product(name: "Histogram", package: "hdrhistogram-swift")
        ],
        path: "Benchmarks/Histogram",
        plugins: [
            .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
        ]
    )
]

// Benchmark testing loading of p90 absolute thresholds
package.targets += [
    .executableTarget(
        name: "P90AbsoluteThresholdsBenchmark",
        dependencies: [
            .product(name: "Benchmark", package: "package-benchmark")
        ],
        path: "Benchmarks/P90AbsoluteThresholds",
        plugins: [
            .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
        ]
    )
]
