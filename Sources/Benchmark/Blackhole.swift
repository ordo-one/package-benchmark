// ===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Collections open source project
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
// ===----------------------------------------------------------------------===//

// Borrowed from Swift Collections Benchmark, thanks!

/// A function to foil compiler optimizations that would otherwise optimize out code you want to benchmark.
///
/// The function wraps another object or function, does nothing, and returns.
/// If you want to benchmark the time is takes to create an instance and you don't maintain a reference to it, the compiler may optimize it out entirely, thinking it is unused.
/// To prevent the compiler from removing the code you want to measure, wrap the creation of the instance with `blackHole`.
/// For example, the following code benchmarks the time it takes to create an instance of `Date`, and wraps the creation of the instance to prevent the compiler from optimizing it away:
///
/// ```swift
/// Benchmark("Foundation Date()",
///     configuration: .init(
///         metrics: [.throughput, .wallClock],
///         scalingFactor: .mega)
/// ) { benchmark in
///     for _ in benchmark.scaledIterations {
///         blackHole(Date())
///     }
/// }
/// ```
@inline(never)
public func blackHole(_: some Any) {}

@inline(never)
public func identity<T>(_ value: T) -> T {
    value
}
