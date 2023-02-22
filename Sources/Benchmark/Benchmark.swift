//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

import Dispatch
import Statistics

/// Defines a benchmark
public final class Benchmark: Codable, Hashable {
    public typealias BenchmarkClosure = (_ benchmark: Benchmark) -> Void
    public typealias BenchmarkAsyncClosure = (_ benchmark: Benchmark) async -> Void
    public typealias BenchmarkMeasurementSynchronization = () -> Void
    public typealias BenchmarkCustomMetricMeasurement = (BenchmarkMetric, Int) -> Void

    public static var benchmarks: [Benchmark] = [] // Bookkeeping of all registered benchmarks

    /// The name used for display purposes of the benchmark (also used for matching when comparing to baselines)
    public var name: String

    /// The reason for a benchmark failure, not set if successful
    public var failureReason: String?
    /// The current benchmark iteration (also includes warmup iterations), can be useful when
    /// e.g. unique keys will be needed for different iterations
    public var currentIteration: Int = 0

    /// Convenience range to iterate over for benchmarks
    public var throughputIterations: Range<Int> { 0 ..< configuration.throughputScalingFactor.rawValue }

    /// Some internal state for display purposes of the benchmark by the BenchmarkTool
    public var target: String?
    public var executablePath: String?
    /// closure: The actual benchmark closure that will be measured
    var closure: BenchmarkClosure? // The actual benchmark to run
    /// asyncClosure: The actual benchmark (async) closure that will be measured
    var asyncClosure: BenchmarkAsyncClosure? // The actual benchmark to run

    // Hooks for benchmark infrastructure to capture metrics of actual measurement() block without preamble:
    public var measurementPreSynchronization: BenchmarkMeasurementSynchronization?
    public var measurementPostSynchronization: BenchmarkMeasurementSynchronization?

    // Hook for custom metrics capturing
    public var customMetricMeasurement: BenchmarkCustomMetricMeasurement?

    /// The configuration to use for this benchmark
    public var configuration: Configuration = .init()

    /// Hook for setting defaults for a whole benchmark suite
    public static var defaultConfiguration: Configuration = .init(metrics: BenchmarkMetric.default,
                                                                  timeUnits: .automatic,
                                                                  warmupIterations: 3,
                                                                  throughputScalingFactor: .count,
                                                                  desiredDuration: .seconds(1),
                                                                  desiredIterations: 100_000,
                                                                  skip: false,
                                                                  thresholds: nil)

    internal static var testSkipBenchmarkRegistrations = false // true in test to avoid bench registration fail

    var measurementCompleted = false // Keep track so we skip multiple 'end of measurement'

    enum CodingKeys: String, CodingKey {
        case name
        case target
        case executablePath
        case configuration
        case failureReason
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }

    public static func == (lhs: Benchmark, rhs: Benchmark) -> Bool {
        lhs.name == rhs.name
    }

    /// Definition of a Benchmark
    /// - Parameters:
    ///   - name: The name used for display purposes of the benchmark (also used for
    ///   matching when comparing to baselines)
    ///   - configuration: Defines the settings that should be used for this benchmark
    ///   - closure: The actual benchmark closure that will be measured
    @discardableResult
    public init?(_ name: String,
                 configuration: Benchmark.Configuration = Benchmark.defaultConfiguration,
                 closure: @escaping BenchmarkClosure) {
        if configuration.skip {
            return nil
        }
        self.name = name
        self.configuration = configuration
        self.closure = closure

        benchmarkRegistration()
    }

    /// Definition of a Benchmark
    /// - Parameters:
    ///   - name: The name used for display purposes of the benchmark (also used for
    ///   matching when comparing to baselines)
    ///   - configuration: Defines the settings that should be used for this benchmark
    ///   - closure: The actual `async` benchmark closure that will be measured
    @discardableResult
    public init?(_ name: String,
                 configuration: Benchmark.Configuration = Benchmark.defaultConfiguration,
                 closure: @escaping BenchmarkAsyncClosure) {
        if configuration.skip {
            return nil
        }
        self.name = name
        self.configuration = configuration
        asyncClosure = closure

        benchmarkRegistration()
    }

    // Shared between sync/async actual benchmark registration
    internal func benchmarkRegistration() {
        if Self.testSkipBenchmarkRegistrations == false {
            guard Self.benchmarks.contains(self) == false else {
                fatalError("Duplicate registration of benchmark '\(name)', name must be unique.")
            }

            Self.benchmarks.append(self)
        }

        configuration.thresholds?.forEach { thresholdMetric, _ in
            if self.configuration.metrics.contains(thresholdMetric) == false {
                print("Warning: Custom threshold defined for metric `\(thresholdMetric)` " +
                    "which isn't used by benchmark `\(name)`")
            }
        }
    }

