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
import Statistics // For TimeInstant/TimeDuration until we can migrate to 5.7 Instant/Duration

/// Defines a benchmark
public final class Benchmark: Codable, Hashable {
    public typealias BenchmarkClosure = (_ benchmark: Benchmark) -> Void
    public typealias BenchmarkAsyncClosure = (_ benchmark: Benchmark) async -> Void
    public typealias BenchmarkMeasurementSynchronization = () -> Void
    public typealias BenchmarkCustomMetricMeasurement = (BenchmarkMetric, Int) -> Void

    public static var benchmarks: [Benchmark] = [] // Bookkeeping of all registered benchmarks

    /// The name used for display purposes of the benchmark (also used for matching when comparing to baselines)
    public var name: String
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
    public var desiredDuration: TimeDuration
    /// The target number of iterations for the benchmark., currently defaults to 100K iterations if not set
    public var desiredIterations: Int
    /// The reason for a benchmark failure, not set if successful
    public var failureReason: String?
    /// The current benchmark iteration (also includes warmup iterations), can be useful when
    /// e.g. unique keys will be needed for different iterations
    public var currentIteration: Int = 0
    /// Customized CI failure thresholds for a given metric for the Benchmark
    public var thresholds: [BenchmarkMetric: BenchmarkResult.PercentileThresholds]?

    /// Convenience range to iterate over for benchmarks
    public var throughputIterations: Range<Int> { 0 ..< throughputScalingFactor.rawValue }

    ///   - closure: The actual benchmark closure that will be measured
    var closure: BenchmarkClosure? // The actual benchmark to run
    var asyncClosure: BenchmarkAsyncClosure? // The actual benchmark to run

    // Hooks for benchmark infrastructure to capture metrics of actual measurement() block without preamble:
    public var measurementPreSynchronization: BenchmarkMeasurementSynchronization?
    public var measurementPostSynchronization: BenchmarkMeasurementSynchronization?

    // Hook for custom metrics capturing
    public var customMetricMeasurement: BenchmarkCustomMetricMeasurement?

    /// Hooks for setting defaults for a whole benchmark suite
    public static var defaultMetrics: [BenchmarkMetric] = BenchmarkMetric.default
    public static var defaultTimeUnits: BenchmarkTimeUnits = .automatic
    public static var defaultWarmupIterations = 3
    public static var defaultThroughputScalingFactor: StatisticsUnits = .count
    public static var defaultDesiredDuration: TimeDuration = .seconds(1)
    public static var defaultDesiredIterations: Int = 100_000
    public static var defaultSkip = false
    public static var defaultThresholds: [BenchmarkMetric: BenchmarkResult.PercentileThresholds]?

    internal static var testSkipBenchmarkRegistrations = false // true in test to avoid bench registration fail

    var measurementCompleted = false // Keep track so we skip multiple 'end of measurement'

    enum CodingKeys: String, CodingKey {
        case name
        case metrics
        case timeUnits
        case warmupIterations
        case throughputScalingFactor
        case desiredDuration
        case desiredIterations
        case thresholds
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
    ///   - metrics: Defines the metrics that should be measured for the benchmark
    ///   - timeUnits: Override the automatic detection of timeunits for metrics related to time
    ///   to a specific one (auto should work for most use cases)
    ///   - warmupIterations: Specifies  a number of warmup iterations should be performed before the
    ///   measurement to reduce outliers due to e.g. cache population, currently 3 warmup iterations will be run.
    ///   - throughputScalingFactor: Specifies the number of logical subiterations being done, scaling
    ///   throughput measurements accordingly. E.g. `.kilo`
    ///   will scale results with 1000. Any iteration done in the benchmark should use
    ///   `benchmark.throughputScalingFactor.rawvalue` for the number of iterations.
    ///   - desiredDuration: The target wall clock runtime for the benchmark
    ///   - desiredIterations: The target number of iterations for the benchmark.
    ///   - skip: Set to true if the benchmark should be excluded from benchmark runs
    ///   - thresholds: Defines custom threshold per metric for failing the benchmark in CI for in `benchmark compare`
    ///   - closure: The actual benchmark closure that will be measured
    @discardableResult
    public init?(_ name: String,
                 metrics: [BenchmarkMetric] = Benchmark.defaultMetrics,
                 timeUnits: BenchmarkTimeUnits = Benchmark.defaultTimeUnits,
                 warmupIterations: Int = Benchmark.defaultWarmupIterations,
                 throughputScalingFactor: StatisticsUnits = Benchmark.defaultThroughputScalingFactor,
                 desiredDuration: TimeDuration = Benchmark.defaultDesiredDuration,
                 desiredIterations: Int = Benchmark.defaultDesiredIterations,
                 skip: Bool = Benchmark.defaultSkip,
                 thresholds: [BenchmarkMetric: BenchmarkResult.PercentileThresholds]? = Benchmark.defaultThresholds,
                 closure: @escaping BenchmarkClosure) {
        if skip {
            return nil
        }
        self.name = name
        self.metrics = metrics
        self.timeUnits = timeUnits
        self.warmupIterations = warmupIterations
        self.throughputScalingFactor = throughputScalingFactor
        self.desiredDuration = desiredDuration
        self.desiredIterations = desiredIterations
        self.thresholds = thresholds
        self.closure = closure

        if Self.testSkipBenchmarkRegistrations == false {
            guard Self.benchmarks.contains(self) == false else {
                fatalError("Duplicate registration of benchmark '\(self.name)', name must be unique.")
            }

            Self.benchmarks.append(self)
        }

        self.thresholds?.forEach { thresholdMetric, _ in
            if self.metrics.contains(thresholdMetric) == false {
                print("Warning: Custom threshold defined for metric `\(thresholdMetric)` " +
                    "which isn't used by benchmark `\(name)`")
            }
        }
    }

