//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

// Pretty printing output as tables / tables with markdown

import Benchmark
import SystemPackage
import Rainbow

private let percentileWidth = 7
private let maxDescriptionWidth = 100

extension BenchmarkTool {

    private func printText(_ markdown: String, terminator: String = "\n") {
        print(markdown, terminator: terminator)
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
        print(separator)
        print(header)
        print(separator)
        print("")
        print("Host '\(machine.hostname.bold)' with \(machine.processors.description.bold) x '\(machine.processorType.bold)' processors (\(machine.memory.description.bold) GB RAM), running:")
        print("\(machine.kernelVersion)")
        printText("")
    }

    fileprivate struct ScaledResults {
        fileprivate struct Percentiles {
            var p0: Int = 0
            var p25: Int = 0
            var p50: Int = 0
            var p75: Int = 0
            var p90: Int = 0
            var p99: Int = 0
            var p100: Int = 0
        }

        var average: Int
        var deviation: Int
        var description: String
        var unitDescription: String
        var percentiles: Percentiles
        var samples: Int
    }

    private func _prettyPrint(title: String,
                              key: String,
                              results: [BenchmarkBaseline.ResultsEntry],
                              width: Int = 30,
                              useGroupingDescription: Bool = false) {
/*
        let table = TextTable<ScaledResults> {
            [Column(title: title, value: "\($0.description)", width: width, align: .left),
             Column(title: "p0", value: $0.percentiles.p0, width: percentileWidth, align: .right),
             Column(title: "p25", value: $0.percentiles.p25, width: percentileWidth, align: .right),
             Column(title: "p50", value: $0.percentiles.p50, width: percentileWidth, align: .right),
             Column(title: "p75", value: $0.percentiles.p75, width: percentileWidth, align: .right),
             Column(title: "p90", value: $0.percentiles.p90, width: percentileWidth, align: .right),
             Column(title: "p99", value: $0.percentiles.p99, width: percentileWidth, align: .right),
             Column(title: "p100", value: $0.percentiles.p100, width: percentileWidth, align: .right),
             Column(title: "Samples", value: $0.samples, width: percentileWidth, align: .right)]
        }
*/
        var benchmarkMetricsMaxLength = 10
        var scaledResults: [ScaledResults] = []
        results.forEach { result in
            let description: String
            let metrics = result.metrics
            let percentiles = metrics.statistics.percentiles()
            var resultPercentiles = ScaledResults.Percentiles()

            var adjustmentFunction: (Int) -> Int

            if self.scale, result.metrics.metric.useScalingFactor {
                description = useGroupingDescription ? "\(result.description) \(result.metrics.scaledUnitDescriptionPretty)"
                : "\(result.metrics.metric.description) \(result.metrics.scaledUnitDescriptionPretty)"
                adjustmentFunction = result.metrics.scale
            } else {
                description = useGroupingDescription ? "\(result.description) \(result.metrics.unitDescriptionPretty)"
                : "\(result.metrics.metric.description) \(result.metrics.unitDescriptionPretty)"
                adjustmentFunction = result.metrics.normalize
            }

            resultPercentiles.p0 = adjustmentFunction(percentiles[0])
            resultPercentiles.p25 = adjustmentFunction(percentiles[1])
            resultPercentiles.p50 = adjustmentFunction(percentiles[2])
            resultPercentiles.p75 = adjustmentFunction(percentiles[3])
            resultPercentiles.p90 = adjustmentFunction(percentiles[4])
            resultPercentiles.p99 = adjustmentFunction(percentiles[5])
            resultPercentiles.p100 = adjustmentFunction(percentiles[6])

            scaledResults.append(ScaledResults(average: adjustmentFunction(Int(result.metrics.statistics.average)),
                                               deviation: adjustmentFunction(Int(result.metrics.statistics.histogram.stdDeviation)),
                                               description: description,
                                               unitDescription: result.metrics.unitDescription,
                                               percentiles: resultPercentiles,
                                               samples: result.metrics.statistics.measurementCount))
            benchmarkMetricsMaxLength = max(benchmarkMetricsMaxLength, description.count)
        }

        print("\(key)".bold)
        scaledResults.forEach { result in
            let indent = String(repeating: " ", count: benchmarkMetricsMaxLength - result.description.count)
            let standardDev = result.deviation > 0 ? "\("SD = \(result.deviation)\(result.unitDescription)".italic)" : ""
            print("      \(indent)  \(result.description) \(result.average.description.bold)\(result.unitDescription) \(standardDev)")
        }
//        table.print(scaledResults, style: Style.fancy)
    }

