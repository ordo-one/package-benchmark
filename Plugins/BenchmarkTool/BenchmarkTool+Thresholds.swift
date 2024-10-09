//
// Copyright (c) 2024 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

import Benchmark
import SystemPackage
import TextTable

private let percentileWidth = 20
private let maxDescriptionWidth = 40

fileprivate struct ThresholdsTableEntry {
    var description: String
    var p90: Int
    var absolute: Int
    var relative: Double
}

extension BenchmarkTool {
    func printThresholds(_ staticThresholdsPerBenchmark: [BenchmarkIdentifier : [BenchmarkMetric: BenchmarkThresholds.AbsoluteThreshold]]) {

        guard !staticThresholdsPerBenchmark.isEmpty else {
            print("No thresholds defined.")
            return
        }

        print("")

        var tableEntries: [ThresholdsTableEntry] = []
        let table = TextTable<ThresholdsTableEntry> {
            [Column(title: "Metric", value: "\($0.description)", width: maxDescriptionWidth, align: .left),
             Column(title: "Threshold .p90", value: $0.p90, width: percentileWidth, align: .right),
             Column(title: "Allowed %", value: $0.relative, width: percentileWidth, align: .right),
             Column(title: "Allowed Δ", value: $0.absolute, width: percentileWidth, align: .right)]
        }

        staticThresholdsPerBenchmark.forEach { benchmarkIdentifier, staticThresholds in
            print("\(benchmarkIdentifier.name)")

            let thresholdDeviations = benchmarks.first(where: { benchmarkIdentifier == .init(target: $0.target,
                                                                                       name: $0.name)})?.configuration.thresholds ?? .init()

            staticThresholds.forEach { threshold in
                let absoluteThreshold = thresholdDeviations[threshold.key]?.absolute[.p90] ?? 0
                let relativeThreshold = thresholdDeviations[threshold.key]?.relative[.p90] ?? 0

                tableEntries.append(.init(description: threshold.key.description,
                                          p90: threshold.value,
                                          absolute: absoluteThreshold,
                                          relative: relativeThreshold))
            }
            table.print(tableEntries, style: format.tableStyle)
            tableEntries = []
        }
    }
}
