//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//
import BenchmarkSupport

@main
extension BenchmarkRunner {}

// swiftlint disable: attributes
@_dynamicReplacement(for: registerBenchmarks)
func benchmarks() {
    Benchmark.defaultConfiguration = .init(desiredDuration: .seconds(5),
                                           desiredIterations: Int.max)

    Benchmark("Basic",
              configuration: .init(metrics: [.wallClock, .throughput])) { _ in
    }

    Benchmark("All metrics",
              configuration: .init(metrics: BenchmarkMetric.all, skip: true)) { _ in
    }
}
