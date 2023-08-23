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
import Foundation

func makeConfigurationFor(_ name: String) -> Benchmark.Configuration {
    // https://forums.swift.org/t/pitch-introduce-module-to-get-the-current-module-name/45806/8
    let moduleName = String("\(#fileID)".prefix(while: { $0 != "/" }))

    var configuration: Benchmark.Configuration = .init(metrics: [.mallocCountTotal, .syscalls] + .arc,
                                                       warmupIterations: 1,
                                                       scalingFactor: .kilo,
                                                       maxDuration: .seconds(2),
                                                       maxIterations: .kilo(100))

    configuration.thresholds = BenchmarkThresholds.makeBenchmarkThresholds(path: FileManager.default.currentDirectoryPath,
                                                                           moduleName: moduleName,
                                                                           benchmarkName: name)
    // if thresholds are nil here, we failed to read anything from the file and might want to warn or set up
    // other thresholds
    return configuration
}

let benchmarks = {
    var testName: String!

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
            array.append(contentsOf: 0 ... 1_000)
            blackHole(array)
        }
    }
}
