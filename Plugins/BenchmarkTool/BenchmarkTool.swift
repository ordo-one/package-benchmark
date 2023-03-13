//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

// The actual benchmark runner/driver

import ArgumentParser
import Benchmark
import SystemPackage

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#else
    #error("Unsupported Platform")
#endif

enum Grouping: String, ExpressibleByArgument {
    case metric
    case benchmark
}

/// The benchmark data output format.
enum OutputFormat: String, ExpressibleByArgument, CaseIterable {
    /// Text output formatted into a visual table
    case text
    /// The text output format, formatted in markdown
    case markdown
    /// Influx data import
    case influx
    case percentiles
    case tsv
    case jmh
    /// The encoded representation of the underlying histograms capturing the benchmark data.
    case encodedHistogram
}

enum BenchmarkOperation: String, ExpressibleByArgument {
    case baseline
    case list
    case run
    case query // query all benchmarks from target, used internally in tool
}

typealias BenchmarkResults = [BenchmarkIdentifier: [BenchmarkResult]]

@main
struct BenchmarkTool: AsyncParsableCommand {
    @Option(name: .long, help: "The paths to the benchmarks to run")
    var benchmarkExecutablePaths: [String]

    @Option(name: .long, help: "The command to perform")
    var command: BenchmarkOperation

    @Option(name: .long, help: "The export format to use \((OutputFormat.allCases).map { String(describing: $0) })")
    var format: OutputFormat

    @Option(name: .long, help: "The path to baseline directory for storage")
    var baselineStoragePath: String

    @Option(name: .long, help: "The path to export to")
    var path: String?

    @Option(name: .long, help: "The baseline to compare with")
    var compare: String?

    @Option(name: .long, help: "The baseline to check thresholds with")
    var check: String?

    @Flag(name: .long, help: "True if we should supress output")
    var quiet: Int

    @Flag(name: .long, help: "True if we should update the baseline")
    var update: Int

    @Flag(name: .long, help: "True if we should delete the baseline")
    var delete: Int

    @Flag(name: .long, help: "True if we should display available baselines")
    var listBaselines: Int

    @Flag(name: .long, help: "True if we should supress progress in benchmark run")
    var noProgress: Int

    @Flag(name: .long, help: "True if we should scale time units, syscall rate, etc to scalingFactor")
    var scale: Int

    @Option(name: .long, help: "The named baseline(s) we should display, update, delete or compare with")
    var baseline: [String] = []

    @Option(name: .long, help: "The grouping to use, 'metric' or 'test'")
    var grouping: Grouping

    @Option(name: .long, help: "Benchmarks matching the regexp filter that should be run")
    var filter: [String] = []

    @Option(name: .long, help: "Benchmarks matching the regexp filter that should be skipped")
    var skip: [String] = []

    var targets: [String] {
        benchmarkExecutablePaths.map { FilePath($0).lastComponent!.description }
    }

    var inputFD: CInt = 0
    var outputFD: CInt = 0

    var benchmarks: [Benchmark] = []
    var benchmarkBaselines: [BenchmarkBaseline] = [] // The baselines read from disk, merged
    var comparisonBaseline: BenchmarkBaseline?
    var checkBaseline: BenchmarkBaseline?

    internal enum ExitCode: Int32 {
        case genericFailure = 1
        case thresholdViolation = 2
    }

    mutating func failBenchmark(_ reason: String? = nil, exitCode: ExitCode = .genericFailure) {
        if let reason {
            print(reason)
            print("")
        }
        #if canImport(Darwin)
            Darwin.exit(exitCode.rawValue)
        #elseif canImport(Glibc)
            Glibc.exit(exitCode.rawValue)
        #endif
    }

    func printChildRunError(error: Int32, benchmarkExecutablePath: String) {
        print("Failed to run '\(command)' for \(benchmarkExecutablePath), error code [\(error)]")
        print("Likely your benchmark crahed, try running the tool in the debugger, e.g.")
        print("lldb \(benchmarkExecutablePath)")
        print("Or check Console.app for a backtrace if on macOS.")
    }

    func shouldRunBenchmark(_ name: String) throws -> Bool {
        if try skip.contains(where: { try name.wholeMatch(of: Regex($0)) != nil }) {
            return false
        }
        return try filter.isEmpty || filter.contains(where: { try name.wholeMatch(of: Regex($0)) != nil })
    }

    mutating func readBaselines() throws {
        func readBaseline(_ baselineName: String) throws -> BenchmarkBaseline? {
            // read all specified baselines
            var readBaselines: [BenchmarkBaseline] = [] // The baselines read from disk

            try targets.forEach { target in // read from all the targets (baselines are stored separately)
                let currentBaseline = try read(target: target, baselineIdentifier: baselineName)

                if let currentBaseline {
                    readBaselines.append(currentBaseline)
                }
            }

            // Merge baselines read
            if readBaselines.isEmpty == false {
                var aggregatedBaseline = readBaselines.first!
                for baseline in 1 ..< readBaselines.count {
                    aggregatedBaseline = aggregatedBaseline.merge(readBaselines[baseline])
                }
                return aggregatedBaseline
            }

            return nil
        }

        try baseline.forEach { baselineName in // for all specified baselines at command line
            if let baseline = try readBaseline(baselineName) {
                benchmarkBaselines.append(baseline)
            } else {
                if quiet == 0 {
                    print("")
                    print("Warning: Failed to load specified baseline '\(baselineName)'.")
                }
            }
        }

        // And separately read in the comparison baseline if any
        if let compare {
            comparisonBaseline = try readBaseline(compare)
        }

        // And separately read in the comparison baseline if any
        if let check {
            checkBaseline = try readBaseline(check)
        }
    }

