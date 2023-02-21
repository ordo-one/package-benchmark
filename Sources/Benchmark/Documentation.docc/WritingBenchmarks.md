# Writing Benchmarks

Create benchmark suites to run and measure your benchmarks.

## Overview

Create benchmarks declaratively using the ``Benchmark/Benchmark`` initalizer, specifying configuration and the work to be measured in a trailing closure.

The minimal code for a benchmark suite would be:

```swift
import BenchmarkSupport                 // import supporting infrastructure
@main extension BenchmarkRunner {}      // Required for main() definition to not get linker errors

@_dynamicReplacement(for: registerBenchmarks) // Register benchmarks
func benchmarks() {

    Benchmark("Minimal benchmark") { benchmark in
    }
}
```

### Writing a Benchmarks with custom configuration

A more real test for a couple of Foundation features would be:

<!-- TODO: wrap the code _much_ tighter to allow full view within a default window. 
The sidebar takes up an impressive amount of space, and ideally this should be viewable without having to scroll horizontally. 
-->
```swift
import SystemPackage
import Foundation
import BenchmarkSupport
@main extension BenchmarkRunner {}

@_dynamicReplacement(for: registerBenchmarks)
func benchmarks() {
    let customThreshold = BenchmarkResult.PercentileThresholds(relative: [.p50: 5.0, .p75: 10.0],
                                                               absolute: [.p25: 10, .p50: 15])
    let customThreshold2 = BenchmarkResult.PercentileThresholds(relative: .strict)
    let customThreshold3 = BenchmarkResult.PercentileThresholds(absolute: .relaxed)

    Benchmark.defaultConfiguration = .init(timeUnits: .microseconds,
                                           thresholds: [.wallClock: customThreshold,
                                                        .throughput: customThreshold2,
                                                        .cpuTotal: customThreshold3,
                                                        .cpuUser: .strict])

    Benchmark("Foundation Date()",
              configuration: .init(metrics: [.throughput, .wallClock], throughputScalingFactor: .mega)) { benchmark in
        for _ in benchmark.throughputIterations {
            blackHole(Date())
        }
    }

    Benchmark("Foundation AttributedString()") { benchmark in
        let count = 200
        var str = AttributedString(String(repeating: "a", count: count))
        str += AttributedString(String(repeating: "b", count: count))
        str += AttributedString(String(repeating: "c", count: count))
        let idx = str.characters.index(str.startIndex, offsetBy: str.characters.count / 2)
        let toInsert = AttributedString(String(repeating: "c", count: str.characters.count))

        benchmark.startMeasurement()
        str.insert(toInsert, at: idx)
    }
}
```

The ``Benchmark/Benchmark`` initializer includes options to allow you to tune how the benchmark should be run, as well as what metrics and thresholds should be captured.
These benchmark options are applied through the ``Benchmark/configuration-swift.property`` parameter.

<!-- I think there's a way to reference code in source control/GitHub that may be appropriate here. -->

<!-- TODO: wrap the code _much_ tighter to allow full view within a default window. 
The sidebar takes up an impressive amount of space, and ideally this should be viewable without having to scroll horizontally. 
-->

```swift
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
```

And the benchmark configuration is defined in ``Benchmark/Configuration-swift.struct``.

<!-- TODO: Reframe this in terms of a reference to the Configuration struct and it's reference documentation -->

```swift
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
...
```

### throughputScalingFactor

If your benchmark uses a small test and you want to run a scaled number of iterations to retrieve stable results, define a ``Benchmark/Configuration-swift.struct/throughputScalingFactor`` in ``Benchmark/Configuration-swift.struct``.
An example of using `throughputScalingFactor`:

<!-- TODO: wrap the code _much_ tighter to allow full view within a default window. 
The sidebar takes up an impressive amount of space, and ideally this should be viewable without having to scroll horizontally. 
-->

```swift
    Benchmark("Foundation Date()",
              configuration: .init(metrics: [.throughput, .wallClock], throughputScalingFactor: .mega)) { benchmark in
        for _ in benchmark.throughputIterations {
            blackHole(Date())
        }
    }
```

### Metrics

Metrics can be specified explicitly, for example `[.throughput, .wallClock]`.
Benchmark also provides a number of convenience methods for common sets of metrics, for example ``Benchmark/BenchmarkMetric/memory`` and - ``Benchmark/BenchmarkMetric/all``.

### Settings defaults for all benchmarks within a suite

Set the desired time units for all benchmarks within a suite easily by setting ``Benchmark/Configuration-swift.struct/timeUnits``:

```swift
@_dynamicReplacement(for: registerBenchmarks)
func benchmarks() {

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

<!-- TODO: wrap the code _much_ tighter to allow full view within a default window. 
The sidebar takes up an impressive amount of space, and ideally this should be viewable without having to scroll horizontally. 
-->

```swift
    let customThreshold = BenchmarkResult.PercentileThresholds(relative: [.p50 : 13.0, .p75 : 18.0],
                                                               absolute: [.p50 : 170, .p75 : 1200])

    Benchmark("Foundation Date()",
              configuration: .init(
              metrics: [.throughput, .wallClock],
              throughputScalingFactor: .mega,
              thresholds: [.throughput : customThreshold, .wallClock : customThreshold])) { benchmark in
        for _ in benchmark.throughputIterations {
            blackHole(Date())
        }
    }
```

There are a number of convenience methods in `BenchmarkResult+Defaults.swift`.

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

`@_dynamicReplacement(for:)` is used to hook in the benchmarks for the target, hopefully it will be an integrated supported part of Swift in the future.
