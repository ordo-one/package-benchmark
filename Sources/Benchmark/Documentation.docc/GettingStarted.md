# Getting Started

Before creating your own benchmarks, install the required prerequisites and add benchmarks to your package.

## Overview

Deeper introduction
On multiple lines (sentences), of course.

### Prerequisites and platform support

The main external dependency is [jemalloc](https://jemalloc.net).The plugin that runs the benchmarks uses jemalloc memory allocation library to provide malloc statistics.
The Benchmark package requires you to install jemalloc on any machine used for benchmarking.

Benchmark uses jemalloc because it has extensive debug information with an accessible API for extracting it, in addition to having good runtime performance.

The plugin depends on the [jemalloc module wrapper](https://github.com/ordo-one/package-jemalloc) for accessing it.

#### Installing `jemalloc` on macOS

```
brew install jemalloc
````

#### Installing `jemalloc` on Ubuntu

```
sudo apt-get install -y libjemalloc-dev
```

Other Linux distributions may come with jemalloc already installed.

### Add dependencies

If you're adding benchmarks to an existing package, add a dependency to the overall package:

```
.package(url: "https://github.com/ordo-one/package-benchmark", .upToNextMajor(from: "0.2.0")),
```

Benchmark requires Swift 5.7 support. If the package that you want to benchmark supports older versions of Swift, create a new package that includes this dependency, as well as a dependency on your library.

### Add exectuable targets

Create an executable target in `Package.swift` for each benchmark suite you want to measure.
The source for all benchmarks *must reside in a directory named `Benchmarks`* in the root of your swift package.
The benchmark plugin relies on the source existing within this directory to discover and run your benchmarks.
Include a dependency in each executable target to `BenchmarkSupport`.
The following example shows an benchmark suite named `My-Benchmark` with the required dependency on `BenchmarkSupport` and the source files for the benchmark that reside in the directory `Benchmarks/My-Benchmark`:

```
.executableTarget(
    name: "My-Benchmark",
    dependencies: [
        .product(name: "BenchmarkSupport", package: "package-benchmark"),
    ],
    path: "Benchmarks/My-Benchmark"
),
```

### Baselines storage

You can store the results results from benchmark runs as baselines for use in later comparison.
Baselines are stored in your package in the directory `.benchmarkBaselines`.  

### Dedicated GitHub runner instances

For reproducible and good comparable results, it is *highly* recommended to set up a private GitHub runner that is
dedicated to performance benchmark runs.

### Sample Project

There's a [sample project](https://github.com/ordo-one/package-benchmark-samples) showing usage of the basic API which
can be a good starting point.
