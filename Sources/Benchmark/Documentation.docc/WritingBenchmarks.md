# Writing Benchmarks

Create benchmark suites to run and measure your benchmarks.

## Overview

Create benchmarks declaratively using the ``Benchmark/Benchmark`` initalizer, specifying configuration and the work to be measured in a trailing closure.

The minimal code for a benchmark suite running with a default configuration would be:

```swift
import Benchmark

let benchmarks = {
    Benchmark("Minimal benchmark") { benchmark in
        // Some work to measure here
    }
}
```

### Writing a Benchmarks with custom configuration

A more real test for a couple of Foundation features would be:


```swift
import SystemPackage
import Foundation
import Benchmark

let benchmarks = {
    let customThreshold = BenchmarkThresholds(
        relative: [.p50: 5.0, .p75: 10.0],
        absolute: [.p25: 10, .p50: 15])
    let customThreshold2 = BenchmarkThresholds(
        relative: BenchmarkThresholds.Relative.strict)
    let customThreshold3 = BenchmarkThresholds(
        absolute: BenchmarkThresholds.Absolute.relaxed)

    Benchmark.defaultConfiguration = .init(
        timeUnits: .microseconds,
        thresholds: [.wallClock: customThreshold,
                     .throughput: customThreshold2,
                     .cpuTotal: customThreshold3,
                     .cpuUser: .strict])

    Benchmark("Foundation Date()",
              configuration: .init(
                metrics: [.throughput, .wallClock],
                scalingFactor: .mega)) { benchmark in
                    for _ in benchmark.scaledIterations {
                        blackHole(Date())
                    }
                }

    Benchmark("Foundation AttributedString()") { benchmark in
        let count = 200
        var str = AttributedString(
            String(repeating: "a", count: count))
        str += AttributedString(
            String(repeating: "b", count: count))
        str += AttributedString(
            String(repeating: "c", count: count))
        let idx = str.characters.index(
            str.startIndex,
            offsetBy: str.characters.count / 2)
        let toInsert = AttributedString(
            String(repeating: "c", count: str.characters.count))

        benchmark.startMeasurement()
        str.insert(toInsert, at: idx)
    }
}
```

The ``Benchmark/Benchmark`` initializer includes options to allow you to tune how the benchmark should be run, as well as what metrics and thresholds should be captured.
These benchmark options are applied through the ``Benchmark/configuration-swift.property`` parameter.

<!-- I think there's a way to reference code in source control/GitHub that may be appropriate here. -->

```swift
/// Definition of a Benchmark
/// - Parameters:
///   - name: The name used for display purposes of the benchmark
///     (also used for matching when comparing to baselines)
///   - configuration: Defines the settings that should be used
///     for this benchmark
///   - closure: The actual benchmark closure that will be measured
@discardableResult
public init?(_ name: String,
    configuration: Benchmark.Configuration = Benchmark.defaultConfiguration,
    closure: @escaping BenchmarkClosure) {
```

And the benchmark configuration is defined in ``Benchmark/Configuration-swift.struct``.

<!-- TODO: Reframe this in terms of a reference to the Configuration struct and it's reference documentation -->

```swift
public extension Benchmark {
    struct Configuration: Codable {
        /// Defines the metrics that should be measured for the benchmark
        public var metrics: [BenchmarkMetric]
        /// Override the automatic detection of timeunits for metrics 
        /// related to time to a specific one 
        /// (auto should work for most use cases)
        public var timeUnits: BenchmarkTimeUnits
        /// Specifies a number of warmup iterations should be performed before   
        /// the measurement to reduce outliers due to e.g. cache population
        public var warmupIterations: Int
        /// Specifies the number of logical subiterations being done, scaling 
        /// throughput measurements accordingly.
        /// E.g. `.kilo`will scale results with 1000. 
        /// Any iteration done in the benchmark should use
        /// `benchmark.scalingFactor.rawvalue` for 
        /// the number of iterations.
        public var scalingFactor: StatisticsUnits
        /// The target wall clock runtime for the benchmark. 
        /// Defaults to `.seconds(1)` if not set.
        public var maxDuration: Duration
        /// The target number of iterations for the benchmark.
        /// Defaults to 100K iterations if not set.
        public var maxIterations: Int
        /// Whether to skip this test (convenience for not 
        /// having to comment out tests that have issues)
        public var skip = false
        /// Customized CI failure thresholds for a given metric 
        /// for the Benchmark
        public var thresholds: [BenchmarkMetric: BenchmarkThresholds]?
...
```

