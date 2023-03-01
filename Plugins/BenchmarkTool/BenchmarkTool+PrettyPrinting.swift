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

fileprivate let percentileWidth = 10

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
 /*
    private func scaledPercentile(_ result: BenchmarkResult, _ percentile: BenchmarkResult.Percentile) -> Int? {
        let percentiles = result.statistics.percentiles()
        let percentileValue = percentiles[percentile.rawValue]

        if self.scale == 0 || result.scaledTimeUnits == result.timeUnits {
            return percentileValue / BenchmarkScalingFactor(result.timeUnits).rawValue
        }

        if result.scaledTimeUnits == result.timeUnits {
            return percentileValue
        }

        guard result.metric.useScalingFactor else {
            if result.scaledTimeUnits == result.timeUnits {
                return percentileValue
            }
            return percentileValue / BenchmarkScalingFactor(result.timeUnits).rawValue
        }
/*
        guard result.metric.useScaleFactor || result.scaledScalingFactor != .none else {
            if result.scaledTimeUnits == result.timeUnits {
                return percentileValue
            }
            return percentileValue / BenchmarkScalingFactor(result.timeUnits).rawValue
        }
*/
//        let scaledDivisor = result.scaledScalingFactor == .none ? BenchmarkScalingFactor(result.timeUnits) : BenchmarkScalingFactor(result.scaledTimeUnits)
        let scaledDivisor = BenchmarkScalingFactor(result.scaledTimeUnits)
        let scaledResult = percentileValue // result.scaledScalingFactor.rawValue / scaledDivisor.rawValue

//        Throughput (scaled / s),mega, mega, p90, 11911823359, 1000
//print("\(percentileValue) / \(result.scaledScalingFactor.rawValue) / \(scaledDivisor.rawValue)")
//        print("\(result.metric),\(scaledDivisor), \(result.scaledScalingFactor), \(percentile), \(percentileValue), \(result.scalingFactor.rawValue)")
        return scaledResult
    }
