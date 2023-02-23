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

enum ExportFormat: String, ExpressibleByArgument, CaseIterable {
    case influx
    case percentiles
    case tsv
    case jmh
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

    @Option(name: .long, help: "The export file format to use \((ExportFormat.allCases).map { String(describing: $0) })")
    var exportFormat: ExportFormat?

    @Option(name: .long, help: "The path to baseline directory for storage")
    var baselineStoragePath: String

    @Option(name: .long, help: "The path to export to")
    var path: String?

    @Option(name: .long, help: "The baseline to compare with")
    var compare: String?

    @Option(name: .long, help: "True if we should supress output")
    var quiet: Bool

    @Option(name: .long, help: "True if we should update the baseline")
    var update: Bool?

    @Option(name: .long, help: "True if we should delete the baseline")
    var delete: Bool?

    @Option(name: .long, help: "True if we should supress progress in benchmark run")
    var noProgress: Bool?

    @Option(name: .long, help: "The named baseline(s) we should display, update, delete or compare with")
    var baseline: [String] = []

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

    var targets: [String] {
        benchmarkExecutablePaths.map { FilePath($0).lastComponent!.description }
    }

    var inputFD: CInt = 0
    var outputFD: CInt = 0

    var benchmarks: [Benchmark] = []
    var baselines: [BenchmarkBaseline] = [] // The baselines read from disk, merged

    mutating func failBenchmark(_ reason: String? = nil) {
        if let reason {
            print(reason)
            print("")
        }
        #if canImport(Darwin)
            Darwin.exit(EXIT_FAILURE)
        #elseif canImport(Glibc)
            Glibc.exit(EXIT_FAILURE)
        #endif
    }

    func printChildRunError(error: Int32, benchmarkExecutablePath: String) {
        print("Failed to run '\(command)' for \(benchmarkExecutablePath), error code [\(error)]")
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

    mutating func readBaselines() throws {
        // read all specified baselines
        var readBaselines: [BenchmarkBaseline] = [] // The baselines read from disk

        try baseline.forEach { baselineName in // for all specified baselines at command line
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

                baselines.append(aggregatedBaseline)
            }
            readBaselines.removeAll(keepingCapacity: true)
        }
    }