### scalingFactor

For fast running (micro-)benchmarks, it is highly recommended to run measurements with an inner loop to ensure that the measurement overhead is small compared to the thing that is under measurement.

To make this easy, Benchmark provides a ``Benchmark/Configuration-swift.struct/scalingFactor`` in ``Benchmark/Configuration-swift.struct`` which gives a convenience iterator range and supports scaled output on the command line using the `--scale` flag.

An example of using `scalingFactor` to run 1M inner loops:

```swift
Benchmark("Foundation Date()", configuration: .init(scalingFactor: .mega)) { benchmark in
    for _ in benchmark.scaledIterations {
        blackHole(Date())
    }
}
```

### Metrics

Benchmark supports a wide range of measurements defined by ``Benchmark/BenchmarkMetric``.

Benchmark provides a number of convenience methods for commonly useful sets of metrics, for example ``Benchmark/BenchmarkMetric/memory`` and - ``Benchmark/BenchmarkMetric/all``.

Metrics can also be specified explicitly, for example `[.throughput, .wallClock]`, or even by combining the default set with individual metrics.

Benchmark also supports completely custom metric measurements using ``Benchmark/Benchmark/measurement(_:_:)`` if there are specific things you want to capture:

```swift
...
// A way to define custom metrics fairly compact
enum CustomMetrics {
    static var one: BenchmarkMetric { .custom("CustomMetricOne") }
    static var two: BenchmarkMetric { .custom("CustomMetricTwo", polarity: .prefersLarger, useScalingFactor: true) }
}

Benchmark("Custom metrics", configuration: .init(metrics: BenchmarkMetric.all + [CustomMetrics.two, CustomMetrics.one], scalingFactor: .kilo)) { benchmark in
    for _ in benchmark.scaledIterations {
        blackHole(Int.random(in: benchmark.scaledIterations))
    }
    benchmark.measurement(CustomMetrics.one, Int.random(in: 1 ... 1_000))
    benchmark.measurement(CustomMetrics.two, Int.random(in: 1 ... 1_000_000))
}
```

### Settings defaults for all benchmarks within a suite

Set the desired time units for all benchmarks within a suite easily by setting ``Benchmark/Configuration-swift.struct/timeUnits``:

```swift
import Benchmark

let benchmarks = {
    Benchmark.defaultConfiguration.timeUnits = .nanoseconds

    Benchmark("Foundation Date()") {
        ...
    }
```

Similar defaults can be set for all benchmark settings using the class variable that takes a standard ``Benchmark/Configuration-swift.struct``:

```swift
Benchmark.defaultConfiguration = .init(...)
```

### Custom thresholds

```swift
    let customThreshold = BenchmarkThresholds(
        relative: [.p50 : 13.0, .p75 : 18.0],
        absolute: [.p50 : .millseconds(170), .p75 : .milliseconds(1200]))

    Benchmark(
        "Foundation Date()",
        configuration: .init(
            metrics: [.throughput, .wallClock],
            scalingFactor: .mega,
            thresholds: [.wallClock : customThreshold])
    ) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(Date())
        }
    }
```

There are a number of convenience methods in `BenchmarkThreshold+Defaults.swift`.

### Async vs Sync

The framework supports both synchronous and asynchronous benchmark closures, it should transparently "just work".

### Notes on threading

The benchmark framework will use a couple of threads internally (one for sampling various statistics during the benchmark runtime, such as e.g. number of threads, another to facilitate async closures), so it is normal to see two extra threads or so when measuring - the sampling thread is currently running every 5ms and should not have measurable impact on most tests.

### Debugging

The benchmark executables are set up to automatically run all tests when run standalone with simple debug output - this is to enable workflows where the benchmark is run in the Xcode debugger or with Instruments if desired - or with `lldb` on the command line on Linux to support debugging in problematic performance tests.

### Implementation notes

The Benchmark SwiftPM plugins executes the `BenchmarkTool` executable which is the benchmark driver.

The `BenchmarkTool` in turns runs each executable target that is defined and uses JSON to communicate with the target process over pipes.

The executable benchmark targets just implements the actual benchmark tests, as much boilerplate code as possible has been hidden. The executable benchmark must depend on the `Benchmark` library target which also will pull in `jemalloc` for malloc stats.
