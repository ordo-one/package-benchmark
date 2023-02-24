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
                print("")
                printAllBaselines()
                return
            }

            if let comparisonBaseline {
                guard benchmarkBaselines.count > 0 else {
                    print("Only had \(benchmarkBaselines.count) baselines, can't compare.")
                    return
                }

                let currentBaseline = benchmarkBaselines[0]
                let baselineName = baseline[0]
                let comparingBaselineName = compare ?? "unknown"

                prettyPrintDelta(currentBaseline: currentBaseline, baseline: comparisonBaseline)

                if currentBaseline.betterResultsOrEqual(than: comparisonBaseline, printOutput: true) {
                    print("New baseline '\(comparingBaselineName)' is BETTER (or equal) than the '\(baselineName)' baseline thresholds.")
                    print("")

                } else {
                    failBenchmark("New baseline '\(comparingBaselineName)' is WORSE than the '\(baselineName)' baseline thresholds.")
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

                if quiet == 0 {
                    prettyPrint(baseline, header: "Updating baseline '\(baselineName)'")
                }

                try baseline.targets.forEach { target in
                    let results = baseline.results.filter { $0.key.target == target }
                    let subset = BenchmarkBaseline(baselineName: baselineName == "default" ? "Current baseline" : baselineName,
                                                   machine: baseline.machine,
                                                   results: results)
                    try write(baseline: subset,
                              baselineName: baselineName,
                              target: target)
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
