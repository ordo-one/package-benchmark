//
// Copyright (c) 2022 Ordo One AB.
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

extension BenchmarkTool {
    func printMarkdown(_ markdown: String, terminator: String = "\n") {
        if format == .markdown {
            print(markdown, terminator: terminator)
        }
    }

    func printText(_ markdown: String, terminator: String = "\n") {
        if format == .text {
            print(markdown, terminator: terminator)
        }
    }

    func formatTableEntry(_ base: Int, _ comparison: Int, _ reversePolarity: Bool = false) -> Int {
        guard comparison != 0, base != 0 else {
            return 0
        }
        var roundedDiff = 100.0 - (100.0 * Double(comparison) / Double(base))
        roundedDiff.round(.toNearestOrAwayFromZero)
        let diff = Int(roundedDiff)

        if reversePolarity {
            return -1 * diff
        }
        return diff
    }

    func printMachine(_ machine: BenchmarkMachine, _ header: String) {
        printMarkdown("## ", terminator: "")
        print(header)
        printText("============================================================================================================================")
        print("")
        printMarkdown("```")
        print("Host '\(machine.hostname)' with \(machine.processors) '\(machine.processorType)' processors with \(machine.memory) GB memory, running:")
        print("\(machine.kernelVersion)")
        printMarkdown("```")
        printText("")
    }

    func prettyPrintByTest(_ baseline: BenchmarkBaseline) {
        let percentileWidth = 7
        let table = TextTable<BenchmarkResult> {
            [Column(title: "Metric", value: "\($0.metric.description) \($0.unitDescriptionPretty)", width: 40, align: .left),
             Column(title: "p0", value: $0.percentiles[.p0] ?? "n/a", width: percentileWidth, align: .right),
             Column(title: "p25", value: $0.percentiles[.p25] ?? "n/a", width: percentileWidth, align: .right),
             Column(title: "p50", value: $0.percentiles[.p50] ?? "n/a", width: percentileWidth, align: .right),
             Column(title: "p75", value: $0.percentiles[.p75] ?? "n/a", width: percentileWidth, align: .right),
             Column(title: "p90", value: $0.percentiles[.p90] ?? "n/a", width: percentileWidth, align: .right),
             Column(title: "p99", value: $0.percentiles[.p99] ?? "n/a", width: percentileWidth, align: .right),
             Column(title: "p100", value: $0.percentiles[.p100] ?? "n/a", width: percentileWidth, align: .right),
             Column(title: "Samples", value: $0.measurements, width: percentileWidth, align: .right)]
        }

        let keys = baseline.results.keys.sorted(by: { $0.name < $1.name })

        keys.forEach { key in
            if let value = baseline.results[key] {
                var allResults: [BenchmarkResult] = []
                value.forEach { result in
                    allResults.append(result)
                }

                allResults.sort(by: { $0.metric.description < $1.metric.description })
                printMarkdown("### ", terminator: "")
                print("\(key.name)")
                printMarkdown("")

                printMarkdown("```")
                table.print(allResults, style: Style.fancy)
                printMarkdown("```")
            }
        }
    }

    struct BenchmarkMetricTableEntry {
        var description: String
        var metrics: BenchmarkResult
    }

