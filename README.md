[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fordo-one%2Fpackage-benchmark%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ordo-one/package-benchmark)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fordo-one%2Fpackage-benchmark%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ordo-one/package-benchmark)
[![Swift Linux build](https://github.com/ordo-one/package-benchmark/actions/workflows/swift-linux-build.yml/badge.svg)](https://github.com/ordo-one/package-benchmark/actions/workflows/swift-linux-build.yml)
[![Swift macOS build](https://github.com/ordo-one/package-benchmark/actions/workflows/swift-macos-build.yml/badge.svg)](https://github.com/ordo-one/package-benchmark/actions/workflows/swift-macos-build.yml)
[![Swift address sanitizer](https://github.com/ordo-one/package-benchmark/actions/workflows/swift-sanitizer-address.yml/badge.svg)](https://github.com/ordo-one/package-benchmark/actions/workflows/swift-sanitizer-address.yml)
[![Swift thread sanitizer](https://github.com/ordo-one/package-benchmark/actions/workflows/swift-sanitizer-thread.yml/badge.svg)](https://github.com/ordo-one/package-benchmark/actions/workflows/swift-sanitizer-thread.yml)
[![codecov](https://codecov.io/gh/ordo-one/package-benchmark/branch/main/graph/badge.svg?token=hXHmhEG1iF)](https://codecov.io/gh/ordo-one/package-benchmark)

# Benchmark 

Benchmark is a harness for easily creating Swift performance benchmarks for both macOS and Linux.

## Overview

Performance is a key feature for many apps and frameworks. Benchmark helps make it easy to measure and track many different metrics that affects performance, such as CPU usage, memory usage and use of operating system resources such as threads and system calls.

Benchmark supports several key workflows for performance measurements, e.g.:

* **Automated Pull Request performance regression checks** by comparing the performance metrics of a pull request with the main branch and having the PR check fail if there is a regression (e.g. no added memory allocations, or that the runtime was at least as good) with ready to use workflows for GitHub CI
* **Manual comparison of multiple performance baselines** for iterative or A/B performance work by an individual developer
* **Export of benchmark results in several formats** such as JMH (Java Microbenchmark Harness), TSV (tab-separated-values), [HDR Histogram](http://hdrhistogram.org) ([analysis](http://www.david-andrzejewski.com/publications/hdr.pdf)), etc. This allows for tracking performance over time or analyzing/visualizing with other tools such as [JMH visualizer](https://jmh.morethan.io), [Gnuplot](http://www.gnuplot.info), [YouPlot](https://github.com/red-data-tools/YouPlot), [HDR Histogram analyzer](http://hdrhistogram.github.io/HdrHistogram/plotFiles.html) and more.

Benchmark provides a quick way for validation of performance metrics, while other more specialized tools such as Instruments, DTrace, Heaptrack, Leaks, Sample and more can be used for finding root causes for any deviations found.

Benchmark is suitable for both smaller ad-hoc benchmarks only caring about runtime (in the spirit of [Google's swift-benchmark](https://github.com/google/swift-benchmark)) and more extensive benchmarks that care about additional metrics such as memory allocations, syscalls, thread usage and more. Thanks to the [HDR Histogram foundation](https://github.com/ordo-one/package-histogram) it's especially suitable for capturing latency statistics for large number of samples.

## Documentation

Documentation on how to use Benchmark in your Swift package can be [viewed online](https://swiftpackageindex.com/ordo-one/package-benchmark/main/documentation/benchmark) (hosted by the Swift Package Index, thanks!) or inside Xcode using `Build Documenation`. Additionally the command plugin provides help information if you run `swift package benchmark help` from the command line.

## Sample Code

There's also [a sample project](https://github.com/ordo-one/package-benchmark-samples) using various aspects of this package in practice.

## Sample benchmark code
```swift
import BenchmarkSupport
@main extension BenchmarkRunner {}
@_dynamicReplacement(for: registerBenchmarks)

func benchmarks() {

    Benchmark("Minimal benchmark") { benchmark in
      // measure something here
    }

    Benchmark("All metrics, full concurrency, async",
              metrics: BenchmarkMetric.all,
              maxDuration: .seconds(10)) { benchmark in
        let _ = await withTaskGroup(of: Void.self, returning: Void.self, body: { taskGroup in
            for _ in 0..< 80  {
                taskGroup.addTask {
                    dummyCounter(defaultCounter()*1000)
                }
            }
            for await _ in taskGroup {
            }
        })
    }
}
```

### Running benchmarks

To execute all defined benchmarks, simply run:

```swift package benchmark```

Please see the detailed documentation hosted at Swift Package Index linked to above or inside Xcode.

### Sample output benchmark run

<img width="877" alt="image" src="https://user-images.githubusercontent.com/8501048/192326477-c5fc5ec8-e77a-469e-a1b3-2f5d40754cb4.png">

### Sample output delta comparison

<img width="876" alt="image" src="https://user-images.githubusercontent.com/8501048/192494857-c39c478c-62fe-4795-9458-b317db59893c.png">

### API and file format stability
The API is deemed stable as of `1.0.0` and follows semantical versioning for future releases. 

The export file formats that are externally defined (e.g. JMH or HDR Histogram formats) will follow the upstream definitions if they change, but have been quite stable for several years. 

The Histogram codable representation is not stable and may change if the Histogram implementation changes.

The benchmark internal baseline representation (stored in `.benchmarkBaselines`) is not stable and is not viewed as public API and may break over time.

For those wanting to save benchmark data over time, it's recommended to export data in e.g. HDR Histogram representations (percentiles, average, stddev etc) or simply post processing the TSV format (which is raw data) to your desired representation.

PR:s for additional standardized formats are welcome, as the export formats are the intended stable interface for saving such data.

### CI build note
The badges above shows that macOS builds are failing on the CI [as GitHub still haven't provided runners for macOS 13 Ventura](https://github.com/actions/runner-images/issues/6426), it works in practice.

