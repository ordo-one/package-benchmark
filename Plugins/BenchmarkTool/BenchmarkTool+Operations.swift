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
    mutating func queryBenchmarks() throws {
        try write(.list)
    outerloop: while true {
        let benchmarkReply = try read()

        switch benchmarkReply {
        case let .list(benchmark):
            benchmarks.append(benchmark)
        case .end:
            break outerloop
        default:
            print("Unexpected reply \(benchmarkReply)")
        }
    }
    }

    mutating func runBenchmark(_ benchmark: Benchmark) throws -> BenchmarkResults {
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

    mutating func postProcessBenchmarkResults(_ benchmarkResults: BenchmarkResults) throws {
        let benchmarkMachine = benchmarkMachine()

        if benchmarkResults.isEmpty {
            return
        }

        switch command {
        case .run:
            prettyPrint(BenchmarkBaseline(machine: benchmarkMachine, results: benchmarkResults))
        case .compare:
            guard let currentBaseline else {
                print("No baseline available to compare with.")
                return
            }

            prettyPrintDelta(BenchmarkBaseline(machine: benchmarkMachine, results: benchmarkResults))

            if BenchmarkBaseline(machine: benchmarkMachine,
                                 results: benchmarkResults).betterResultsOrEqual(than: currentBaseline,
                                                                                 printOutput: true) {
                print("Current run of \(target) is BETTER (or equal) than the '\(baselineName ?? "default")' baseline thresholds.")
            } else {
                failBenchmark("Current run is \(target) WORSE than the '\(baselineName ?? "default")' baseline thresholds.")
            }

        case .updateBaseline:
            if quiet == false {
                prettyPrint(BenchmarkBaseline(machine: benchmarkMachine, results: benchmarkResults),
                            header: "Updating baselines")
            }
            try write(BenchmarkBaseline(machine: benchmarkMachine, results: benchmarkResults))
        case .export:
            switch exportFormat {
            case .influx:
                let exportStruct = saveExportableResults(BenchmarkBaseline(machine: benchmarkMachine, results: benchmarkResults))
                let csvString = convertToCSV(exportableBenchmark: exportStruct)
                try write(csvString, fileName: "influx_results.csv")
            case .percentiles:
                try benchmarkResults.forEach { key, results in
                    try results.forEach { values in
                        let outputString = values.statistics!.histogram
                        var metricDescription = values.metric.description.replacingOccurrences(of: "/", with: "_")
                        metricDescription = metricDescription.replacingOccurrences(of: " ", with: "_")
                        try write("\(outputString)", fileName: "\(key.name).\(metricDescription).histogram.txt")
                    }
                }
            case .jmh:
                let baseline = BenchmarkBaseline(machine: benchmarkMachine, results: benchmarkResults)
                try baseline.targets.forEach { target in
                    var metricDescription = target.replacingOccurrences(of: "/", with: "_")
                    metricDescription = metricDescription.replacingOccurrences(of: " ", with: "_")

                    try write("\(convertToJMH(baseline))",
                              fileName: "\(baselineName ?? "default")-\(target)-jmh_export.json")
                }

            case .tsv:
                try benchmarkResults.forEach { key, results in
                    var outputString = ""

                    try results.forEach { values in
                        if let histogram = values.statistics?.histogram {
                            histogram.recordedValues().forEach { value in
                                for _ in 0..<value.count {
                                    outputString += "\(value.value)\n"
                                }
                            }

                        }
                        try write("\(outputString)", fileName: "\(key.name).\(values.metric).tsv")
                    }
                }
            default:
                print("Export type not supported.")
            }
        default:
            print("Unexpected command \(command)")
        }
    }

    func listBenchmarks() throws {
        print("Target '\(FilePath(benchmarkExecutablePath).lastComponent!)' available benchmarks:")
        benchmarks.forEach { benchmark in
            print("\(benchmark.name)")
        }
        print("")
    }
}
