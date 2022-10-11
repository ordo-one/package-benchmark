[![Swift version](https://img.shields.io/badge/Swift-5.6-orange?style=flat-square)](https://img.shields.io/badge/Swift-5.6-orange?style=flat-square)
[![Swift build and test](https://github.com/ordo-one/package-benchmark/actions/workflows/swift-build.yml/badge.svg)](https://github.com/ordo-one/package-benchmark/actions/workflows/swift-build.yml)
[![Swift address sanitizer](https://github.com/ordo-one/package-benchmark/actions/workflows/swift-address-sanitizer.yml/badge.svg)](https://github.com/ordo-one/package-benchmark/actions/workflows/swift-address-sanitizer.yml)
[![codecov](https://codecov.io/gh/ordo-one/package-benchmark/branch/main/graph/badge.svg?token=hXHmhEG1iF)](https://codecov.io/gh/ordo-one/package-benchmark)

# Benchmark 

## Introduction

Benchmark is a harness for easily creating Swift performance benchmarks for both macOS and Linux.

It's intended to be suitable for both ad-hoc smaller benchmarks primarily caring about runtime (in the spirit of [Google's swift-benchmark](https://github.com/google/swift-benchmark)) as well for more extensive benchmarks caring about additional benchmark metrics such as memory allocations, syscalls, thread usage and more.

Benchmark supports both local usage with baseline comparisons for an iterative workflow for the individual developer, but more importantly has good support for integration with GitHub CI with provided sample workflows for automated comparisons between `main` and a pull request branch to support enforced performance validation for pull requests with customizable thresholds - this is the primary intended use case for the package.

The focus for measurements are percentiles (`p0` (min), `p25`, `p50` (median), `p75`, `p90`, `p99` and `p100` (max)) to support analysis of the actual distribution of benchmark measurements. A given benchmark is typically run for a minimum amount of time and/or a given number of iterations, see details in the Benchmark documentation below.

### Minimal benchmark + benchmark using async / Swift Concurrency
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
              desiredDuration: .seconds(10)) { benchmark in
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

See the detailed documentation links below for extended usage including delta comparisons and baseline storage etc.

### Sample output benchmark run

<img width="877" alt="image" src="https://user-images.githubusercontent.com/8501048/192326477-c5fc5ec8-e77a-469e-a1b3-2f5d40754cb4.png">

### Sample output delta comparison

<img width="876" alt="image" src="https://user-images.githubusercontent.com/8501048/192494857-c39c478c-62fe-4795-9458-b317db59893c.png">

### Source and file format stability 
The source and file format of baselines are not officially stable yet until release `1.0.0`, even though no majors changes are planned currently, there might be source and file format breaking changes in minor releases (not patch releases) until then.

## Contents

- [Getting started and initial setup](Documentation/GettingStarted.md)
- [Writing benchmarks](Documentation/WritingBenchmarks.md)
- [Running benchmarks](Documentation/RunningBenchmarks.md)
- [Performance metrics and thresholds](Documentation/Metrics.md)
- [Typical workflows (manual and CI)](Documentation/Workflows.md)
- [Laundry list](Documentation/TODO.md)

There's also [a sample project](https://github.com/ordo-one/package-benchmark-samples) using various aspects of this package for those who just want to see how it can be used in practice
