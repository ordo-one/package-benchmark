// swiftlint:disable all
//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

// Internal Benchmark framework definitions used for communication with host process etc

/// The entry point for defining benchmarks, expected to be overridden by benchmarks you write.
///
/// Annotate a function that returns your benchmarks with `@_dynamicReplacement(for: registerBenchmarks)`
/// to override this function. The following code shows a minimal benchmark structure.
/// ```swift
/// @_dynamicReplacement(for: registerBenchmarks)
/// func benchmarks() {
///     Benchmark("Minimal benchmark") { benchmark in
///     }
/// }
/// ```
public dynamic func registerBenchmarks() {
    print("This function must be dynamically replaced using @_dynamicReplacement")
}

/// The entry point for defining benchmarks setup, expected to be overridden by the setup you write.
///
/// Annotate a function that returns your benchmarks with `@_dynamicReplacement(for: setupBenchmarks)`
/// to override this function. The following code shows a minimal benchmark structure.
/// ```swift
/// @_dynamicReplacement(for: setupBenchmarks)
/// func setup() {
///     try Benchmark("Minimal benchmark") { benchmark in
///     }
/// }
/// ```
public dynamic func setupBenchmarks() {
    print("This function must be dynamically replaced using @_dynamicReplacement")
}

/// The entry point for defining benchmarks teardown, expected to be overridden by the teardown you write.
///
/// Annotate a function that returns your benchmarks with `@_dynamicReplacement(for: teardownBenchmarks)`
/// to override this function. The following code shows a minimal benchmark structure.
/// ```swift
/// @_dynamicReplacement(for: teardownBenchmarks)
/// func teardown() {
///     try Benchmark("Minimal benchmark") { benchmark in
///     }
/// }
/// ```
public dynamic func teardownBenchmarks() {
    print("This function must be dynamically replaced using @_dynamicReplacement")
}

// Command sent from benchmark runner to the benchmark under measurement
#if swift(>=5.8)
    @_documentation(visibility: internal)
#endif
public enum BenchmarkCommandRequest: Codable {
    case list
    case run(benchmark: Benchmark)
    case end // exit the benchmark
}

// Replies from benchmark under measure to benchmark runner
#if swift(>=5.8)
    @_documentation(visibility: internal)
#endif
public enum BenchmarkCommandReply: Codable {
    case list(benchmark: Benchmark)
    case ready
    case result(benchmark: Benchmark, results: [BenchmarkResult]) // receives results from built-in metric collectors
    case run
    case end // end of query for list/result
    case error(_ description: String) // error while performing operation (e.g. 'run')
}
