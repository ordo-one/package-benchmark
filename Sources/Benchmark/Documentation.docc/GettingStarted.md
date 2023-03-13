# Getting Started

Before creating your own benchmarks, you must install the required prerequisites and add a dependency on Benchmark to your package.

## Overview

There are three steps that needs to be performed to get up and running with your own benchmarks:

* Install prerequisite dependencies if needed (currently that's only `jemalloc`) 
* Add a dependency on Benchmark to your `Package.swift` file
* Add one or more benchmark executable targets to the top level `Benchmarks/` directory for auto discovery

After having done those, running your benchmarks are as simple as running `swift package benchmark`.

### Installing Prerequisites and Platform Support

Benchmark requires Swift 5.7 support as it uses Regex and Duration types introduced with the `macOS 13` runtime, most versions of Linux will work as long as Swift 5.7+ is used. 

Benchmark also depends and needs the [jemalloc](https://jemalloc.net) memory allocation library, which is used by the Benchmark infrastructure to capture memory allocation statistics, as `jemalloc` provides a rich programmatic API for extracting memory allocation statistics at runtime. 

The Benchmark package requires you to install jemalloc on any machine used for benchmarking. 

If you want to avoid adding the `jemalloc` dependency to your project, the recommended approach is to embed a separate Swift project in a subdirectory that uses your project, then the dependency on `jemalloc` is contained to that subproject only.

#### Installing `jemalloc` on macOS

```
brew install jemalloc
````

#### Installing `jemalloc` on Ubuntu

```
sudo apt-get install -y libjemalloc-dev
```

#### Installing `jemalloc` on Amazon Linux 2 
For Amazon Linux 2 users have reported that the following works:

Docker file configuration
```dockerfile
RUN sudo yum -y install bzip2 make
RUN curl https://github.com/jemalloc/jemalloc/releases/download/5.3.0/jemalloc-5.3.0.tar.bz2 -L -o jemalloc-5.3.0.tar.bz2
RUN tar -xf jemalloc-5.3.0.tar.bz2
RUN cd jemalloc-5.3.0 && ./configure && make && sudo make install
```

`make install` installs the libraries in `/usr/local/lib`, which the plugin can’t find, so you also have to do:

```
$ sudo ldconfig /usr/local/lib
```

Alternatively:
```
echo /usr/local/lib > /etc/ld.so.conf.d/local_lib.conf && ldconfig
```

### Adding dependencies

To add the dependency on Benchmark, add a dependency to your package:

```swift
.package(url: "https://github.com/ordo-one/package-benchmark", .upToNextMajor(from: "1.0.0")),
```

### Add benchmark exectuable targets

Create an executable target in `Package.swift` for each benchmark suite you want to measure.

The source for all benchmarks *must reside in a directory named `Benchmarks`* in the root of your swift package.

The benchmark plugin uses this directory combined with the executable target information to automatically discover and run your benchmarks.

For each executable target, include a dependency on `BenchmarkSupport` from `package-benchmark`.

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

### Dedicated GitHub runner instances

For reproducible and good comparable results, it is *highly* recommended to set up a private GitHub runner that is completely dedicated for performance benchmark runs, as the standard GitHub CI runners are deployed on a shared infrastructure the deviations between runs can be significant and difficult to assess.

### Sample Project

There's a [sample project](https://github.com/ordo-one/package-benchmark-samples) showing usage of the basic API which can be a good starting point if you want to look at how a project can be setup.
