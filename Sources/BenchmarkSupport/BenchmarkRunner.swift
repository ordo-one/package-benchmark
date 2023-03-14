//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

import ArgumentParser
@_exported import Benchmark
@_exported import Statistics

// @main must be done in actual benchmark to avoid linker errors unfortunately
public struct BenchmarkRunner: AsyncParsableCommand, BenchmarkRunnerReadWrite {
    static var testReadWrite: BenchmarkRunnerReadWrite?

    public init() {}

    @Option(name: .shortAndLong, help: "Whether to suppress progress output.")
    var quiet = false

    @Option(name: .shortAndLong, help: "The input pipe filedescriptor used for communication with host process.")
    var inputFD: Int32?

    @Option(name: .shortAndLong, help: "The output pipe filedescriptor used for communication with host process.")
    var outputFD: Int32?

    @Option(name: .long, help: "Benchmarks matching the regexp filter that should be run")
    var filter: [String] = []

    @Option(name: .long, help: "Benchmarks matching the regexp filter that should be skipped")
    var skip: [String] = []

    var debug = false

    func shouldRunBenchmark(_ name: String) throws -> Bool {
        if try skip.contains(where: { try name.wholeMatch(of: Regex($0)) != nil }) {
            return false
        }
        return try filter.isEmpty || filter.contains(where: { try name.wholeMatch(of: Regex($0)) != nil })
    }

    // swiftlint:disable cyclomatic_complexity function_body_length
    public mutating func run() async throws {
        // We just run everything in debug mode to simplify workflow with debuggers/profilers
        if inputFD == nil, outputFD == nil {
            debug = true
        }

        let channel = Self.testReadWrite ?? self

        registerBenchmarks()

        var debugIterator = Benchmark.benchmarks.makeIterator()
        var benchmarkCommand: BenchmarkCommandRequest
        let benchmarkExecutor = BenchmarkExecutor(quiet: quiet)
        var benchmark: Benchmark?
        var results: [BenchmarkResult] = []

        while true {
            if debug { // in debug mode we run all benchmarks matching filter/skip specified
                var benchmark: Benchmark?
                benchmarkCommand = .list

                while true {
                    benchmark = debugIterator.next()
                    if let benchmark {
                        if try shouldRunBenchmark(benchmark.name) {
                            benchmarkCommand = BenchmarkCommandRequest.run(benchmark: benchmark)
                            break
                        }
                    } else {
                        return
                    }
                }
                if benchmark == nil {
                    return
                }
            } else {
                benchmarkCommand = try channel.read()
            }

            switch benchmarkCommand {
            case .list:
                try Benchmark.benchmarks.forEach { benchmark in
                    try channel.write(.list(benchmark: benchmark))
                }

                try channel.write(.end)
            case let .run(benchmarkToRun):
                benchmark = Benchmark.benchmarks.first { $0.name == benchmarkToRun.name }

                if let benchmark {
                    // Pick up some settings overridden by BenchmarkTool
                    if benchmarkToRun.configuration.metrics.isEmpty == false {
                        for metricIndex in 0 ..< benchmarkToRun.configuration.metrics.count {
                            let metric = benchmarkToRun.configuration.metrics[metricIndex]
                            if metric == .custom(metric.description) {
                                if let existingMetric =
                                    benchmark.configuration.metrics.first(where: { $0.description == metric.description }) {
                                    benchmarkToRun.configuration.metrics[metricIndex] = existingMetric
                                }
                            }
                        }
                        benchmark.configuration.metrics = benchmarkToRun.configuration.metrics
                    }

                    benchmark.target = benchmarkToRun.target

                    results = benchmarkExecutor.run(benchmark)

                    guard benchmark.failureReason == nil else {
                        try channel.write(.error(benchmark.failureReason!))
                        return
                    }

                    // If we didn't capture any results for the desired metrics (e.g. an empty metric list), skip
                    // reporting results back
                    if results.isEmpty == false {
                        try channel.write(.result(benchmark: benchmark, results: results))
                    }

                    // Minimal output for debugging
                    if debug {
                        print("Debug results for \(benchmark.name):")
                        print("")
                        results.forEach { result in
                            print("\(result.metric):")
                            print("\(result.statistics.histogram)")
                            print("")
                        }
                        print("")
                    }
                } else {
                    print("Internal error: Couldn't find specified benchmark '\(benchmarkToRun.name)' to run.")
                }

                try channel.write(.end)
            case .end:
                return
            }
        }
    }
}
