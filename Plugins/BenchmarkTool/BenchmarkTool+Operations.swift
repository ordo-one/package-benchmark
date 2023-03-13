//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

// run/list benchmarks by talking to controlled process

import Benchmark
import ExtrasJSON
import SystemPackage
import TextTable

extension BenchmarkTool {
    mutating func queryBenchmarks(_ benchmarkPath: String) throws {
        try write(.list)
        outerloop: while true {
            let benchmarkReply = try read()

            switch benchmarkReply {
            case let .list(benchmark):
                benchmark.executablePath = benchmarkPath
                benchmark.target = FilePath(benchmarkPath).lastComponent!.description
                benchmarks.append(benchmark)
            case .end:
                break outerloop
            default:
                print("Unexpected reply \(benchmarkReply)")
            }
        }
    }

    mutating func runBenchmark(target: String, benchmark: Benchmark) throws -> BenchmarkResults {
        var benchmarkResults: BenchmarkResults = [:]

        try write(.run(benchmark: benchmark))

        outerloop: while true {
            let benchmarkReply = try read()

            switch benchmarkReply {
            case let .result(benchmark: benchmark, results: results):
                let filteredResults = results.filter { benchmark.configuration.metrics.contains($0.metric) }
                benchmarkResults[BenchmarkIdentifier(target: target, name: benchmark.name)] = filteredResults
            case .end:
                break outerloop
            case let .error(description):
                print("*****")
                print("***** Benchmark '\(benchmark.name)' failed:")
                print("***** \(description)")
                print("*****")
                failBenchmark("")
                break outerloop
            default:
                print("Unexpected reply \(benchmarkReply)")
            }
        }

        return benchmarkResults
    }

    func cleanupStringForShellSafety(_ string: String) -> String {
        var cleanedString = string.replacingOccurrences(of: "/", with: "_")
        cleanedString = cleanedString.replacingOccurrences(of: " ", with: "_")
        return cleanedString
    }

    struct NameAndTarget: Hashable {
        let name: String
        let target: String
    }

