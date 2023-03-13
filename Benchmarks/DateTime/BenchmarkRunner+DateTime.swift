// Copyright 2023 Ordo One AB
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0

import DateTime

import BenchmarkSupport
@main
extension BenchmarkRunner {}

@_dynamicReplacement(for: registerBenchmarks)
func benchmarks() {
    Benchmark.defaultConfiguration = .init(metrics: [.throughput, .wallClock],
                                           warmupIterations: 10,
                                           scalingFactor: .kilo,
                                           maxDuration: .seconds(1),
                                           maxIterations: .kilo(10))

    Benchmark("InternalUTCClock-now") { benchmark in
        for _ in benchmark.scaledIterations {
            BenchmarkSupport.blackHole(InternalUTCClock.now)
        }
    }

    Benchmark("BenchmarkClock-now") { benchmark in
        for _ in benchmark.scaledIterations {
            BenchmarkSupport.blackHole(BenchmarkClock.now)
        }
    }

    Benchmark("Foundation-Date") { benchmark in
        for _ in benchmark.scaledIterations {
            BenchmarkSupport.blackHole(Foundation.Date())
        }
    }
}
