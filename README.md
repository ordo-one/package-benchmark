# Benchmark 

## Introduction

Benchmark is a harness for easily creating Swift performance benchmarks for both macOS and Linux.

It's intended to be suitable for both ad-hoc smaller benchmarks primarily caring about runtime (in the spirit of [Google's swift-benchmark](https://github.com/google/swift-benchmark)) as well for more extensive benchmarks caring about additional benchmark metrics such as memory allocations, syscalls, thread usage and more.

Benchmark supports both local usage with baseline comparisons for an iterative workflow for the individual developer, but more importantly has good support for integration with GitHub CI with provided sample workflows for automated comparisons between `main` and a pull request branch to support enforced performance validation for pull requests with customizable thresholds - this is the primary intended use case for the package.

The focus for measurements are percentiles (`p0` (min), `p25`, `p50` (median), `p75`, `p90`, `p99` and `p100` (max)) to support analysis of the actual distribution of benchmark measurements. A given benchmark is typically run for a minimum amount of time and/or a given number of iterations, see details in the Benchmark documentation below.

### Sample output

<img width="877" alt="image" src="https://user-images.githubusercontent.com/8501048/192326477-c5fc5ec8-e77a-469e-a1b3-2f5d40754cb4.png">

## Contents

- [Getting started and initial setup](Documentation/GettingStarted.md)
- [Writing benchmarks](Documentation/WritingBenchmarks.md)
- [Running benchmarks](Documentation/RunningBenchmarks.md)
- [Performance metrics and thresholds](Documentation/Metrics.md)
- [Typical workflows (manual and CI)](Documentation/Workflows.md)
- [Laundry list](Documentation/TODO.md)

There's also [a sample project](https://github.com/ordo-one/package-benchmark-samples) using various aspects of this package for those who just want to see how it can be used in practice