    mutating func run() async throws {
        if command == .baseline, delete == 0, listBaselines == 0, update == 0 { // don't need to read baseline
            try readBaselines()
        }

        // First get a list of all benchmarks
        try benchmarkExecutablePaths.forEach { benchmarkExecutablePath in
            try runChild(benchmarkPath: benchmarkExecutablePath,
                         benchmarkCommand: .query) { [self] result in
                if result != 0 {
                    printChildRunError(error: result, benchmarkExecutablePath: benchmarkExecutablePath)
                }
            }
        }

        // If we just need data from disk, skip running benchmarks
        if command == .baseline, benchmarkBaselines.count > 0 {
            if compare == nil, delete == 0, update == 0 {
                try postProcessBenchmarkResults()
                return
            }

            // comparison, short circuit if we have read both baselines from disk
            if compare != nil, comparisonBaseline != nil { // comparison operation
                try postProcessBenchmarkResults()
                return
            }
        }

        if delete > 0 {
            try postProcessBenchmarkResults()
            return
        }

        if listBaselines > 0 {
            try postProcessBenchmarkResults()
            return
        }

        guard command != .query else {
            fatalError("Query command should never be specified to the BenchmarkTool")
        }

        guard command != .list else {
            try listBenchmarks()
            return
        }

        if quiet == 0 {
            "Running Benchmarks".printAsHeader()
            fflush(stdout)
        }

        var benchmarkResults: BenchmarkResults = [:]

        // run each benchmark for the target as a separate process
        try benchmarks.forEach { benchmark in
            if try shouldRunBenchmark(benchmark.name) {
                let results = try runChild(benchmarkPath: benchmark.executablePath!,
                                           benchmarkCommand: command,
                                           benchmark: benchmark) { [self] result in
                    if result != 0 {
                        printChildRunError(error: result, benchmarkExecutablePath: benchmark.executablePath!)
                    }
                }

                benchmarkResults = benchmarkResults.merging(results) { _, new in new }
            }
        }

        // Insert benchmark run at first position of baselines
        if comparisonBaseline != nil {
            baseline.insert("default", at: 0)
        }
        benchmarkBaselines.insert(BenchmarkBaseline(baselineName: "Current baseline",
                                                    machine: benchmarkMachine(),
                                                    results: benchmarkResults), at: 0)

        try postProcessBenchmarkResults()
    }

    func withCStrings(_ strings: [String], scoped: ([UnsafeMutablePointer<CChar>?]) throws -> Void) rethrows {
        let cStrings = strings.map { strdup($0) }
        try scoped(cStrings + [nil])
        cStrings.forEach { free($0) }
    }

    enum RunCommandError: Error {
        case WaitPIDError
        case POSIXSpawnError(Int32)
    }

    @discardableResult
    mutating func runChild(benchmarkPath: String,
                           benchmarkCommand: BenchmarkOperation,
                           benchmark: Benchmark? = nil,
                           completion: ((Int32) -> Void)? = nil) throws -> BenchmarkResults {
        var pid: pid_t = 0

        var benchmarkResults: BenchmarkResults = [:]
        let fromChild = try FileDescriptor.pipe()
        let toChild = try FileDescriptor.pipe()
        let path = FilePath(benchmarkPath)
        let args: [String] = [path.lastComponent!.description,
                              "--input-fd", toChild.readEnd.rawValue.description,
                              "--output-fd", fromChild.writeEnd.rawValue.description,
                              "--quiet", (noProgress > 0).description]

        inputFD = fromChild.readEnd.rawValue
        outputFD = toChild.writeEnd.rawValue

        try withCStrings(args) { cArgs in
            var status = posix_spawn(&pid, path.string, nil, nil, cArgs, environ)

            // Close child ends of the pipes
            try toChild.readEnd.close()
            try fromChild.writeEnd.close()

            do {
                switch benchmarkCommand {
                case .query:
                    try queryBenchmarks(benchmarkPath) // Get all available benchmarks first
                case .list:
                    try listBenchmarks()
                case .baseline:
                    fallthrough
                case .run:
                    guard let benchmark else {
                        fatalError("No benchmark specified for update/export/run/compare operation")
                    }
                    benchmarkResults = try runBenchmark(target: path.lastComponent!.description, benchmark: benchmark)
                }

                try write(.end)
            } catch {
                fatalError("\(error)")
            }

            if status == 0 {
                if waitpid(pid, &status, 0) != -1 {
                    completion?(status)
                } else {
                    print("waitpiderror")
                    fflush(nil)
                    throw RunCommandError.WaitPIDError
                }
            } else {
                throw RunCommandError.POSIXSpawnError(status)
            }
        }

        return benchmarkResults
    }
}
