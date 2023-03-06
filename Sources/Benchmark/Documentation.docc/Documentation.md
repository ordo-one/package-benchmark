# ``Benchmark``

Benchmark is a harness for easily creating Swift performance benchmarks for both macOS and Linux.

## Overview

Performance is a key feature for many apps and frameworks. Benchmark helps make it easy to measure and track many different metrics that affects performance, such as CPU usage, memory usage and use of operating system resources such as threads and system calls.

Benchmark supports several key workflows for performance measurements, e.g.:

* **Automated Pull Request performance regression checks** by comparing the performance metrics of a pull request with the main branch and having the PR check fail if there is a regression (e.g. no added memory allocations, or that the runtime was at least as good) with ready to use workflows for GitHub CI
* **Manual comparison of multiple performance baselines** for iterative or A/B performance work by an individual developer
* **Export of benchmark results in several formats** such as JMH (Java Microbenchmark Harness), TSV (tab-separated-values), [HDR Histogram](http://hdrhistogram.org) ([analysis](http://www.david-andrzejewski.com/publications/hdr.pdf)), etc. This allows for tracking performance over time or analyzing/visualizing with other tools such as [JMH visualizer](https://jmh.morethan.io), [Gnuplot](http://www.gnuplot.info), [YouPlot](https://github.com/red-data-tools/YouPlot), [HDR Histogram analyzer](http://hdrhistogram.github.io/HdrHistogram/plotFiles.html) and more.

Benchmark provides a quick way for validation of performance metrics, while other more specialized tools such as Instruments, DTrace, Heaptrack, Leaks, Sample and more can be used for finding root causes for any deviations found.

Benchmark is suitable for both smaller ad-hoc benchmarks only caring about runtime (in the spirit of [Google's swift-benchmark](https://github.com/google/swift-benchmark)) and more extensive benchmarks that care about additional metrics such as memory allocations, syscalls, thread usage and more. Thanks to the HDR Histogram foundation it's especially suitable for capturing latency statistics for large number of samples.

The default text output from Benchmark is oriented around [the five-number summary](https://en.wikipedia.org/wiki/Five-number_summary) percentiles, plus the last decile (`p90`) and the last percentile (`p99`) - it's thus a variation of a [seven-figure summary](https://en.wikipedia.org/wiki/Seven-number_summary) with the focus on the 'bad' end of results (as those are what we typically care about addressing).

We've found that focusing on percentiles rather than average or standard deviations as is common, is more useful for a wider range of benchmark measurements and allow for a consistent way of expressing benchmark results and CI thresholds deviations looking at both throughput and latency measurements (which typically do **not** have a standardized distribution and almost always are multi-modal in nature).

That being said, some of the export formats do include more traditional average/stddev type of values and the Benchmark infrastructure actually captures _all_ samples for a test run, so there are even export functionality for all the raw data points for arbitrary post-run statistical analysis as desired.

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:WritingBenchmarks>
- <doc:ConfiguringBenchmarks>
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
