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
import Statistics

extension BenchmarkTool {
    private func printMarkdown(_ markdown: String, terminator: String = "\n") {
        if format == .markdown {
            print(markdown, terminator: terminator)
        }
    }

    private func printText(_ markdown: String, terminator: String = "\n") {
        if format == .text {
            print(markdown, terminator: terminator)
        }
    }

    private func formatTableEntry(_ base: Int, _ comparison: Int, _ reversePolarity: Bool = false) -> Int {
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

    private func printMachine(_ machine: BenchmarkMachine, _ header: String) {
        let separator = String(repeating: "=", count: machine.kernelVersion.count)
        print("")
        printMarkdown("## ", terminator: "")
        printText(separator)
        print(header)
        printText(separator)
        print("")
        printMarkdown("```")
        print("Host '\(machine.hostname)' with \(machine.processors) '\(machine.processorType)' processors with \(machine.memory) GB memory, running:")
        print("\(machine.kernelVersion)")
        printMarkdown("```")
        printText("")
    }

    private func scaledValue(result: BenchmarkResult, value: Int) -> Int {
        guard self.scale > 0 else {
            return value
        }
        return value / result.scalingFactor.rawValue
    }

    func shouldScale(_ metric: BenchmarkMetric) -> Bool {
        switch metric {
        case .cpuSystem, .cpuTotal, .cpuUser, .wallClock:
            return true
        case .mallocCountLarge, .mallocCountSmall, .mallocCountTotal, .memoryLeaked:
            return true
        case .syscalls, .throughput:
            return true
        case .readSyscalls, .readBytesLogical, .readBytesPhysical:
            return true
        case .writeSyscalls, .writeBytesLogical, .writeBytesPhysical:
            return true
        case .custom:
            return true
        default:
            return false
        }
    }

    private func scaledPercentile(_ result: BenchmarkResult, _ percentile: Statistics.Percentile) -> Int? {
        let percentiles = result.statistics.percentiles()

        let percentileValue = percentiles[percentile.rawValue]

        guard shouldScale(result.metric) else {
            return percentileValue
        }

//        return percentileValue
        let factor = BenchmarkScalingFactor(result.timeUnits)
        let scaledResult = percentileValue / factor.rawValue / result.scalingFactor.rawValue
//        418 490875903 / 1000000000
//        Memory (virtual peak) p99 418490875903, 1000000000, 1000

        print("\(result.metric) \(percentile) \(percentileValue), \(factor.rawValue), \(result.scalingFactor.rawValue)")
        return scaledResult
    }
/*
    private func scale(results: [BenchmarkBaseline.ResultsEntry]) -> [BenchmarkBaseline.ResultsEntry] {

  //      return results.map { result
//            $0.metrics.map {

//            }
//        }
        results.forEach { results in
            let units = Statistics.Units(results.metrics.timeUnits)
            results.metrics.
            print("Units \(units) for \(results.metrics.timeUnits)")
        }
        let scaledResults = results
        scaledResults.forEach { resultEntry in
//            resultEntry.metrics.
        }
        return results
    }

    private func scaledUnits(results: BenchmarkBaseline.ResultsEntry) -> BenchmarkBaseline.ResultsEntry {
        let units = Statistics.Units(results.metrics.timeUnits)

        print("Units \(units) for \(results.metrics.timeUnits)")
        return results
    }
*/
    private func _prettyPrint(title: String,
                              key: String,
                              results: [BenchmarkBaseline.ResultsEntry],
                              width: Int = 30) {
        let percentileWidth = 7
        let table = TextTable<BenchmarkBaseline.ResultsEntry> {
            [Column(title: title, value: "\($0.description) \($0.metrics.unitDescriptionPretty)", width: width, align: .left),
             Column(title: "p0", value: scaledPercentile($0.metrics, .p0) ?? "n/a", width: percentileWidth, align: .right),
             Column(title: "p25", value: scaledPercentile($0.metrics, .p25) ?? "n/a", width: percentileWidth, align: .right),
             Column(title: "p50", value: scaledPercentile($0.metrics, .p50) ?? "n/a", width: percentileWidth, align: .right),
             Column(title: "p75", value: scaledPercentile($0.metrics, .p75) ?? "n/a", width: percentileWidth, align: .right),
             Column(title: "p90", value: scaledPercentile($0.metrics, .p90) ?? "n/a", width: percentileWidth, align: .right),
             Column(title: "p99", value: scaledPercentile($0.metrics, .p99) ?? "n/a", width: percentileWidth, align: .right),
             Column(title: "p100", value: scaledPercentile($0.metrics, .p100) ?? "n/a", width: percentileWidth, align: .right),
             Column(title: "Samples", value: $0.metrics.statistics.measurementCount, width: percentileWidth, align: .right)]
        }

        let scaledResults = results // scale(results: results)
        printMarkdown("### ", terminator: "")
        print("\(key)")
        printMarkdown("")

        printMarkdown("```")
        table.print(scaledResults, style: Style.fancy)
        printMarkdown("```")
    }

    func prettyPrint(_ baseline: BenchmarkBaseline,
                     header: String, // = "Benchmark results",
                     hostIdentifier _: String? = nil) {
        if quiet > 0 {
            return
        }

        printMachine(baseline.machine, header)

        switch grouping {
        case .benchmark:
            var width = 10
            let metrics = baseline.metricsMatching { _, _ in true }
            metrics.forEach { metric in
                width = max(width, metric.description.count)
            }
            width = min(70, width + 5) // add 5 for ' (M)'

            baseline.targets.forEach { target in
                let separator = String(repeating: "=", count: "\(target)".count)
                printMarkdown("## ", terminator: "")
                printText(separator)
                print("\(target)")
                printText(separator)
                print("")
                baseline.benchmarkNames.forEach { benchmarkName in
                    let results = baseline.resultEntriesMatching { identifier, result in
                        (identifier.name == benchmarkName && identifier.target == target, result.metric.description)
                    }
                    if results.count > 0 {
                        _prettyPrint(title: "Metric", key: benchmarkName, results: results, width: width)
                    }
                }
            }
        case .metric:
            var width = 10
            baseline.benchmarkIdentifiers.forEach { identifier in
                width = max(width, "\(identifier.target):\(identifier.name)".count)
            }
            width = min(70, width + 5) // add 5 for ' (M)'

            baseline.benchmarkMetrics.forEach { metric in

                let results = baseline.resultEntriesMatching { identifier, result in
                    (result.metric == metric, "\(identifier.target):\(identifier.name)")
                }
                _prettyPrint(title: "Test", key: metric.description, results: results, width: width)
            }
        }
    }

    func prettyPrintDelta(currentBaseline: BenchmarkBaseline,
                          baseline: BenchmarkBaseline,
                          hostIdentifier _: String? = nil) {
        printMachine(baseline.machine, "Comparing results with baseline")
        if currentBaseline.machine != baseline.machine {
            print("Warning: Machine configuration is different when comparing baselines, other config:")
            printMachine(currentBaseline.machine, "")
        }

        baseline.targets.forEach { target in

            printMarkdown("## ", terminator: "")
            print("\(target)")
            printText("============================================================================================================================")
            print("")

            let baseBaselineName = currentBaseline.baselineName
            let comparisonBaselineName = baseline.baselineName

            var keys = baseline.results.keys.sorted(by: { $0.name < $1.name })

            keys.removeAll(where: { $0.target == target })
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
                                let table = TextTable<BenchmarkBaseline.ResultsEntry> {
                                    [Column(title: "\(result.metric.description) \(result.unitDescriptionPretty)", value: $0.description, width: 40, align: .center),
                                     Column(title: "p0", value: scaledPercentile($0.metrics, .p0) ?? "n/a", width: percentileWidth, align: .right),
                                     Column(title: "p25", value: scaledPercentile($0.metrics,.p25) ?? "n/a", width: percentileWidth, align: .right),
                                     Column(title: "p50", value: scaledPercentile($0.metrics,.p50) ?? "n/a", width: percentileWidth, align: .right),
                                     Column(title: "p75", value: scaledPercentile($0.metrics,.p75) ?? "n/a", width: percentileWidth, align: .right),
                                     Column(title: "p90", value: scaledPercentile($0.metrics,.p90) ?? "n/a", width: percentileWidth, align: .right),
                                     Column(title: "p99", value: scaledPercentile($0.metrics,.p99) ?? "n/a", width: percentileWidth, align: .right),
                                     Column(title: "p100", value: scaledPercentile($0.metrics,.p100) ?? "n/a", width: percentileWidth, align: .right),
                                     Column(title: "Samples", value: $0.metrics.statistics.measurementCount, width: percentileWidth, align: .right)]
                                }

                                // Rescale result to base if needed
//                                result.scaleResults(to: base)
/*
                                var percentiles: [Statistics.Percentile: Int] = [:]

                                result.percentiles.forEach { percentile, value in
                                    if let basePercentile = base.percentiles[percentile] {
                                        percentiles[percentile] = value - basePercentile
                                    }
                                }

                                let percentiles: [Statistics.Percentile: Int] = [:]
                                let deltaComparison = BenchmarkResult(metric: BenchmarkMetric.delta,
                                                                      timeUnits: result.timeUnits,
                                                                      scalingFactor: result.scalingFactor,
//                                                                      measurements: result.statistics.measurementCount - base.statistics.measurementCount,
                                                                      warmupIterations: result.warmupIterations - base.warmupIterations,
  //                                                                    percentiles: percentiles)

                                let reversedPolarity = base.metric.polarity() == .prefersLarger

                                percentiles = [:]
                                result.percentiles.forEach { percentile, value in
                                    if let basePercentile = base.percentiles[percentile] {
                                        percentiles[percentile] = formatTableEntry(basePercentile, value, reversedPolarity)
                                    }
                                }

                                let percentageComparison = BenchmarkResult(metric: BenchmarkMetric.deltaPercentage,
                                                                           timeUnits: base.timeUnits,
                                                                           scalingFactor: base.scalingFactor,
                                                                           measurements: formatTableEntry(base.measurements, result.measurements, false),
                                                                           warmupIterations: formatTableEntry(base.warmupIterations, result.warmupIterations, true),
                                                                           percentiles: percentiles)

                                printMarkdown("```")
                                var tableEntries: [BenchmarkBaseline.ResultsEntry] = []
                                tableEntries.append(BenchmarkBaseline.ResultsEntry(description: baseBaselineName, metrics: base))
                                tableEntries.append(BenchmarkBaseline.ResultsEntry(description: comparisonBaselineName, metrics: result))
                                tableEntries.append(BenchmarkBaseline.ResultsEntry(description: BenchmarkMetric.delta.description, metrics: deltaComparison))
                                tableEntries.append(BenchmarkBaseline.ResultsEntry(description: "Improvement %", metrics: percentageComparison))
                                table.print(tableEntries, style: Style.fancy)
                                printMarkdown("```")
 */

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
}
