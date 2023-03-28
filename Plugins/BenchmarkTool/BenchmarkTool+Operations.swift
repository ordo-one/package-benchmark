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
#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#else
    #error("Unsupported Platform")
#endif

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
                if metrics.isEmpty == false {
                    benchmark.configuration.metrics = metrics
                }
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
        // Turn on buffering again for output
        setvbuf(stdout, nil, _IOFBF, Int(BUFSIZ))

        switch command {
        case .`init`:
            return
        case .baseline:
            guard let baselineOperation else {
                fatalError("Baseline command without specifying a baseline operation, internal error in Benchmark")
            }

            switch baselineOperation {
            case .delete:
                benchmarkExecutablePaths.forEach { path in
                    let target = FilePath(path).lastComponent!.description
                    baseline.forEach {
                        removeBaselinesNamed(target: target, baselineName: $0)
                    }
                }
                return
            case .list:
                printAllBaselines()
            case .compare:
                guard benchmarkBaselines.count == 2 else {
                    print("Can only compare exactly 2 benchmark baselines, got: \(benchmarkBaselines.count) baselines.")
                    return
                }

                prettyPrintDelta(currentBaseline: benchmarkBaselines[0], baseline: benchmarkBaselines[1])
            case .update:
                guard benchmarkBaselines.count == 1 else {
                    print("Can only update a single benchmark baseline, got: \(benchmarkBaselines.count) baselines.")
                    return
                }

                let baseline = benchmarkBaselines[0]
                if let baselineName = self.baseline.first {
                    try baseline.targets.forEach { target in
                        let results = baseline.results.filter { $0.key.target == target }
                        let subset = BenchmarkBaseline(baselineName: baselineName,
                                                       machine: baseline.machine,
                                                       results: results)
                        try write(baseline: subset,
                                  baselineName: baselineName,
                                  target: target)
                    }

                    if quiet == false {
                        print("")
                        print("Updated baseline '\(baselineName)'")
                    }
                } else {
                    fatalError("Could not get first baselinename")
                }

            case .check:
                if checkAbsoluteThresholds {
                    guard benchmarkBaselines.count == 1 else {
                        print("Can only do threshold violation checks for exactly 1 benchmark baseline, got: \(benchmarkBaselines.count) baselines.")
                        return
                    }

                    print("")
                    let currentBaseline = benchmarkBaselines[0]
                    let baselineName = baseline[0]

                    let deviationResults = currentBaseline.failsAbsoluteThresholdChecks(benchmarks: benchmarks)

                    if deviationResults.isEmpty {
                        print("Baseline '\(baselineName)' is BETTER (or equal) than the defined absolute baseline thresholds. (--check-absolute)")
                    } else {
                        prettyPrintAbsoluteDeviation(baselineName: baselineName,
                                                     deviationResults: deviationResults)
                        failBenchmark("New baseline '\(baselineName)' is WORSE than the defined absolute baseline thresholds. (--check-absolute)",
                                      exitCode: .thresholdViolation)
                    }
                } else {
                    guard benchmarkBaselines.count == 2 else {
                        print("Can only do threshold violation checks for exactly 2 benchmark baselines, got: \(benchmarkBaselines.count) baselines.")
                        return
                    }

                    let currentBaseline = benchmarkBaselines[0]
                    let checkBaseline = benchmarkBaselines[1]
                    let baselineName = baseline[0]
                    let checkBaselineName = baseline[1]

                    let (betterOrEqual, deviationResults) = checkBaseline.betterResultsOrEqual(than: currentBaseline,
                                                                                               benchmarks: benchmarks)

                    if betterOrEqual {
                        print("New baseline '\(checkBaselineName)' is BETTER (or equal) than the '\(baselineName)' baseline thresholds.")
                    } else {
                        prettyPrintDeviation(baselineName: baselineName,
                                             comparingBaselineName: checkBaselineName,
                                             deviationResults: deviationResults)
                        failBenchmark("New baseline '\(checkBaselineName)' is WORSE than the '\(baselineName)' baseline thresholds.",
                                      exitCode: .thresholdViolation)
                    }
                }
            case .read:
                if benchmarkBaselines.isEmpty {
                    print("No baseline found.")
                } else {
                    try benchmarkBaselines.forEach { baseline in
                        try exportResults(baseline: baseline)
                    }
                }
            }
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
