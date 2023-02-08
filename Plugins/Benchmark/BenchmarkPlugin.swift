//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

// 'Benchmark' plugin that is responsible for gathering command line arguments and then
// Running the `BenchmarkTool` for each benchmark target.

import PackagePlugin

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#else
    #error("Unsupported Platform")
#endif

@main struct Benchmark: CommandPlugin {
    func withCStrings(_ strings: [String], scoped: ([UnsafeMutablePointer<CChar>?]) throws -> Void) rethrows {
        let cStrings = strings.map { strdup($0) }
        try scoped(cStrings + [nil])
        cStrings.forEach { free($0) }
    }

    func performCommand(context: PluginContext, arguments: [String]) throws {
        // Get specific target(s) to run benchmarks for if specified on command line
        var argumentExtractor = ArgumentExtractor(arguments)
        let specifiedTargets = try argumentExtractor.extractSpecifiedTargets(in: context.package, withOption: "target")
        let skipTargets = try argumentExtractor.extractSpecifiedTargets(in: context.package, withOption: "skip")
        let outputFormats = argumentExtractor.extractOption(named: "format")
        let groupingToUse = argumentExtractor.extractOption(named: "grouping")
        let quietRunning = argumentExtractor.extractFlag(named: "quiet")
        var outputFormat = "text"
        var grouping = "test"

        if outputFormats.count > 0 {
            if let format = outputFormats.first {
                switch format {
                case "markdown":
                    fallthrough
                case "text":
                    outputFormat = format
                default:
                    print("Unknown output format '\(format)', valid output formats are 'text' and 'markdown'")
                    return
                }
            }
            if outputFormats.count > 1 {
                print("Only a single output format may be specified, will use the first one specified '\(outputFormat)'")
            }
        }

        if groupingToUse.count > 0 {
            if let group = groupingToUse.first {
                switch group {
                case "test":
                    fallthrough
                case "metric":
                    grouping = "metric"
                default:
                    print("Unknown grouping '\(group)', valid groupings are 'metric' and 'test'")
                    return
                }
            }
            if groupingToUse.count > 1 {
                print("Only a single grouping may be specified, will use the first one specified '\(grouping)'")
            }
        }

        // Build all targets
        if outputFormat == "text" {
            if quietRunning == 0 {
                print("Building targets in release mode for benchmark run...")
                fflush(nil)
            }
        }
        let buildResult = try packageManager.build(
            .all(includingTests: false),
            parameters: .init(configuration: .release)
        )
        if outputFormat == "text" {
            if quietRunning == 0 {
                print("Build complete! Running benchmarks...")
                print("")
            }
        }

        guard buildResult.succeeded else {
            print(buildResult.logText)
            print("Benchmark failed to run due to build error.")
            return
        }

        let swiftSourceModuleTargets: [SwiftSourceModuleTarget]
        if specifiedTargets.isEmpty {
            swiftSourceModuleTargets = context.package.targets(ofType: SwiftSourceModuleTarget.self)
        } else {
            swiftSourceModuleTargets = specifiedTargets
        }

        let filteredTargets = swiftSourceModuleTargets
            .filter { $0.kind == .executable }
            .filter { benchmark in
                let path = benchmark.directory.removingLastComponent()
                return path.lastComponent == "Benchmarks" ? true : false
            }
            .filter { benchmark in
                swiftSourceModuleTargets.first(where: { $0.name == benchmark.name }) != nil ? true : false
            }
            .filter { benchmark in
                skipTargets.first(where: { $0.name == benchmark.name }) == nil ? true : false
            }

        // Filter out all executable products which are Benchmarks we should run
        let benchmarks = buildResult.builtArtifacts
            .filter { benchmark in
                filteredTargets.first(where: { $0.name == benchmark.path.lastComponent }) != nil ? true : false
            }

        // Remaining positional arguments are various action verbs for the plugin
        var positionalArguments = argumentExtractor.remainingArguments

        let commandToPerform = positionalArguments.count > 0 ? positionalArguments.removeFirst() : "run" // default

        let benchmarkTool = try context.tool(named: "BenchmarkTool")

        var firstBenchmarkTool = true

        var benchmarkFailure = false
        // Run the benchmarkTool for each target, constructing proper argument list for the BenchmarkTool
        benchmarks.forEach { benchmark in
            var pid: pid_t = 0

            var args: [String] = [benchmarkTool.path.lastComponent.description,
                                  "--target", benchmark.path.lastComponent.description,
                                  "--benchmark-executable-path", benchmark.path.string,
                                  "--baseline-storage-path", context.package.directory.string,
                                  "--baseline-comparison-path", context.package.directory.string,
                                  "--format", outputFormat,
                                  "--grouping", grouping,
                                  "--quiet", quietRunning > 0 ? true.description : false.description,
                                  "--first-benchmark-tool", firstBenchmarkTool.description]

            switch commandToPerform {
            case "list":
                args.append(contentsOf: ["--command", "list"])
            case "run":
                args.append(contentsOf: ["--command", "run"])
            case "compare":
                args.append(contentsOf: ["--command", "compare"])
                if positionalArguments.count > 0 {
                    args.append(contentsOf: ["--baseline-name", positionalArguments[0]])
                }
                if positionalArguments.count > 1 {
                    args.append(contentsOf: ["--baseline-name-second", positionalArguments[1]])
                }
            case "update-baseline":
                args.append(contentsOf: ["--command", "update-baseline"])
                if positionalArguments.count > 0 {
                    args.append(contentsOf: ["--baseline-name", positionalArguments[0]])
                }
            case "export":
                args.append(contentsOf: ["--command", "export"])
                if positionalArguments.count > 0 {
                    args.append(contentsOf: ["--export-format", positionalArguments[0]])
                }
            case "baseline":
                args.append(contentsOf: ["--command", "baseline"])
                if positionalArguments.count > 0 {
                    args.append(contentsOf: ["--baseline-name", positionalArguments[0]])
                }
            default:
                print("Unknown command/option \(commandToPerform)")
                return
            }

            withCStrings(args) { cArgs in
                var status = posix_spawn(&pid, benchmarkTool.path.string, nil, nil, cArgs, environ)

                if status == 0 {
                    if waitpid(pid, &status, 0) != -1 {
                        if status != 0 {
                            benchmarkFailure = true
                        }
                    } else {
                        print("BenchmarkTool returned a non-zero exit code, errno = \(errno)")
                        exit(errno)
                    }
                } else {
                    print("Failed to run BenchmarkTool, posix_spawn() returned [\(status)]")
                }
            }

            firstBenchmarkTool = false
        }
        if benchmarkFailure {
            print("One or more benchmark suites had a threshold violation or crashed during runtime.")
            throw MyError.benchmarkDeviationOrBenchmarkFailed
        }
    }

    enum MyError: Error {
        case benchmarkDeviationOrBenchmarkFailed
    }
}
