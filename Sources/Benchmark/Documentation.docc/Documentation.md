# ``Benchmark``

Benchmark is a harness for easily creating Swift performance benchmarks for both macOS and Linux.

## Overview

Performance is a key feature for many apps and frameworks. Benchmark helps make it easy to measure many different metrics that affects performance, such as CPU usage, memory usage and use of operating system resources such as threads and system calls.

Benchmark supports several key workflows for performance measurements, e.g.:

* Automated Pull Request performance regression checks by comparing the performance metrics of a pull request with the main branch and having the PR check fail if there is a regression (e.g. no added memory allocations, or that the runtime was at least as good)
* Manual comparison of multiple performance baselines for iterative or A/B performance work 
* Export of benchmark results in several standardized formats such as JMH, TSV, HDR Histogram, etc. This allows for tracking performance over time or analyzing/visualizing with other tools such as JMH visualizer, Gnuplot, Youplot, HDR Histogram analyzer and more.

Benchmark provides a quick way for validation of performance metrics, other more specialized tools such as Instruments, DTrace, Heaptrack, Leaks, Sample and more can be used for finding root causes for any deviations found.

Benchmark is suitable for both ad-hoc smaller benchmarks primarily caring about runtime (in the spirit of [Google's swift-benchmark](https://github.com/google/swift-benchmark)) and more extensive benchmarks that care about additional metrics such as memory allocations, syscalls, thread usage and more.

Benchmark supports both local usage and enforced performance evaluation for continuous integration.
Local usage includes baseline comparisons for an iterative workflow for the individual developer.
The continuous integration support for Benchmark is the primary intended use case for the package.
CI support has good support for integration with GitHub CI, and includes sample workflows for automated comparisons between a `main` branch and the branch of a pull request to allow CI to enforce performance validation with customizable thresholds.

Benchmark measurements are provided as percentiles to support analysis of the actual distribution of benchmark measurements.
An individual benchmark is typically run for a minimum amount of time and/or a given number of iterations.
The default percentiles presented are:

| `p0` | `p25` | `p50` | `p75` | `p90` | `p99` | `p100` |
| ---- | ----- | ----- | ----- | ----- | ----- | ------ |
| (min)|       | (median) |    |       |       | (max) |

You can also configure your own sets of percentiles within Benchmark configurations.
For more details on configuring benchmarks, see [LINK TBD].

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:WritingBenchmarks>
- <doc:Metrics>
- <doc:RunningBenchmarks>
- <doc:Workflows>

### Benchmarks

- ``Benchmark/Benchmark``

### Configuring Benchmarks

- ``Benchmark/Benchmark/Configuration-swift.struct`` 
- ``Benchmark/BenchmarkMetric``
- ``Benchmark/BenchmarkTimeUnits``

### Registering Benchmarks

- ``Benchmark/registerBenchmarks()``

### Supporting Functions

- ``Benchmark/blackHole(_:)``