    /// `measurement` registers custom metric measurements
    ///
    ///
    /// - Parameters:
    ///   - metric: A `.custom()` metric to register a value for
    ///   - value: The value to register for the metric.
    public func measurement(_ metric: BenchmarkMetric, _ value: Int) {
        if let customMetricMeasurement {
            switch metric {
            case .custom:
                customMetricMeasurement(metric, value)
            default:
                return
            }
        }
    }

    /// If the benchmark contains a preamble setup that should not be part of the measurement
    /// `startMeasurement` can be called explicitly to define when measurement should begin.
    /// Otherwise the whole benchmark will be measured.
    public func startMeasurement() {
        if let measurementPreSynchronization {
            measurementPreSynchronization()
        }
        measurementCompleted = false
    }

    /// If the benchmark contains a postample that should not be part of the measurement
    /// `startMeasurement` can be called explicitly to define when measurement should begin.
    /// Otherwise the whole benchmark will be measured.
    public func stopMeasurement() {
        guard measurementCompleted == false else { // This is to skip the implicit stop if we did an explicit before
            return
        }

        if let measurementPostSynchronization {
            measurementCompleted = true
            measurementPostSynchronization()
        }
    }

    /// Used to signify that a given benchmark have failed for some reason
    /// - Parameter description: An explanation why a given benchmark failed which will be reported to the end user.
    public func error(_ description: String) {
        failureReason = description
    }

    // The rest is intenral supporting infrastructure that should only
    // be used by the BenchmarkRunner

    // https://forums.swift.org/t/actually-waiting-for-a-task/56230
    // Async closures can possibly show false memory leaks possibly due to Swift runtime allocations
    internal func runAsync() {
        let semaphore = DispatchSemaphore(value: 0)

        // Must do this in a separate thread, otherwise we block the concurrent thread pool
        DispatchQueue.global(qos: .userInitiated).async {
            Task {
                self.startMeasurement()
                await self.asyncClosure?(self)
                self.stopMeasurement()

                semaphore.signal()
            }
        }
        semaphore.wait()
    }

    // Public but should only be used by BenchmarkRunner
    public func run() {
        if closure != nil {
            startMeasurement()
            closure?(self)
            stopMeasurement()
        }

        if asyncClosure != nil {
            runAsync()
        }
    }
}

public extension Benchmark {
    struct Configuration: Codable {
        /// Defines the metrics that should be measured for the benchmark
        public var metrics: [BenchmarkMetric]
        /// Override the automatic detection of timeunits for metrics related to time to a specific
        /// one (auto should work for most use cases)
        public var timeUnits: BenchmarkTimeUnits
        /// Specifies a number of warmup iterations should be performed before the measurement to
        /// reduce outliers due to e.g. cache population
        public var warmupIterations: Int
        /// Specifies the number of logical subiterations being done, scaling throughput measurements accordingly.
        /// E.g. `.kilo`will scale results with 1000. Any iteration done in the benchmark should use
        /// `benchmark.throughputScalingFactor.rawvalue` for the number of iterations.
        public var throughputScalingFactor: StatisticsUnits
        /// The target wall clock runtime for the benchmark, currenty defaults to `.seconds(1)` if not set
        public var desiredDuration: Duration
        /// The target number of iterations for the benchmark., currently defaults to 100K iterations if not set
        public var desiredIterations: Int
        /// Whether to skip this test (convenience for not having to comment out tests that have issues)
        public var skip = false
        /// Customized CI failure thresholds for a given metric for the Benchmark
        public var thresholds: [BenchmarkMetric: BenchmarkResult.PercentileThresholds]?

        public init(metrics: [BenchmarkMetric] = defaultConfiguration.metrics,
                    timeUnits: BenchmarkTimeUnits = defaultConfiguration.timeUnits,
                    warmupIterations: Int = defaultConfiguration.warmupIterations,
                    throughputScalingFactor: StatisticsUnits = defaultConfiguration.throughputScalingFactor,
                    desiredDuration: Duration = defaultConfiguration.desiredDuration,
                    desiredIterations: Int = defaultConfiguration.desiredIterations,
                    skip: Bool = defaultConfiguration.skip,
                    thresholds: [BenchmarkMetric: BenchmarkResult.PercentileThresholds]? =
                    defaultConfiguration.thresholds) {
            self.metrics = metrics
            self.timeUnits = timeUnits
            self.warmupIterations = warmupIterations
            self.throughputScalingFactor = throughputScalingFactor
            self.desiredDuration = desiredDuration
            self.desiredIterations = desiredIterations
            self.skip = skip
            self.thresholds = thresholds
        }
        // swiftlint:disable nesting
        enum CodingKeys: String, CodingKey {
            case metrics
            case timeUnits
            case warmupIterations
            case throughputScalingFactor
            case desiredDuration
            case desiredIterations
            case thresholds
        }
    }
}