    mutating func postProcessBenchmarkResults() throws {
        switch command {
        case .baseline:
            if delete > 0 {
                benchmarkExecutablePaths.forEach { path in
                    let target = FilePath(path).lastComponent!.description
                    print("")
                    baseline.forEach {
                        print("Removing baseline for \(target): '\($0)'")
                        removeBaselinesNamed(target: target, baselineName: $0)
                    }
                }
                return
            }

            if listBaselines > 0 {
                printAllBaselines()
                return
            }

            if let comparisonBaseline {
                guard benchmarkBaselines.count > 0 else {
                    print("Only had \(benchmarkBaselines.count) baselines, can't compare.")
                    return
                }

                let currentBaseline = benchmarkBaselines[0]

                prettyPrintDelta(currentBaseline: currentBaseline, baseline: comparisonBaseline)

                return
            }

            if let checkBaseline {
                guard benchmarkBaselines.count > 0 else {
                    print("Only had \(benchmarkBaselines.count) baselines available, can't check.")
                    return
                }

                let currentBaseline = benchmarkBaselines[0]
                let baselineName = baseline[0] == "default" ? "Current baseline" : baseline[0]
                let comparingBaselineName = check ?? "unknown"

                //                let benchmark = benchmarkFor(currentBaseline.results)
                let (betterOrEqual, deviationResults) = checkBaseline.betterResultsOrEqual(than: currentBaseline,
                                                                                           benchmarks: benchmarks)

                if betterOrEqual {
                    print("New baseline '\(comparingBaselineName)' is BETTER (or equal) than the '\(baselineName)' baseline thresholds.")
                } else {
                    if quiet == 0 {
                        let metrics = deviationResults.map(\.metric).unique()
                        // Get a unique set of all name/target pairs that have threshold violations, sorted lexically:
                        let namesAndTargets = deviationResults.map { return NameAndTarget(name: $0.name, target:$0.target)}
                            .unique().sorted { lhs, rhs in
                                if lhs.target < rhs.target {
                                    return true
                                }

                                return lhs.name < rhs.name
                            }

                        namesAndTargets.forEach { nameAndTarget in
                            "Threshold violations for \(nameAndTarget.name):\(nameAndTarget.target)".printAsHeader()
                            metrics.forEach { metric in

                                let relativeResults = deviationResults.filter { $0.name == nameAndTarget.name &&
                                    $0.target == nameAndTarget.target &&
                                    $0.metric == metric &&
                                    $0.relative == true }
                                let absoluteResults = deviationResults.filter { $0.name == nameAndTarget.name &&
                                    $0.target == nameAndTarget.target &&
                                    $0.metric == metric &&
                                    $0.relative == false }
                                let width = 40
                                let percentileWidth = 15


                                // The baseValue is the new baseline that we're using as the comparison base, so...
                                if absoluteResults.isEmpty == false {
                                    let absoluteTable = TextTable<BenchmarkResult.ThresholdDeviation> {
                                        [Column(title: "\(metric.description) (\(metric.countable ? $0.units.description : $0.units.timeDescription), Δ)",
                                                value: $0.percentile, width: width, align: .left),
                                         Column(title: "\(baselineName)", value: $0.comparisonValue , width: percentileWidth, align: .right),
                                         Column(title: "\(comparingBaselineName)", value: $0.baseValue, width: percentileWidth, align: .right),
                                         Column(title: "Difference Δ", value: $0.difference, width: percentileWidth, align: .right),
                                         Column(title: "Threshold Δ", value: $0.differenceThreshold, width: percentileWidth, align: .right)]
                                    }

                                    absoluteTable.print(absoluteResults, style: Style.fancy)
                                }

                                if relativeResults.isEmpty == false {
                                    let relativeTable = TextTable<BenchmarkResult.ThresholdDeviation> {
                                        [Column(title: "\(metric.description) (\(metric.countable ? $0.units.description : $0.units.timeDescription), %)",
                                                value: $0.percentile, width: width, align: .left),
                                         Column(title: "\(baselineName)", value: $0.comparisonValue, width: percentileWidth, align: .right),
                                         Column(title: "\(comparingBaselineName)", value: $0.baseValue, width: percentileWidth, align: .right),
                                         Column(title: "Difference %", value: $0.difference, width: percentileWidth, align: .right),
                                         Column(title: "Threshold %", value: $0.differenceThreshold, width: percentileWidth, align: .right)]
                                    }

                                    relativeTable.print(relativeResults, style: Style.fancy)
                                }
                            }
                        }
                    }

                    failBenchmark("New baseline '\(comparingBaselineName)' is WORSE than the '\(baselineName)' baseline thresholds.",
                                  exitCode: .thresholdViolation)
                }

                return
            }

            if update > 0 {
                guard benchmarkBaselines.count > 0 else {
                    print("Only had \(benchmarkBaselines.count) baselines, can't update.")
                    return
                }

                let baseline = benchmarkBaselines[0]
                let baselineName = self.baseline.first ?? "default"

                try baseline.targets.forEach { target in
                    let results = baseline.results.filter { $0.key.target == target }
                    let subset = BenchmarkBaseline(baselineName: baselineName == "default" ? "Current baseline" : baselineName,
                                                   machine: baseline.machine,
                                                   results: results)
                    try write(baseline: subset,
                              baselineName: baselineName,
                              target: target)
                }

                if quiet == 0 {
                    print("")
                    print("Updated baseline '\(baselineName)'")
                }

                return
            }

            if benchmarkBaselines.isEmpty {
                print("No baseline found.")
            } else {
                try benchmarkBaselines.forEach { baseline in
                    try exportResults(baseline: baseline)
                }
            }

            return
        case .run:

            guard let baseline = benchmarkBaselines.first else {
                fatalError("Internal error, no baseline data after benchmark run.")
            }

            try exportResults(baseline: baseline)
        case .query:
            break
        case .list:
            break
        }
    }

    func listBenchmarks() throws {
        print("")
        benchmarkExecutablePaths.forEach { benchmarkExecutablePath in
            print("Target '\(FilePath(benchmarkExecutablePath).lastComponent!)' available benchmarks:")
            benchmarks.forEach { benchmark in
                if benchmark.executablePath == benchmarkExecutablePath {
                    print("\(benchmark.name)")
                }
            }
            print("")
        }
    }
}
