# Getting Started

## Prerequisites and platform support

The main external dependency is that the plugin uses the [jemalloc](https://jemalloc.net) memory allocation library.

It is a prerequisited install on any machine used for benchmarking, to be able to get the required malloc statistics.

It's used as it has extensive debug information with an accessible API for extracting it - in addition to having good runtime performance. 

The plugin depends on the [jemalloc module wrapper](https://github.com/ordo-one/package-jemalloc) for accessing it.

## Installing `jemalloc`

### macOS installing `jemalloc`
```
brew install jemalloc
````

### Ubuntu installing `jemalloc`
```
sudo apt-get install -y libjemalloc-dev
```

Some Linux distributions may have jemalloc already installed on the system.

## Add dependencies
Add a dependency on the plugin:
```
        .package(url: "https://github.com/ordo-one/package-benchmark", .upToNextMajor(from: "0.2.0")),
```

## Add exectuable targets

To add targets for benchmarking, you create an executable target for each benchmark suite that should be measured.
The source must reside as a subdirectory to a `Benchmarks` directory.

Each benchmark suite to be run *must have its source path in the Benchmarks folder* and depend on `BenchmarkSupport`, e.g.
```
            .executableTarget(
                name: "My-Benchmark",
                dependencies: [
                    .product(name: "BenchmarkSupport", package: "package-benchmark"),
                ],
                path: "Benchmarks/My-Benchmark"
            ),
```

## Baselines storage
The results from benchmark runs can be stored as benchmark baselines - they are then stored in your packages directory in a folder called `.benchmarkBaselines`.  

## Dedicated GitHub runner instances
For reproducible and good comparable results, it is *highly* recommended to set up a private GitHub runner that is
dedicated to performance benchmark runs.

## Howto
There's a [sample project](https://github.com/ordo-one/package-benchmark-samples) showing usage of the basic API which
can be a good starting point.
