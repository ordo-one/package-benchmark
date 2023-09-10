//
// Copyright (c) 2023 Ordo One AB
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0

import Benchmark
import Foundation

let benchmarks = {
    var thresholds: [BenchmarkMetric: BenchmarkThresholds]
    let relative: BenchmarkThresholds.RelativeThresholds = [.p25: 25.0, .p50: 50.0, .p75: 75.0, .p90: 100.0, .p99: 101.0, .p100: 201.0]
    let absolute: BenchmarkThresholds.AbsoluteThresholds = [.p75: 999, .p90: 1_000, .p99: 1_001, .p100: 2_001]
    thresholds = [.mallocCountTotal: .init(relative: relative, absolute: absolute)]

    Benchmark.defaultConfiguration = .init(metrics: [.mallocCountTotal, .syscalls],
                                           warmupIterations: 1,
                                           scalingFactor: .kilo,
                                           maxDuration: .seconds(2),
                                           maxIterations: .kilo(100),
                                           thresholds: thresholds)

    Benchmark("P90Date") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(Foundation.Date())
        }
    }

    Benchmark("P90Malloc") { benchmark in
        for _ in benchmark.scaledIterations {
            var array: [Int] = []
            array.append(contentsOf: 0 ... 1_000)
            blackHole(array)
        }
    }
}
