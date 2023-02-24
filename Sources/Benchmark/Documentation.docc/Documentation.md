# ``Benchmark``

Benchmark is a harness for easily creating Swift performance benchmarks for both macOS and Linux.

## Overview

More detail about Benchmark, why it's relevant, and intro to what's included.
On more than one line, generally.

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