    func prettyPrintByMetric(_ baseline: BenchmarkBaseline) {
        var tableEntries: [BenchmarkMetric: [BenchmarkMetricTableEntry]] = [:]

        baseline.results.forEach { benchmarkIdentifier, benchmarkResults in
            benchmarkResults.forEach { result in
                if tableEntries[result.metric] == nil {
                    tableEntries[result.metric] = [BenchmarkMetricTableEntry(description: benchmarkIdentifier.name, metrics: result)]
                } else {
                    tableEntries[result.metric]?.append(BenchmarkMetricTableEntry(description: benchmarkIdentifier.name, metrics: result))
                }
            }
        }

        let percentileWidth = 7
        let table = TextTable<BenchmarkMetricTableEntry> {
            [Column(title: "Test", value: "\($0.description) \($0.metrics.unitDescriptionPretty)", width: 40, align: .left),
             Column(title: "p0", value: $0.metrics.percentiles[.p0] ?? "n/a", width: percentileWidth, align: .right),
             Column(title: "p25", value: $0.metrics.percentiles[.p25] ?? "n/a", width: percentileWidth, align: .right),
             Column(title: "p50", value: $0.metrics.percentiles[.p50] ?? "n/a", width: percentileWidth, align: .right),
             Column(title: "p75", value: $0.metrics.percentiles[.p75] ?? "n/a", width: percentileWidth, align: .right),
             Column(title: "p90", value: $0.metrics.percentiles[.p90] ?? "n/a", width: percentileWidth, align: .right),
             Column(title: "p99", value: $0.metrics.percentiles[.p99] ?? "n/a", width: percentileWidth, align: .right),
             Column(title: "p100", value: $0.metrics.percentiles[.p100] ?? "n/a", width: percentileWidth, align: .right),
             Column(title: "Samples", value: $0.metrics.measurements, width: percentileWidth, align: .right)]
        }

        let keys = tableEntries.keys.sorted(by: { $0.description < $1.description })
        keys.forEach { key in
            if let value = tableEntries[key] {
                var allResults: [BenchmarkMetricTableEntry] = []
                value.forEach { result in
                    allResults.append(result)
                }

                allResults.sort(by: { $0.description < $1.description })
                printMarkdown("### ", terminator: "")
                print("\(key)")
                printMarkdown("")

                printMarkdown("```")
                table.print(allResults, style: Style.fancy)
                printMarkdown("```")
            }
        }
    }

    func prettyPrint(_ baseline: BenchmarkBaseline,
                     header: String = "Benchmark results",
                     hostIdentifier _: String? = nil) {
        if quiet {
            return
        }
        if firstBenchmarkTool {
            printMachine(baseline.machine, header)
        }

        printMarkdown("## ", terminator: "")
        print("\(target)")
        printText("============================================================================================================================")
        print("")

        switch grouping {
        case .test:
            prettyPrintByTest(baseline)
        case .metric:
            prettyPrintByMetric(baseline)
        }
    }

    struct BenchmarkTableEntry {
        var description: String
        var metrics: BenchmarkResult
    }