    func setupRainbow() {
        switch path {
        case nil:
            fallthrough
        case "stdout":
            Rainbow.outputTarget = .console
        default:
            break
        }
    }

    func prettyPrintText(_ baseline: BenchmarkBaseline,
                          header: String, // = "Benchmark results",
                          hostIdentifier _: String? = nil) {
        guard quiet == false else { return }

        setupRainbow()
        printMachine(baseline.machine, header)

        switch grouping {
        case .benchmark:
            var width = 10
            let metrics = baseline.metricsMatching { _, _ in true }
            metrics.forEach { metric in
                width = max(width, metric.description.count)
            }
            width = min(maxDescriptionWidth, width + " (M)".count)

            baseline.targets.forEach { target in
                var firstOutput = true

                baseline.benchmarkNames.forEach { benchmarkName in
                    let results = baseline.resultEntriesMatching { identifier, result in
                        (identifier.name == benchmarkName && identifier.target == target, result.metric.description)
                    }
                    if results.count > 0 {
                        if firstOutput {
                            print("\(target)".bold)
                            firstOutput = false
                        }
                        _prettyPrint(title: "Metric", key: benchmarkName, results: results, width: width)
                    }
                }
            }
        case .metric:
            var width = 10
            baseline.benchmarkIdentifiers.forEach { identifier in
                width = max(width, "\(identifier.target):\(identifier.name)".count)
            }
            width = min(maxDescriptionWidth, width + " (M)".count)

            baseline.benchmarkMetrics.forEach { metric in

                let results = baseline.resultEntriesMatching { identifier, result in
                    (result.metric == metric, "\(identifier.target):\(identifier.name)")
                }

                _prettyPrint(title: "Test", key: metric.description, results: results, width: width, useGroupingDescription: true)
            }
        }
    }
/*
    func prettyPrintDeltaTable(currentBaseline: BenchmarkBaseline,
                               baseline: BenchmarkBaseline,
                               hostIdentifier _: String? = nil) {
        printMachine(baseline.machine, "Comparing results between '\(currentBaseline.baselineName)' and '\(baseline.baselineName)'")
        if currentBaseline.machine != baseline.machine {
            print("Warning: Machine configuration is different when comparing baselines, other config:")
            printMachine(currentBaseline.machine, "")
        }

        baseline.targets.forEach { target in
            let baseBaselineName = currentBaseline.baselineName
            let comparisonBaselineName = baseline.baselineName

            var keys = baseline.results.keys.sorted(by: { $0.name < $1.name })

            keys.removeAll(where: { $0.target != target })

            var firstOutput = true

            keys.forEach { key in
                if let value = baseline.results[key] {
                    guard let baselineComparison = currentBaseline.results[key] else {
                        //       print("No baseline to compare with for `\(key.target):\(key.name)`.")
                        return
                    }

                    if firstOutput {
                        print("\(target)")
                        printText("============================================================================================================================")
                        print("")
                        firstOutput = false
                    }

                    printText("----------------------------------------------------------------------------------------------------------------------------")
                    print("\(key.name) metrics")
                    printText("----------------------------------------------------------------------------------------------------------------------------")
                    print("")

                    value.forEach { currentResult in
                        var result = currentResult
                        if let base = baselineComparison.first(where: { $0.metric == result.metric }) {
                            let (hideResults, _) = result.betterResultsOrEqual(than: base, thresholds: result.thresholds ?? BenchmarkThresholds.none)

                            // We hide the markdown results if they are better than baseline to cut down noise
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
                                 Column(title: "p0", value: $0.percentiles.p0, width: percentileWidth, align: .right),
                                 Column(title: "p25", value: $0.percentiles.p25, width: percentileWidth, align: .right),
                                 Column(title: "p50", value: $0.percentiles.p50, width: percentileWidth, align: .right),
                                 Column(title: "p75", value: $0.percentiles.p75, width: percentileWidth, align: .right),
                                 Column(title: "p90", value: $0.percentiles.p90, width: percentileWidth, align: .right),
                                 Column(title: "p99", value: $0.percentiles.p99, width: percentileWidth, align: .right),
                                 Column(title: "p100", value: $0.percentiles.p100, width: percentileWidth, align: .right),
                                 Column(title: "Samples", value: $0.samples, width: percentileWidth, align: .right)]
                            }

                            // Rescale result to base if needed
                            result.timeUnits = base.timeUnits

                            var scaledResults: [ScaledResults] = []

                            let percentiles = result.statistics.percentiles()
                            let percentilesBase = base.statistics.percentiles()

                            var resultPercentiles = ScaledResults.Percentiles()
                            var basePercentiles = ScaledResults.Percentiles()
                            var adjustmentFunction: (Int) -> Int
                            let samples = result.statistics.measurementCount - base.statistics.measurementCount

                            if self.scale, base.metric.useScalingFactor {
                                adjustmentFunction = base.scale
                            } else {
                                adjustmentFunction = base.normalize
                            }

                            basePercentiles.p0 = adjustmentFunction(percentilesBase[0])
                            basePercentiles.p25 = adjustmentFunction(percentilesBase[1])
                            basePercentiles.p50 = adjustmentFunction(percentilesBase[2])
                            basePercentiles.p75 = adjustmentFunction(percentilesBase[3])
                            basePercentiles.p90 = adjustmentFunction(percentilesBase[4])
                            basePercentiles.p99 = adjustmentFunction(percentilesBase[5])
                            basePercentiles.p100 = adjustmentFunction(percentilesBase[6])

                            scaledResults.append(ScaledResults(description: baseBaselineName,
                                                               percentiles: basePercentiles,
                                                               samples: base.statistics.measurementCount))

                            if self.scale, result.metric.useScalingFactor {
                                adjustmentFunction = result.scale
                            } else {
                                adjustmentFunction = result.normalize
                            }

                            resultPercentiles.p0 = adjustmentFunction(percentiles[0])
                            resultPercentiles.p25 = adjustmentFunction(percentiles[1])
                            resultPercentiles.p50 = adjustmentFunction(percentiles[2])
                            resultPercentiles.p75 = adjustmentFunction(percentiles[3])
                            resultPercentiles.p90 = adjustmentFunction(percentiles[4])
                            resultPercentiles.p99 = adjustmentFunction(percentiles[5])
                            resultPercentiles.p100 = adjustmentFunction(percentiles[6])

                            scaledResults.append(ScaledResults(description: comparisonBaselineName,
                                                               percentiles: resultPercentiles,
                                                               samples: result.statistics.measurementCount))

                            var deltaPercentiles = ScaledResults.Percentiles()

                            deltaPercentiles.p0 = resultPercentiles.p0 - basePercentiles.p0
                            deltaPercentiles.p25 = resultPercentiles.p25 - basePercentiles.p25
                            deltaPercentiles.p50 = resultPercentiles.p50 - basePercentiles.p50
                            deltaPercentiles.p75 = resultPercentiles.p75 - basePercentiles.p75
                            deltaPercentiles.p90 = resultPercentiles.p90 - basePercentiles.p90
                            deltaPercentiles.p99 = resultPercentiles.p99 - basePercentiles.p99
                            deltaPercentiles.p100 = resultPercentiles.p100 - basePercentiles.p100

                            scaledResults.append(ScaledResults(description: BenchmarkMetric.delta.description,
                                                               percentiles: deltaPercentiles,
                                                               samples: samples))

                            let reversedPolarity = base.metric.polarity == .prefersLarger

                            var percentageDeltaPercentiles = ScaledResults.Percentiles()

                            percentageDeltaPercentiles.p0 = formatTableEntry(basePercentiles.p0,
                                                                             resultPercentiles.p0,
                                                                             reversedPolarity)
                            percentageDeltaPercentiles.p25 = formatTableEntry(basePercentiles.p25,
                                                                              resultPercentiles.p25,
                                                                              reversedPolarity)
                            percentageDeltaPercentiles.p50 = formatTableEntry(basePercentiles.p50,
                                                                              resultPercentiles.p50,
                                                                              reversedPolarity)
                            percentageDeltaPercentiles.p75 = formatTableEntry(basePercentiles.p75,
                                                                              resultPercentiles.p75,
                                                                              reversedPolarity)
                            percentageDeltaPercentiles.p90 = formatTableEntry(basePercentiles.p90,
                                                                              resultPercentiles.p90,
                                                                              reversedPolarity)
                            percentageDeltaPercentiles.p99 = formatTableEntry(basePercentiles.p99,
                                                                              resultPercentiles.p99,
                                                                              reversedPolarity)
                            percentageDeltaPercentiles.p100 = formatTableEntry(basePercentiles.p100,
                                                                               resultPercentiles.p100,
                                                                               reversedPolarity)

                            scaledResults.append(ScaledResults(description: "Improvement %",
                                                               percentiles: percentageDeltaPercentiles,
                                                               samples: samples))

                            table.print(scaledResults, style: Style.fancy)

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
*/
    func prettyPrintDeviationText(baselineName: String,
                                  comparingBaselineName: String,
                                  deviationResults: [BenchmarkResult.ThresholdDeviation]) {
        guard quiet == false else { return }
        setupRainbow()
        let metrics = deviationResults.map(\.metric).unique()

        // Get a unique set of all name/target pairs that have threshold violations, sorted lexically:
        let namesAndTargets = deviationResults.map { NameAndTarget(name: $0.name, target: $0.target) }
            .unique().sorted { ($0.target, $0.name) < ($1.target, $1.name) }

        var deviationCount = 0

        guard namesAndTargets.isEmpty == false else { return }

        var benchmarkMetricsMaxLength = 10
        namesAndTargets.forEach { _ in
            metrics.forEach { metric in
                benchmarkMetricsMaxLength = max(benchmarkMetricsMaxLength, metric.description.count)
            }
        }

        namesAndTargets.forEach { nameAndTarget in

            print("\(nameAndTarget.target.bold):\(nameAndTarget.name.bold)")

            metrics.forEach { metric in
                let indent = String(repeating: " ", count: benchmarkMetricsMaxLength - metric.description.count)

                let relativeResults = deviationResults.filter { $0.name == nameAndTarget.name &&
                    $0.target == nameAndTarget.target &&
                    $0.metric == metric &&
                    $0.relative == true
                }
                let absoluteResults = deviationResults.filter { $0.name == nameAndTarget.name &&
                    $0.target == nameAndTarget.target &&
                    $0.metric == metric &&
                    $0.relative == false
                }


                absoluteResults.forEach { result in
                    let unitDescription = metric.countable ? "" : result.units.timeDescription
                    let percentile = "\(result.percentile)".paddingToLeft(upTo: 4)

                    print("    \(percentile) \(indent)\(metric.description) \((result.difference - result.differenceThreshold).description.bold)\(unitDescription.italic)")
                    deviationCount += 1
                }

                relativeResults.forEach { result in
                    let percentile = "\(result.percentile)".paddingToLeft(upTo: 4)
                    print("    \(percentile) \(indent)\(metric.description) \((result.difference - result.differenceThreshold).description.bold)\("%".italic)")
                    deviationCount += 1
                }
            }
        }
        print("")
    }