    mutating func run() async throws {
        try readBaselines()
        switch command {
        case .query:
            fatalError("Query command should never be specified to the BenchmarkTool")
        case .baseline:

            if compare != nil && baselines.count > 1 {
                try postProcessBenchmarkResults()
                return
            } else {

            }

            return
        case .list:
            break
        case .run:
            if quiet == false {
                let runString = "Running Benchmarks"
                let separator = String(repeating: "=", count: runString.count)
                print("")
                print(separator)
                print(runString)
                print(separator)
                print("")
                fflush(stdout)
            }
            break
        }

        if command == .list || command == .run {

            // First get a list of all benchmarks
            try benchmarkExecutablePaths.forEach { benchmarkExecutablePath in
                try runChild(benchmarkPath: benchmarkExecutablePath,
                             benchmarkCommand: .query) { [self] result in
                    if result != 0 {
                        printChildRunError(error: result, benchmarkExecutablePath: benchmarkExecutablePath)
                    }
                }
            }

            guard command != .list else {
                try listBenchmarks()
                return
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
            baseline.insert("Current run", at:0)
            baselines.insert(BenchmarkBaseline(machine: benchmarkMachine(), results: benchmarkResults), at: 0)
        }

        try postProcessBenchmarkResults()
    }

    /*
     mutating func run() async throws {
     switch command {
     case .baseline:
     try targets.forEach { target in
     let currentBaseline = try read(target: target, baselineIdentifier: baselineName)
     if let currentBaseline {
     readBaselines.append(currentBaseline)
     }
     }

     if readBaselines.isEmpty {
     print("No baseline found.")
     } else {
     var aggregatedBaseline = readBaselines.first!
     for baseline in 1 ..< readBaselines.count {
     aggregatedBaseline = aggregatedBaseline.merge(readBaselines[baseline])
     }
     prettyPrint(aggregatedBaseline, header: "Current baseline")
     }
     return
     case .compare:
     var otherBaselines: [BenchmarkBaseline] = []

     try targets.forEach { target in
     let currentBaseline = try read(target: target, baselineIdentifier: baselineName)

     if let currentBaseline {
     readBaselines.append(currentBaseline)
     if let baselineNameSecond { // we compare with another known baseline instead of running
     let otherBaseline = try read(target: target, baselineIdentifier: baselineNameSecond)
     if let otherBaseline {
     otherBaselines.append(otherBaseline)
     }
     }
     }
     }

     // Merge baselines read
     var aggregatedBaseline = readBaselines.first!
     for baseline in 1 ..< readBaselines.count {
     aggregatedBaseline = aggregatedBaseline.merge(readBaselines[baseline])
     }

     // We read a second set of baseline to compare with
     if otherBaselines.isEmpty == false {
     // merge those as well
     var otherAggregatedBaseline = otherBaselines.first!
     for baseline in 1 ..< otherBaselines.count {
     otherAggregatedBaseline = otherAggregatedBaseline.merge(otherBaselines[baseline])
     }

     prettyPrintDelta(currentBaseline:aggregatedBaseline, baseline: otherAggregatedBaseline)

     if otherAggregatedBaseline.betterResultsOrEqual(than: aggregatedBaseline, printOutput: true) {
     print("New baseline '\(baselineNameSecond ?? "current")' is BETTER (or equal) than the '\(baselineName ?? "default")' baseline thresholds.")
     print("")

     } else {
     failBenchmark("New baseline '\(baselineNameSecond ?? "current ")' is WORSE than the '\(baselineName ?? "default")' baseline thresholds.")
     }

     return
     } else if baselineNameSecond != nil {
     failBenchmark("Couldn't find baseline '\(baselineNameSecond!)' to compare with, skipping comparison.")
     }

     //              return
     //            }

     /*

      try targets.forEach { target in
      currentBaseline = try read(target: target, baselineIdentifier: baselineName)

      if let currentBaseline {
      readBaselines.append(currentBaseline)
      if let baselineNameSecond { // we compare with another known baseline instead of running
      let otherBaseline = try read(target: target, baselineIdentifier: baselineNameSecond)

      if let otherBaseline {
      prettyPrintDelta(baseline: otherBaseline, target: target)

      if otherBaseline.betterResultsOrEqual(than: currentBaseline, printOutput: true) {
      print("New baseline '\(baselineNameSecond)' for '\(target)' is BETTER (or equal) than the '\(baselineName ?? "default")' baseline thresholds.")
      print("")

      } else {
      failBenchmark("New baseline '\(baselineNameSecond)' for '\(target)' is WORSE than the '\(baselineName ?? "default")' baseline thresholds.")
      }
      } else {
      failBenchmark("\(target): Couldn't find baseline '\(baselineNameSecond)' to compare with, skipping comparison.")
      }
      return
      }
      }
      } */
     case .export:
     var results: BenchmarkResults = [:]
     try targets.forEach { target in
     if let baselineName {
     if let currentBaseline = try read(target: target, baselineIdentifier: baselineName) {
     readBaselines.append(currentBaseline)
     results.merge(currentBaseline.results) { first, _ in first }
     } else {
     failBenchmark("\(target): Couldn't read baseline '\(baselineName)' for export.")
     }
     return
     }
     }
     try postProcessBenchmarkResults(results)
     case .list:
     break
     case .updateBaseline:
     break
     case .run:
     if quiet == false {
     let runString = "Running Benchmarks"
     let separator = String(repeating: "=", count: runString.count)
     print("")
     print(separator)
     print(runString)
     print(separator)
     print("")
     fflush(stdout)
     }
     break
     default:
     print("Unknown command \(command) in BenchmarkTool")
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

     guard command != .list else {
     try listBenchmarks()
     return
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

     try postProcessBenchmarkResults(benchmarkResults)
     }

     */

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
                              "--quiet", quiet.description]

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
