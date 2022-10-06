#  Writing Benchmarks

Benchmarks are done declaratively with a benchmark initalizer specifying behavior and a trailing closure which is what actually will be measured.
 
The minimal code for a benchmark would be:

```swift
import BenchmarkSupport                 // import supporting infrastructure
@main extension BenchmarkRunner {}      // Required for main() definition to not get linker errors

@_dynamicReplacement(for: registerBenchmarks) // Register benchmarks
func benchmarks() {

    Benchmark("Minimal benchmark") { benchmark in
    }
}
```
A more real test for a couple of Foundation features would be:

```swift
import SystemPackage
import Foundation
import BenchmarkSupport
@main extension BenchmarkRunner {}

@_dynamicReplacement(for: registerBenchmarks)
func benchmarks() {
    let customThreshold = BenchmarkResult.PercentileThresholds(relative: [.p50 : 13.0, .p75 : 18.0],
                                                               absolute: [.p50 : 170, .p75 : 1200])

    Benchmark("Foundation Date()",
              metrics: [.throughput, .wallClock],
              throughputScalingFactor: .mega,
              thresholds: [.throughput : customThreshold, .wallClock : customThreshold]) { benchmark in
        for _ in benchmark.throughputIterations {
            blackHole(Date())
        }
    }

    Benchmark("Foundation AttributedString()", skip: false) { benchmark in
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

The `Benchmark` initializer has a wide range of options that allows tuning for how the benchmark should be run as well as what metrics and threshold should be captured and applied.

```swift
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
```

### throughputScalingFactor
It's sometimes desireable to view `.throughput` scaled to a given number of iterations performed by the test (as for smaller test a large number of iterations is desirable to get stable results). This can be done by using `throughputScalingFactor`.

An example would be:

```swift
    Benchmark("Foundation Date()",
              metrics: [.throughput],
              throughputScalingFactor: .mega) { benchmark in
        for _ in benchmark.throughputIterations { // will loop 1_000_000 times
            blackHole(Date())
        }
    }
```

### Metrics

Metrics can be specified both explicitly, e.g. `[.throughput, .wallClock]` but also with a number of convenience methods in  
`BenchmarkMetric+Defaults.swift`, like e.g. `BenchmarkMetric.memory` or `BenchmarkMetric.all`.

### Settings defaults for all benchmarks in a suite
It's possible to set the desired time units for a whole benchmark suite easily by setting `Benchmark.defaultBenchmarkTimeUnits`
```swift
@_dynamicReplacement(for: registerBenchmarks)
func benchmarks() {

    Benchmark.defaultBenchmarkTimeUnits = .nanoseconds

    Benchmark("Foundation Date()") {
...
    }
```

Similar defaults can be set for all benchmark settings using the class variables:
```
Benchmark.defaultMetrics
Benchmark.defaultTimeUnits
Benchmark.defaultWarmupIterations
Benchmark.defaultThroughputScalingFactor
Benchmark.defaultDesiredDuration
Benchmark.defaultDesiredIterations
Benchmark.defaultSkip
Benchmark.defaultThresholds
```

### Custom thresholds

```swift
    let customThreshold = BenchmarkResult.PercentileThresholds(relative: [.p50 : 13.0, .p75 : 18.0],
                                                               absolute: [.p50 : 170, .p75 : 1200])

    Benchmark("Foundation Date()",
              metrics: [.throughput, .wallClock],
              throughputScalingFactor: .mega,
              thresholds: [.throughput : customThreshold, .wallClock : customThreshold]) { benchmark in
        for _ in benchmark.throughputIterations {
            blackHole(Date())
        }
    }
```
There are a number of convenience methods in `BenchmarkResult+Defaults.swift`.

## Async vs Sync
The framework supports both synchronous and asynchronous benchmark closures, it should transparently "just work".

## Some implementation notes
The Benchmark SwiftPM plugins executes the `BenchmarkTool` executable which is the benchmark driver.

The `BenchmarkTool` in turns runs each executable target that is defined and uses JSON to communicate with the target process over pipes. 

The executable benchmark targets just implements the actual benchmark tests, as much boilerplate code as possible has been hidden. The executable benchmark must depend on the `Benchmark` library target which also will pull in `jemalloc` for malloc stats.

`@_dynamicReplacement(for:)` is used to hook in the benchmarks for the target, hopefully it will be an integrated supported part of Swift in the future.

### Notes on threading
The benchmark framework will use a couple of threads internally (one for sampling various statistics during the benchmark runtime, such as e.g. number of threads, another to facilitate async closures), so it is normal to see two extra threads or so when measuring - the sampling thread is currently running every 5ms and should not have measurable impact on most tests.

## Debugging
The benchmark executables are set up to automatically run all tests when run standalone with simple debug output - this is to enable workflows where the benchmark is run in the Xcode debugger or with Instruments if desired - or with `lldb` on the command line on Linux to support debugging in problematic performance tests.