    func prettyPrintAbsoluteDeviationText(baselineName: String,
                                          deviationResults: [BenchmarkResult.ThresholdDeviation]) {
        guard quiet == false else { return }

        let metrics = deviationResults.map(\.metric).unique()
        // Get a unique set of all name/target pairs that have threshold violations, sorted lexically:
        let namesAndTargets = deviationResults.map { NameAndTarget(name: $0.name, target: $0.target) }
            .unique().sorted { ($0.target, $0.name) < ($1.target, $1.name) }

        guard namesAndTargets.isEmpty == false else { return }

        var benchmarkMetricsMaxLength = 10
        namesAndTargets.forEach { _ in
            metrics.forEach { metric in
                benchmarkMetricsMaxLength = max(benchmarkMetricsMaxLength, metric.description.count)
            }
        }

        namesAndTargets.forEach { nameAndTarget in

            print("\(nameAndTarget.target.bold):\(nameAndTarget.name.bold)")

            metrics.forEach { metric in
                let indent = String(repeating: " ", count: benchmarkMetricsMaxLength - metric.description.count)

                let absoluteResults = deviationResults.filter { $0.name == nameAndTarget.name &&
                    $0.target == nameAndTarget.target &&
                    $0.metric == metric &&
                    $0.relative == false
                }

                absoluteResults.forEach { result in
                    let unitDescription = metric.countable ? "" : result.units.timeDescription
                    let percentile = "\(result.percentile)".paddingToLeft(upTo: 4)

                    print("    \(percentile) \(indent)\(metric.description) \((result.difference - result.differenceThreshold).description.bold)\(unitDescription.italic)")
                }
            }
        }
        print("")
    }
}

extension RangeReplaceableCollection where Self: StringProtocol {
    func paddingToLeft(upTo length: Int, using element: Element = " ") -> SubSequence {
        return repeatElement(element, count: Swift.max(0, length-count)) + suffix(Swift.max(count, count-length))
    }
}

