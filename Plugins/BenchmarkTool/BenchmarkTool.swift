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

enum OutputFormat: String, ExpressibleByArgument {
    case text
    case markdown
}

enum Grouping: String, ExpressibleByArgument {
    case metric
    case test
}

enum ExportFormat: String, ExpressibleByArgument {
    case influx
}

enum BenchmarkOperation: String, ExpressibleByArgument {
    case baseline
    case compare
    case list
    case run
    case updateBaseline = "update-baseline"
    case export
    case query // query all benchmarks from target, used internally in tool
}

typealias BenchmarkResults = [BenchmarkIdentifier: [BenchmarkResult]]

@main
struct BenchmarkTool: AsyncParsableCommand {
    @Option(name: .long, help: "The path to the benchmark to run")
    var benchmarkExecutablePath: String

    @Option(name: .long, help: "The target name of the benchmark to run")
    var target: String

    @Option(name: .long, help: "The command to perform")
    var command: BenchmarkOperation

    @Option(name: .long, help: "The export file format to use, 'influx'")
    var exportFormat: ExportFormat?

    @Option(name: .long, help: "The path to baseline directory for storage")
    var baselineStoragePath: String

    @Option(name: .long, help: "The path to baseline directory for comparisons")
    var baselineComparisonPath: String

    // Used for pretty printing machine info etc.
    @Option(name: .long, help: "True if the invocation of this tool is the first in the run of the plugin")
    var firstBenchmarkTool: Bool

    @Option(name: .long, help: "True if we should supress output")
    var quiet: Bool

    @Option(name: .long, help: "The named baseline we should update or compare with")
    var baselineName: String?

    @Option(name: .long, help: "The second named baseline we should update or compare with for A/B")
    var baselineNameSecond: String?

    @Option(name: .long, help: "The output format to use, 'text' or 'markdown'")
    var format: OutputFormat

    @Option(name: .long, help: "The grouping to use, 'metric' or 'test'")
    var grouping: Grouping

    @Option(name: .long, help: "Benchmarks matching the regexp filter that should be run")
    var filter: [String] = []

    @Option(name: .long, help: "Benchmarks matching the regexp filter that should be skipped")
    var skip: [String] = []

    var inputFD: CInt = 0
    var outputFD: CInt = 0

    var benchmarks: [Benchmark] = []

    var currentBaseline: BenchmarkBaseline?

    var benchmarkFailure = false

    mutating func failBenchmark(_ reason: String) {
        print(reason)
        benchmarkFailure = true
    }

    func printChildRunError(_ result: Int32) {
        print("Failed to run '\(command)' for \(benchmarkExecutablePath), result [\(result)]")
        print("Likely your benchmark crahed, try running the tool in the debugger, e.g.")
        print("lldb \(benchmarkExecutablePath)")
        print("Or check Console.app for a backtrace if on macOS.")
    }

    func shouldRunBenchmark(_ name: String) throws -> Bool {
        if try skip.contains(where: { name.wholeMatch(of: try Regex($0)) != nil }) {
            return false
        }
        return try filter.isEmpty || filter.contains(where: { name.wholeMatch(of: try Regex($0)) != nil })
    }

    mutating func run() async throws {
        switch command {
        case .baseline:
            currentBaseline = try read(baselineIdentifier: baselineName)
            if let currentBaseline {
                prettyPrint(currentBaseline, header: "Current baseline")
            } else {
                print("No baseline found.")
            }
        case .compare:
            currentBaseline = try read(baselineIdentifier: baselineName)

            if let currentBaseline {
                if let baselineNameSecond { // we compare with another known baseline instead of running
                    let otherBaseline = try read(baselineIdentifier: baselineNameSecond)

                    if let otherBaseline {
                        prettyPrintDelta(otherBaseline)

                        if otherBaseline.betterResultsOrEqual(than: currentBaseline, printOutput: true) {
                            print("New baseline '\(baselineNameSecond)' for '\(target)' is BETTER (or equal) than the '\(baselineName ?? "default")' baseline thresholds.")
                            print("")
                        } else {
                            print("New baseline '\(baselineNameSecond)' for '\(target)' is WORSE than the '\(baselineName ?? "default")' baseline thresholds.")
                            print("")
                            benchmarkFailure = true
                        }

                        break
                    } else {
                        failBenchmark("\(target): Couldn't find baseline '\(baselineNameSecond)' to compare with, skipping comparison.")
                        return
                    }
                }
            }
            fallthrough
        case .list:
            fallthrough
        case .updateBaseline:
            fallthrough
        case .export:
            fallthrough
        case .run:
            // first get a list of benchmarks from the executable
            try runChild(benchmarkPath: benchmarkExecutablePath,
                         benchmarkCommand: .query) { [self] result in
                if result != 0 {
                    printChildRunError(result)
                }
            }

            var benchmarkResults: BenchmarkResults = [:]

            // run each benchmark for the target as a separate process
            try benchmarks.forEach { benchmark in
                if try shouldRunBenchmark(benchmark.name) {
                    // Then perform actions
                    let results = try runChild(benchmarkPath: benchmarkExecutablePath,
                                               benchmarkCommand: command,
                                               benchmark: benchmark) { [self] result in
                        if result != 0 {
                            printChildRunError(result)
                        }
                    }

                    benchmarkResults = benchmarkResults.merging(results) { _, new in new }
                }
            }
            try postProcessBenchmarkResults(benchmarkResults)
        default:
            print("Unknown command \(command) in BenchmarkTool")
        }

        if benchmarkFailure {
            #if canImport(Darwin)
                Darwin.exit(EXIT_FAILURE)
            #elseif canImport(Glibc)
                Glibc.exit(EXIT_FAILURE)
            #endif
        }
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
                              "--output-fd", fromChild.writeEnd.rawValue.description]

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
                    try queryBenchmarks() // Get all available benchmarks first
                case .list:
                    try listBenchmarks()
                case .updateBaseline:
                    fallthrough
                case .export:
                    fallthrough
                case .run:
                    fallthrough
                case .compare:
                    guard let benchmark else {
                        fatalError("No benchmark specified for update/export/run/compare operation")
                    }
                    benchmarkResults = try runBenchmark(benchmark)
                case .baseline:
                    fallthrough
                default:
                    print("Unknown command \(benchmarkCommand)")
                }

                try write(.end)
            } catch {}

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
