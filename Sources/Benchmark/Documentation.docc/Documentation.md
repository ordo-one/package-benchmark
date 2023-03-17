# ``Benchmark``

Benchmark allows you to easily create sophisticated Swift performance benchmarks

## Overview

Performance is a key feature for many apps and frameworks. 
Benchmark helps make it easy to measure and track many different metrics that affects performance, such as CPU usage, memory usage and use of operating system resources such as threads and system calls.
Benchmark provides a quick way for validation of performance metrics, while other more specialized tools such as Instruments, DTrace, Heaptrack, Leaks, Sample, etc support finding root causes for any deviations found.

Benchmark supports several key workflows for performance measurements.

* **<doc:CreatingAndComparingBaselines>**
* **<doc:ComparingBenchmarksCI>**
* **<doc:ExportingBenchmarks>**

Benchmark is suitable for both smaller ad-hoc benchmarks focusing on execution time (in the spirit of [Google's swift-benchmark](https://github.com/google/swift-benchmark)) and more extensive benchmarks that care about several additional metrics such as memory allocations, syscalls, thread usage, context switches, and more. 
Thanks to the use of the [Histogram foundation](https://github.com/ordo-one/package-histogram) it's especially suitable for capturing latency statistics for large number of samples.


The default text output from Benchmark is oriented around [the five-number summary](https://en.wikipedia.org/wiki/Five-number_summary) percentiles, plus the last decile (`p90`) and the last percentile (`p99`) - it's thus a variation of a [seven-figure summary](https://en.wikipedia.org/wiki/Seven-number_summary) with the focus on the 'bad' end of results (as those are what we typically care about addressing).
We've found that focusing on percentiles rather than average or standard deviations, is more useful for a wider range of benchmark measurements and gives a deeper understanding of the results.
Percentiles allows for a consistent way of expressing benchmark results of both throughput and latency measurements (which typically do **not** have a standardized distribution, being almost always are multi-modal in nature).
This multi-modal nature of the latency measurements leads to the common statistical measures of mean and standard deviation being potentially misleading.

That being said, some of the export formats do include more traditional mean and standard deviation statistics.
The Benchmark infrastructure captures _all_ samples for a test run, so you can review the raw data points for your own post-run statistical analysis if desired. It's recommended that you explore the default output formats and the existing analytical tools first.

## Topics

### Essentials

- <doc:GettingStarted>

### Benchmarks

- <doc:WritingBenchmarks>
- <doc:Metrics>
- <doc:RunningBenchmarks>
- <doc:CreatingAndComparingBaselines>
- <doc:ComparingBenchmarksCI>
- <doc:ExportingBenchmarks>
- ``Benchmark/Benchmark``

### Configuring Benchmarks

- ``Benchmark/Benchmark/Configuration-swift.struct``
- ``Benchmark/BenchmarkMetric``
- ``Benchmark/BenchmarkTimeUnits``
- ``Benchmark/BenchmarkScalingFactor``

### Supporting Functions

- ``Benchmark/blackHole(_:)``