    /// Definition of a Benchmark
    /// - Parameters:
    ///   - name: The name used for display purposes of the benchmark (also used for
    ///   matching when comparing to baselines)
    ///   - metrics: Defines the metrics that should be measured for the benchmark
    ///   - timeUnits: Override the automatic detection of timeunits for metrics related to time
    ///   to a specific one (auto should work for most use cases)
    ///   - warmupIterations: Specifies a number of warmup iterations should be performed before the
    ///   measurement to reduce outliers due to e.g. cache population
    ///   - throughputScalingFactor: Specifies the number of logical subiterations being done, scaling
    ///   throughput measurements accordingly. E.g. `.kilo`
    ///   will scale results with 1000. Any iteration done in the benchmark should use
    ///   `benchmark.throughputScalingFactor.rawvalue` for the number of iterations.
    ///   - desiredDuration: The target wall clock runtime for the benchmark
    ///   - desiredIterations: The target number of iterations for the benchmark.
    ///   - skip: Set to true if the benchmark should be excluded from benchmark runs
    ///   - thresholds: Defines custom threshold per metric for failing the benchmark in CI for in `benchmark compare`
    ///   - closure: The actual `async` benchmark closure that will be measured
    @discardableResult
    public init?(_ name: String,
                 metrics: [BenchmarkMetric] = Benchmark.defaultMetrics,
                 timeUnits: BenchmarkTimeUnits = Benchmark.defaultTimeUnits,
                 warmupIterations: Int = Benchmark.defaultWarmupIterations,
                 throughputScalingFactor: StatisticsUnits = Benchmark.defaultThroughputScalingFactor,
                 desiredDuration: TimeDuration = Benchmark.defaultDesiredDuration,
                 desiredIterations: Int = Benchmark.defaultDesiredIterations,
                 skip: Bool = Benchmark.defaultSkip,
                 thresholds: [BenchmarkMetric: BenchmarkResult.PercentileThresholds]? = Benchmark.defaultThresholds,
                 closure: @escaping BenchmarkAsyncClosure) {
        if skip {
            return nil
        }
        self.name = name
        self.metrics = metrics
        self.timeUnits = timeUnits
        self.warmupIterations = warmupIterations
        self.throughputScalingFactor = throughputScalingFactor
        self.desiredDuration = desiredDuration
        self.desiredIterations = desiredIterations
        self.thresholds = thresholds
        asyncClosure = closure

        Self.benchmarks.append(self)
    }

    /// `measurement` registers custom metric measurements
    ///
    ///
    /// - Parameters:
    ///   - metric: A `.custom()` metric to register a value for
    ///   - value: The value to register for the metric.
    public func measurement(_ metric: BenchmarkMetric, _ value: Int) {
        if let customMetricMeasurement = customMetricMeasurement {
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
        if let measurementPreSynchronization = measurementPreSynchronization {
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

        if let measurementPostSynchronization = measurementPostSynchronization {
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