*/
    fileprivate struct ScaledResults {
        let description: String
        let p0:Int
        let p25:Int
        let p50:Int
        let p75:Int
        let p90:Int
        let p99:Int
        let p100:Int
        let samples:Int
    }

    private func _prettyPrint(title: String,
                              key: String,
                              results: [BenchmarkBaseline.ResultsEntry],
                              width: Int = 30) {

        let table = TextTable<ScaledResults> {
            [Column(title: title, value: "\($0.description)", width: width, align: .left),
             Column(title: "p0", value: $0.p0, width: percentileWidth, align: .right),
             Column(title: "p25", value: $0.p25, width: percentileWidth, align: .right),
             Column(title: "p50", value: $0.p50, width: percentileWidth, align: .right),
             Column(title: "p75", value: $0.p75, width: percentileWidth, align: .right),
             Column(title: "p90", value: $0.p90, width: percentileWidth, align: .right),
             Column(title: "p99", value: $0.p99, width: percentileWidth, align: .right),
             Column(title: "p100", value: $0.p100, width: percentileWidth, align: .right),
             Column(title: "Samples", value: $0.samples, width: percentileWidth, align: .right)]
        }

        var scaledResults: [ScaledResults] = []
        results.forEach { result in
            let description: String
            let percentiles = result.metrics.statistics.percentiles()
            let p0, p25, p50, p75, p90, p99, p100: Int

            if self.scale > 0 && result.metrics.metric.useScalingFactor {
                description = "\(result.metrics.metric.description) \(result.metrics.scaledUnitDescriptionPretty)"
                p0 = result.metrics.scale(percentiles[0])
                p25 = result.metrics.scale(percentiles[1])
                p50 = result.metrics.scale(percentiles[2])
                p75 = result.metrics.scale(percentiles[3])
                p90 = result.metrics.scale(percentiles[4])
                p99 = result.metrics.scale(percentiles[5])
                p100 = result.metrics.scale(percentiles[6])
            } else {
                description = "\(result.metrics.metric.description) \(result.metrics.unitDescriptionPretty)"
                p0 = result.metrics.normalize(percentiles[0])
                p25 = result.metrics.normalize(percentiles[1])
                p50 = result.metrics.normalize(percentiles[2])
                p75 = result.metrics.normalize(percentiles[3])
                p90 = result.metrics.normalize(percentiles[4])
                p99 = result.metrics.normalize(percentiles[5])
                p100 = result.metrics.normalize(percentiles[6])
            }

            scaledResults.append(ScaledResults(description: description,
                                               p0: p0,
                                               p25: p25,
                                               p50: p50,
                                               p75: p75,
                                               p90: p90,
                                               p99: p99,
                                               p100: p100,
                                               samples: result.metrics.statistics.measurementCount))
        }


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

                                let title = "\(result.metric.description) \(result.unitDescriptionPretty)"
                                let width = 40
                                let table = TextTable<ScaledResults> {
                                    [Column(title: title, value: "\($0.description)", width: width, align: .center),
                                     Column(title: "p0", value: $0.p0, width: percentileWidth, align: .right),
                                     Column(title: "p25", value: $0.p25, width: percentileWidth, align: .right),
                                     Column(title: "p50", value: $0.p50, width: percentileWidth, align: .right),
                                     Column(title: "p75", value: $0.p75, width: percentileWidth, align: .right),
                                     Column(title: "p90", value: $0.p90, width: percentileWidth, align: .right),
                                     Column(title: "p99", value: $0.p99, width: percentileWidth, align: .right),
                                     Column(title: "p100", value: $0.p100, width: percentileWidth, align: .right),
                                     Column(title: "Samples", value: $0.samples, width: percentileWidth, align: .right)]
                                }

                                // Rescale result to base if needed
                                result.timeUnits = base.timeUnits

                                var scaledResults: [ScaledResults] = []

                                let percentiles = result.statistics.percentiles()
                                let basePercentiles = base.statistics.percentiles()

                                var p0, p25, p50, p75, p90, p99, p100: Int

                                if self.scale > 0 && base.metric.useScalingFactor {
                                    p0 = base.scale(basePercentiles[0])
                                    p25 = base.scale(basePercentiles[1])
                                    p50 = base.scale(basePercentiles[2])
                                    p75 = base.scale(basePercentiles[3])
                                    p90 = base.scale(basePercentiles[4])
                                    p99 = base.scale(basePercentiles[5])
                                    p100 = base.scale(basePercentiles[6])
                                } else {
                                    p0 = base.normalize(basePercentiles[0])
                                    p25 = base.normalize(basePercentiles[1])
                                    p50 = base.normalize(basePercentiles[2])
                                    p75 = base.normalize(basePercentiles[3])
                                    p90 = base.normalize(basePercentiles[4])
                                    p99 = base.normalize(basePercentiles[5])
                                    p100 = base.normalize(basePercentiles[6])
                                }
                                scaledResults.append(ScaledResults(description: baseBaselineName,
                                                                   p0: p0,
                                                                   p25: p25,
                                                                   p50: p50,
                                                                   p75: p75,
                                                                   p90: p90,
                                                                   p99: p99,
                                                                   p100: p100,
                                                                   samples: base.statistics.measurementCount))


                                if self.scale > 0 && result.metric.useScalingFactor {
                                    p0 = result.scale(percentiles[0])
                                    p25 = result.scale(percentiles[1])
                                    p50 = result.scale(percentiles[2])
                                    p75 = result.scale(percentiles[3])
                                    p90 = result.scale(percentiles[4])
                                    p99 = result.scale(percentiles[5])
                                    p100 = result.scale(percentiles[6])
                                } else {
                                    p0 = result.normalize(percentiles[0])
                                    p25 = result.normalize(percentiles[1])
                                    p50 = result.normalize(percentiles[2])
                                    p75 = result.normalize(percentiles[3])
                                    p90 = result.normalize(percentiles[4])
                                    p99 = result.normalize(percentiles[5])
                                    p100 = result.normalize(percentiles[6])
                                }

                                scaledResults.append(ScaledResults(description: comparisonBaselineName,
                                                                   p0: p0,
                                                                   p25: p25,
                                                                   p50: p50,
                                                                   p75: p75,
                                                                   p90: p90,
                                                                   p99: p99,
                                                                   p100: p100,
                                                                   samples: result.statistics.measurementCount))






                                if self.scale > 0 && result.metric.useScalingFactor {
                                    p0 = result.scale(percentiles[0]) - base.scale(basePercentiles[0])
                                    p25 = result.scale(percentiles[1]) - base.scale(basePercentiles[1])
                                    p50 = result.scale(percentiles[2]) - base.scale(basePercentiles[2])
                                    p75 = result.scale(percentiles[3]) - base.scale(basePercentiles[3])
                                    p90 = result.scale(percentiles[4]) - base.scale(basePercentiles[4])
                                    p99 = result.scale(percentiles[5]) - base.scale(basePercentiles[5])
                                    p100 = result.scale(percentiles[6]) - base.scale(basePercentiles[6])
                                } else {
                                    p0 = result.normalize(percentiles[0]) - base.normalize(basePercentiles[0])
                                    p25 = result.normalize(percentiles[1]) - base.normalize(basePercentiles[1])
                                    p50 = result.normalize(percentiles[2]) - base.normalize(basePercentiles[2])
                                    p75 = result.normalize(percentiles[3]) - base.normalize(basePercentiles[3])
                                    p90 = result.normalize(percentiles[4]) - base.normalize(basePercentiles[4])
                                    p99 = result.normalize(percentiles[5]) - base.normalize(basePercentiles[5])
                                    p100 = result.normalize(percentiles[6]) - base.normalize(basePercentiles[6])
                                }

                                let samples = result.statistics.measurementCount - base.statistics.measurementCount
                                scaledResults.append(ScaledResults(description: BenchmarkMetric.delta.description,
                                                                   p0: p0,
                                                                   p25: p25,
                                                                   p50: p50,
                                                                   p75: p75,
                                                                   p90: p90,
                                                                   p99: p99,
                                                                   p100: p100,
                                                                   samples: samples))

                                let reversedPolarity = base.metric.polarity == .prefersLarger


                                if self.scale > 0 && result.metric.useScalingFactor {
                                    p0 = formatTableEntry(base.scale(basePercentiles[0]),
                                                                     result.scale(percentiles[0]),
                                                                                  reversedPolarity)
                                    p25 = formatTableEntry(base.scale(basePercentiles[1]),
                                                                     result.scale(percentiles[1]),
                                                                                  reversedPolarity)
                                    p50 = formatTableEntry(base.scale(basePercentiles[2]),
                                                                     result.scale(percentiles[2]),
                                                                                  reversedPolarity)
                                    p75 = formatTableEntry(base.scale(basePercentiles[3]),
                                                                     result.scale(percentiles[3]),
                                                                                  reversedPolarity)
                                    p90 = formatTableEntry(base.scale(basePercentiles[4]),
                                                                     result.scale(percentiles[4]),
                                                                                  reversedPolarity)
                                    p99 = formatTableEntry(base.scale(basePercentiles[5]),
                                                                     result.scale(percentiles[5]),
                                                                                  reversedPolarity)
                                    p100 = formatTableEntry(base.scale(basePercentiles[6]),
                                                                     result.scale(percentiles[6]),
                                                                                  reversedPolarity)
                                } else {
                                    p0 = formatTableEntry(base.normalize(basePercentiles[0]),
                                                                     result.normalize(percentiles[0]),
                                                                                  reversedPolarity)
                                    p25 = formatTableEntry(base.normalize(basePercentiles[1]),
                                                                      result.normalize(percentiles[1]),
                                                                                   reversedPolarity)
                                    p50 = formatTableEntry(base.normalize(basePercentiles[2]),
                                                                      result.normalize(percentiles[2]),
                                                                                   reversedPolarity)
                                    p75 = formatTableEntry(base.normalize(basePercentiles[3]),
                                                                      result.normalize(percentiles[3]),
                                                                                   reversedPolarity)
                                    p90 = formatTableEntry(base.normalize(basePercentiles[4]),
                                                                      result.normalize(percentiles[4]),
                                                                                   reversedPolarity)
                                    p99 = formatTableEntry(base.normalize(basePercentiles[5]),
                                                                      result.normalize(percentiles[5]),
                                                                                   reversedPolarity)
                                    p100 = formatTableEntry(base.normalize(basePercentiles[6]),
                                                                       result.normalize(percentiles[6]),
                                                                                    reversedPolarity)
                                }

                                scaledResults.append(ScaledResults(description: "Improvement %",
                                                                   p0: p0,
                                                                   p25: p25,
                                                                   p50: p50,
                                                                   p75: p75,
                                                                   p90: p90,
                                                                   p99: p99,
                                                                   p100: p100,
                                                                   samples: samples))


                                printMarkdown("```")
                                table.print(scaledResults, style: Style.fancy)
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
}
