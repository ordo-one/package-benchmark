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
        let benchmarkMachine = benchmarkMachine()

        switch command {
        case .baseline:
            if compare != nil {
                guard baselines.count > 1 && self.baseline.count > 1 else {
                    print("Only had \(baselines.count) baselines, can't compare.")
                    return
                }

                let currentBaseline = baselines[0]
                let comparingBaseline = baselines[1]
                let baselineName = self.baseline[0]
                let comparingBaselineName = self.baseline[1]

                prettyPrintDelta(currentBaseline:currentBaseline, baseline: comparingBaseline)

                if comparingBaseline.betterResultsOrEqual(than: currentBaseline, printOutput: true) {
                    print("New baseline '\(comparingBaselineName)' is BETTER (or equal) than the '\(baselineName)' baseline thresholds.")
                    print("")

                } else {
                    failBenchmark("New baseline '\(comparingBaselineName)' is WORSE than the '\(baselineName)' baseline thresholds.")
                }
            }

            if baselines.isEmpty {
                print("No baseline found.")
            } else {
                let baseline = baselines[0]
                prettyPrint(baseline, header: "Current baseline")
            }

            return
        case .run:
            guard let baseline = baselines.first else {
                fatalError("Internal error, no baseline data after benchmark run.")
            }

            prettyPrint(baseline)

/*        case .compare:
            guard readBaselines.isEmpty == false else {
                print("No baseline available to compare with.")
                return
            }

            // Merge baselines read
            var aggregatedBaseline = readBaselines.first!
            for baseline in 1 ..< readBaselines.count {
                aggregatedBaseline = aggregatedBaseline.merge(readBaselines[baseline])
            }

            let currentBaseline = BenchmarkBaseline(machine: benchmarkMachine, results: benchmarkResults)
            prettyPrintDelta(currentBaseline: currentBaseline, baseline: aggregatedBaseline)

            if currentBaseline.betterResultsOrEqual(than: aggregatedBaseline, printOutput: true) {
                print("Current run is BETTER (or equal) than the '\(baselineName ?? "default")' baseline thresholds.")
            } else {
                failBenchmark("Current run of is WORSE than the '\(baselineName ?? "default")' baseline thresholds.")
            }
        case .updateBaseline:
            if quiet == false {
                prettyPrint(BenchmarkBaseline(machine: benchmarkMachine, results: benchmarkResults),
                            header: "Updating baselines")
            }
            let baseline = BenchmarkBaseline(machine: benchmarkMachine,
                                             results: benchmarkResults)
            try baseline.targets.forEach { target in
                let results = baseline.results.filter { $0.key.target == target }
                try write(BenchmarkBaseline(machine: benchmarkMachine, results: results), target: target)
            }
        case .export:
            try exportResults(BenchmarkBaseline(machine: benchmarkMachine,
                                                results: benchmarkResults))
 */
        default:
            print("Unexpected command \(command)")
        }
    }

    func listBenchmarks() throws {
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
