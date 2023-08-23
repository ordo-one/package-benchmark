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
    Benchmark.defaultConfiguration = .init(metrics: [.mallocCountTotal, .syscalls],
                                           warmupIterations: 1,
                                           scalingFactor: .kilo,
                                           maxDuration: .seconds(2),
                                           maxIterations: .kilo(100))

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
