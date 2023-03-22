//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#else
    #error("Unsupported Platform")
#endif

import ArgumentParser

#if swift(>=5.8)
    @_documentation(visibility: internal)
#endif
/// Internal type that will be hidden from documentation when upgrading doc generation to Swift 5.8+
public protocol BenchmarkRunnerHooks {
    static func main() async
    static func registerBenchmarks()
}

#if swift(>=5.8)
    @_documentation(visibility: internal)
#endif
public extension BenchmarkRunnerHooks {
    static func main() async {
        await BenchmarkRunner.setupBenchmarkRunner(registerBenchmarks: registerBenchmarks)
    }
}

#if swift(>=5.8)
    @_documentation(visibility: internal)
#endif
/// Internal type that will be hidden from documentation when upgrading doc generation to Swift 5.8+
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

    @Flag(name: .long, help:
        """
        Set to true if thresholds should be checked against an absolute reference point rather than delta between baselines.
        This is used for CI workflows when you want to validate the thresholds vs. a persisted benchmark baseline
        rather than comparing PR vs main or vs a current run. This is useful to cut down the build matrix needed
        for those wanting to validate performance of e.g. toolchains or OS:s as well (or have other reasons for wanting
        a specific check against a given absolute reference.).
        If this is enabled, zero or one baselines should be specified for the check operation.
        By default, thresholds are checked comparing two baselines, or a baseline and a benchmark run.
        """)
    var checkAbsoluteThresholds = false

    var debug = false

    func shouldRunBenchmark(_ name: String) throws -> Bool {
        if try skip.contains(where: { try name.wholeMatch(of: Regex($0)) != nil }) {
            return false
        }
        return try filter.isEmpty || filter.contains(where: { try name.wholeMatch(of: Regex($0)) != nil })
    }

    public static func setupBenchmarkRunner(registerBenchmarks: () -> Void) async {
        do {
            var command = Self.parseOrExit()
            Benchmark.checkAbsoluteThresholds = command.checkAbsoluteThresholds
            registerBenchmarks()
            try await command.run()
        } catch {
            exit(withError: error)
        }
    }

    // swiftlint:disable cyclomatic_complexity function_body_length
    public mutating func run() async throws {
        // Flush stdout so we see any failures clearly
        setbuf(stdout, nil)

        // We just run everything in debug mode to simplify workflow with debuggers/profilers
        if inputFD == nil, outputFD == nil {
            debug = true
        }

        let channel = Self.testReadWrite ?? self

        var debugIterator = Benchmark.benchmarks.makeIterator()
        var benchmarkCommand: BenchmarkCommandRequest
        let benchmarkExecutor = BenchmarkExecutor(quiet: quiet)
        var benchmark: Benchmark?
        var results: [BenchmarkResult] = []

        Benchmark.startupHook?()

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
                Benchmark.shutdownHook?()
                return
            }
        }
    }
}
