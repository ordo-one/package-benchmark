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

@main
struct BenchmarkTool: AsyncParsableCommand {
    @Option(name: .long, help: "The path to the benchmark to run")
    var benchmarkExecutablePath: String

    @Option(name: .long, help: "The target name of the benchmark to run")
    var target: String

    @Option(name: .long, help: "The command to perform")
    var command: String

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

    var inputFD: CInt = 0
    var outputFD: CInt = 0

    var benchmarks: [Benchmark] = []

    var currentBaseline: BenchmarkBaseline?

    var benchmarkFailure = false

    mutating func failBenchmark(_ reason: String) {
        print(reason)
        benchmarkFailure = true
    }

    mutating func run() async throws {
        switch command {
        case "baseline":
            currentBaseline = try read(baselineIdentifier: baselineName)
            if let currentBaseline = currentBaseline {
                prettyPrint(currentBaseline, header: "Current baseline")
            } else {
                print("No baseline found.")
            }
        case "compare":
            currentBaseline = try read(baselineIdentifier: baselineName)

            if let currentBaseline = currentBaseline {
                if let baselineNameSecond = baselineNameSecond { // we compare with another known baseline instead of running
                    let otherBaseline = try read(baselineIdentifier: baselineNameSecond)

                    if let otherBaseline = otherBaseline {
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
        case "list":
            fallthrough
        case "update-baseline":
            fallthrough
        case "run":
            try runChild(benchmarkExecutablePath) { [self] result in
                if result != 0 {
                    print("Failed to run '\(command)' for \(benchmarkExecutablePath), result [\(result)]")
                    print("Likely your benchmark crahed, try running the tool in the debugger, e.g.")
                    print("lldb \(benchmarkExecutablePath)")
                    print("Or check Console.app for a backtrace if on macOS.")
                }
            }
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

    mutating func runChild(_ benchmarkPath: String, completion: ((Int32) -> Void)? = nil) throws {
        var pid: pid_t = 0

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
                try queryBenchmarks() // Get all available benchmarks first

                switch command {
                case "update-baseline":
                    fallthrough
                case "run":
                    fallthrough
                case "compare":
                    try runBenchmarks()
                case "list":
                    try listBenchmarks()
                case "baseline":
                    fallthrough
                default:
                    print("Unknown command \(command)")
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
    }
}