    func prettyPrintDelta(_ baseline: BenchmarkBaseline,
                          hostIdentifier _: String? = nil) {
        guard let currentBaseline = currentBaseline else {
            print("No baseline available to compare with.")
            return
        }

        if quiet {
            return
        }

        if firstBenchmarkTool {
            printMachine(baseline.machine, "Comparing results with baseline")
            if currentBaseline.machine != baseline.machine {
                print("Warning: Machine configuration is different when comparing baselines, other config:")
                printMachine(currentBaseline.machine, "")
            }
        }

        printMarkdown("## ", terminator: "")
        print("\(target)")
        printText("============================================================================================================================")
        print("")

        var baseBaselineName: String
        var comparisonBaselineName: String
        if let baselineName = baselineName { // we compare with another known baseline instead of running
            baseBaselineName = "'\(baselineName)'"
        } else {
            baseBaselineName = "Baseline"
        }
        if let baselineNameSecond = baselineNameSecond { // we compare with another known baseline instead of running
            comparisonBaselineName = "'\(baselineNameSecond)'"
        } else {
            comparisonBaselineName = "Current run"
        }

        let keys = baseline.results.keys.sorted(by: { $0.name < $1.name })

        keys.forEach { key in
            if let value = baseline.results[key] {
                guard let baselineComparison = currentBaseline.results[key] else {
                    //       print("No baseline to compare with for `\(key.target):\(key.name)`.")
                    return
                }

                printMarkdown("### ", terminator: "")
                printText("----------------------------------------------------------------------------------------------------------------------------")
                print("\(key.name) metrics")
                printText("----------------------------------------------------------------------------------------------------------------------------")
                print("")

                value.forEach { currentResult in
                    var result = currentResult
                    if let base = baselineComparison.first(where: { $0.metric == result.metric }) {
                        if result == base {
//                            print(" \(result.metric) results were identical.")
//                            print("")
                        } else {
                            var hideResults: Bool = true

                            if result.betterResultsOrEqual(than: base, thresholds: result.thresholds ?? BenchmarkResult.PercentileThresholds.default) {
                                hideResults = true
                            } else {
                                hideResults = false
                            }

                            if format == .markdown {
                                if hideResults {
                                    print("<details><summary>\(result.metric): results within specified thresholds, fold down for details.</summary>")
                                    print("<p>")
                                    print("")
                                }
                            }
                            let percentileWidth = 7
                            let table = TextTable<BenchmarkTableEntry> {
                                [Column(title: "\(result.metric.description) \(result.unitDescriptionPretty)", value: $0.description, width: 40, align: .center),
                                 Column(title: "p0", value: $0.metrics.percentiles[.p0] ?? "n/a", width: percentileWidth, align: .right),
                                 Column(title: "p25", value: $0.metrics.percentiles[.p25] ?? "n/a", width: percentileWidth, align: .right),
                                 Column(title: "p50", value: $0.metrics.percentiles[.p50] ?? "n/a", width: percentileWidth, align: .right),
                                 Column(title: "p75", value: $0.metrics.percentiles[.p75] ?? "n/a", width: percentileWidth, align: .right),
                                 Column(title: "p90", value: $0.metrics.percentiles[.p90] ?? "n/a", width: percentileWidth, align: .right),
                                 Column(title: "p99", value: $0.metrics.percentiles[.p99] ?? "n/a", width: percentileWidth, align: .right),
                                 Column(title: "p100", value: $0.metrics.percentiles[.p100] ?? "n/a", width: percentileWidth, align: .right),
                                 Column(title: "Samples", value: $0.metrics.measurements, width: percentileWidth, align: .right)]
                            }

                            // Rescale result to base if needed
                            result.scaleResults(to: base)

                            var percentiles: [BenchmarkResult.Percentile: Int] = [:]

                            result.percentiles.forEach { percentile, value in
                                if let basePercentile = base.percentiles[percentile] {
                                    percentiles[percentile] = value - basePercentile
                                }
                            }

                            let deltaComparison = BenchmarkResult(metric: BenchmarkMetric.delta,
                                                                  timeUnits: result.timeUnits,
                                                                  measurements: result.measurements - base.measurements,
                                                                  warmupIterations: result.warmupIterations - base.warmupIterations,
                                                                  percentiles: percentiles)

                            let reversedPolarity = base.metric.polarity() == .prefersLarger

                            percentiles = [:]
                            result.percentiles.forEach { percentile, value in
                                if let basePercentile = base.percentiles[percentile] {
                                    percentiles[percentile] = formatTableEntry(basePercentile, value, reversedPolarity)
                                }
                            }

                            let percentageComparison = BenchmarkResult(metric: BenchmarkMetric.deltaPercentage,
                                                                       timeUnits: base.timeUnits,
                                                                       measurements: formatTableEntry(base.measurements, result.measurements, false),
                                                                       warmupIterations: formatTableEntry(base.warmupIterations, result.warmupIterations, true),
                                                                       percentiles: percentiles)

                            printMarkdown("```")
                            var tableEntries: [BenchmarkTableEntry] = []
                            tableEntries.append(BenchmarkTableEntry(description: baseBaselineName, metrics: base))
                            tableEntries.append(BenchmarkTableEntry(description: comparisonBaselineName, metrics: result))
                            tableEntries.append(BenchmarkTableEntry(description: BenchmarkMetric.delta.description, metrics: deltaComparison))
                            tableEntries.append(BenchmarkTableEntry(description: "Improvement %", metrics: percentageComparison))
                            table.print(tableEntries, style: Style.fancy)
                            printMarkdown("```")

                            if format == .markdown {
                                if hideResults {
                                    print("<p>")
                                    print("</details>")
                                    print("")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
