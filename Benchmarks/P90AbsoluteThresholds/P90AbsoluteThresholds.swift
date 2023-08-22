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

let benchmarks = {
    var testName: String = "testName should be set"

    testName = "P90Date"
    Benchmark(testName, configuration: makeConfigurationFor(testName)) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(Foundation.Date())
        }
    }

    testName = "P90Malloc"
    Benchmark(testName, configuration: makeConfigurationFor(testName)) { benchmark in
        for _ in benchmark.scaledIterations {
            var array: [Int] = []
            array.append(contentsOf: 0...1000)
            blackHole(array)
        }
    }
}
