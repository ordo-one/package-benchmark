//
// Copyright (c) 2023 Ordo One AB
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0

import Benchmark
import DateTime

let benchmarks: @Sendable () -> Void = {
    Benchmark.defaultConfiguration = .init(metrics: [.throughput, .wallClock, .instructions] + .arc,
                                           warmupIterations: 10,
                                           scalingFactor: .kilo,
                                           maxDuration: .seconds(1),
                                           maxIterations: .kilo(10))

    Benchmark("InternalUTCClock-now") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(InternalUTCClock.now)
        }
    }

    Benchmark("BenchmarkClock-now") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(DateTime.BenchmarkClock.now)
        }
    }

    Benchmark("Foundation-Date") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(Foundation.Date())
        }
    }
}
