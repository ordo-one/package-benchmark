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
              configuration: .init(metrics: [.throughput, .wallClock], scalingFactor: .mega)) { benchmark in
        for _ in benchmark.scaledIterations {
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

The `Benchmark` initializer has a wide range of options that allows tuning for how the benchmark should be run as well as what metrics and threshold should be captured and applied through the `configuration` parameter.

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

And the benchmark configuration:
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
        /// `benchmark.scalingFactor.rawvalue` for the number of iterations.
        public var scalingFactor: StatisticsUnits
        /// The target wall clock runtime for the benchmark, currenty defaults to `.seconds(1)` if not set
        public var maxDuration: Duration
        /// The target number of iterations for the benchmark., currently defaults to 100K iterations if not set
        public var maxIterations: Int
        /// Whether to skip this test (convenience for not having to comment out tests that have issues)
        public var skip = false
        /// Customized CI failure thresholds for a given metric for the Benchmark
        public var thresholds: [BenchmarkMetric: BenchmarkResult.PercentileThresholds]?
...
```

### scalingFactor
It's sometimes desireable to view `.throughput` scaled to a given number of iterations performed by the test (as for smaller test a large number of iterations is desirable to get stable results). This can be done by using `scalingFactor`.

An example would be:

```swift
    Benchmark("Foundation Date()",
              configuration: .init(metrics: [.throughput, .wallClock], scalingFactor: .mega)) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(Date())
        }
    }
```

### Metrics

Metrics can be specified both explicitly, e.g. `[.throughput, .wallClock]` but also with a number of convenience methods in  
`BenchmarkMetric+Defaults.swift`, like e.g. `BenchmarkMetric.memory` or `BenchmarkMetric.all`.

### Settings defaults for all benchmarks in a suite
It's possible to set the desired time units for a whole benchmark suite easily by setting `Benchmark.defaultConfiguration.timeUnits`
```swift
@_dynamicReplacement(for: registerBenchmarks)
func benchmarks() {

    Benchmark.defaultConfiguration.timeUnits = .nanoseconds

    Benchmark("Foundation Date()") {
...
    }
```

Similar defaults can be set for all benchmark settings using the class variable that takes a standard `Benchmark.Configuration`:
```
Benchmark.defaultConfiguration = .init(...)
```

### Custom thresholds

```swift
    let customThreshold = BenchmarkResult.PercentileThresholds(relative: [.p50 : 13.0, .p75 : 18.0],
                                                               absolute: [.p50 : 170, .p75 : 1200])

    Benchmark("Foundation Date()",
              configuration: .init(
              metrics: [.throughput, .wallClock],
              scalingFactor: .mega,
              thresholds: [.throughput : customThreshold, .wallClock : customThreshold])) { benchmark in
        for _ in benchmark.scaledIterations {
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

