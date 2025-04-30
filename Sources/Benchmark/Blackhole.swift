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
@_optimize(none) // Used after tip here: https://forums.swift.org/t/compiler-swallows-blackhole/64305/10 - see also https://github.com/apple/swift/commit/1fceeab71e79dc96f1b6f560bf745b016d7fcdcf
public func blackHole(_: some Any) {}

@_optimize(none) // Used after tip here: https://forums.swift.org/t/compiler-swallows-blackhole/64305/10 - see also https://github.com/apple/swift/commit/1fceeab71e79dc96f1b6f560bf745b016d7fcdcf
public func identity<T>(_ value: T) -> T {
    value
}

/// A more generalized variant of `blackHole` -- forces the compiler to assume that the argument is not only used, but also mutated. 
/// Foils compiler optimizations like const-folding, loop-invariant code motion, and common-subexpression elimination.
/// For example, the `blackHole` does not always suffice for the following benchmark.
/// ```swift
/// Benchmark("Const-folded?",
///     configuration: .init(
///         metrics: [.wallClock, .mallocTotal],
///         scalingFactor: .mega
///     ) { benchmark in
///     let arguments = Arguments()  // set up
///     benchmark.startMeasurement()
///     for _ in benchmark.scaledIterations {
///         blackHole(benchmarkee(arguments)) 
///     }
/// ```
/// If `benchmarkee` is a pure function, i.e. has no side-effects, the above code will get subjected to e.g. loop-invariant code motion.
/// ```swift
/// Benchmark("Const-folded?",
///     configuration: .init(
///         metrics: [.wallClock, .mallocTotal],
///         scalingFactor: .mega
///     ) { benchmark in
///     let arguments = Arguments()  // set up
///     benchmark.startMeasurement()
///     let _result = benchmarkee(arguments)
///     for _ in benchmark.scaledIterations {
///         blackHole(_result)  // no longer benchmarking `benchmarkee`!
///     }
/// ```
/// The correct way to implement this benchmark would then be
/// ```swift
/// Benchmark("Const-folded?",
///     configuration: .init(
///         metrics: [.wallClock, .mallocTotal],
///         scalingFactor: .mega
///     ) { benchmark in
///     var arguments = Arguments()  // set up
///     benchmark.startMeasurement()
///     for _ in benchmark.scaledIterations {
///         clobber(&arguments)
///         blackHole(benchmarkee(arguments)) 
///     }
/// ```
@_optimize(none)
public func clobber(_: UnsafeMutableRawPointer) {}
