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

@available(macOS 13.0, *)
@main struct Benchmark: CommandPlugin {
    enum Command: String {
        case run
        case list
        case baseline
        case help
    }

    enum Format: String {
        case text
        case markdown
        case influx
        case percentiles
        case tsv
        case jmh
    }

    enum Grouping: String {
        case metric
        case benchmark
    }

    func withCStrings(_ strings: [String], scoped: ([UnsafeMutablePointer<CChar>?]) throws -> Void) rethrows {
        let cStrings = strings.map { strdup($0) }
        try scoped(cStrings + [nil])
        cStrings.forEach { free($0) }
    }

    func performCommand(context: PluginContext, arguments: [String]) throws {
        // Get specific target(s) to run benchmarks for if specified on command line
        var argumentExtractor = ArgumentExtractor(arguments)
        let filterSpecified = argumentExtractor.extractOption(named: "filter")
        let skipSpecified = argumentExtractor.extractOption(named: "skip")
        let specifiedTargets = try argumentExtractor.extractSpecifiedTargets(in: context.package, withOption: "target")
        let skipTargets = try argumentExtractor.extractSpecifiedTargets(in: context.package, withOption: "skip-target")
        let outputFormats = argumentExtractor.extractOption(named: "format")
        let pathSpecified = argumentExtractor.extractOption(named: "path") // export path
        let compareSpecified = argumentExtractor.extractOption(named: "compare")
//        let updateBaseline = argumentExtractor.extractFlag(named: "update")
//        let deleteBaseline = argumentExtractor.extractFlag(named: "delete")
        let quietRunning = argumentExtractor.extractFlag(named: "quiet")
        let noProgress = argumentExtractor.extractFlag(named: "no-progress")
        let groupingToUse = argumentExtractor.extractOption(named: "grouping")
        let debug = argumentExtractor.extractFlag(named: "debug")
        var outputFormat: Format = .text
        var grouping = "benchmark"
        var exportPath = "."
        var comparisonBaseline = "default"

        if argumentExtractor.unextractedOptionsOrFlags.count > 0 {
            print("Unknown option/flag specfied: \(argumentExtractor.unextractedOptionsOrFlags)")
            throw MyError.invalidArgument
        }

        // Remaining positional arguments are various action verbs for the plugin
        var positionalArguments = argumentExtractor.remainingArguments

        let commandString = positionalArguments.count > 0 ? positionalArguments.removeFirst() : Command.run.rawValue

        guard let commandToPerform = Command(rawValue: commandString), commandToPerform != .help else {
            if commandString != "help" {
                print("")
                print("Unknown command '\(commandString)'.")
            }
            print("")
            print(help)
            print("")
            print("Please visit https://github.com/ordo-one/package-benchmark for more in-depth documentation")
            print("")
            return
        }

        if pathSpecified.count > 0 {
            exportPath = pathSpecified.first!
            if pathSpecified.count > 1 {
                print("Only a single output path may be specified, will use the first one specified '\(exportPath)'")
            }
        }

        if compareSpecified.count > 0 {
            comparisonBaseline = compareSpecified.first!
            if compareSpecified.count > 1 {
                print("Only a single comparison baseline may be specified, will use the first one specified '\(comparisonBaseline)'")
            }
        }

        if outputFormats.count > 0 {
            if let format = Format(rawValue: outputFormats.first!) {
                outputFormat = format
            } else {
                print("Unknown output format '\(outputFormats.first!)'")
                return
            }
            if outputFormats.count > 1 {
                print("Only a single output format may be specified, will use the first one specified '\(outputFormat)'")
            }
        }

        if groupingToUse.count > 0 {
            if let group = Grouping(rawValue: groupingToUse.first!) {
                grouping = group.rawValue
            } else {
                print("Unknown grouping '\(groupingToUse.first!)', valid groupings are 'metric' and 'benchmark'")
                return
            }
            if groupingToUse.count > 1 {
                print("Only a single grouping may be specified, will use the first one specified '\(grouping)'")
            }
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

        // Build the targets
        if outputFormat == .text {
            if quietRunning == 0 {
                print("Building benchmark targets in release mode for benchmark run...")
                fflush(nil)
            }
        }

        let benchmarkTool = try context.tool(named: "BenchmarkTool")

        var args: [String] = [benchmarkTool.path.lastComponent.description,
                              "--command", commandToPerform.rawValue,
                              "--baseline-storage-path", context.package.directory.string,
                              "--format", outputFormat.rawValue,
                              "--grouping", grouping]

        try filteredTargets.forEach { target in
            if quietRunning == 0 {
                print("Building \(target.name)")
            }

            let buildResult = try packageManager.build(
                .product(target.name), // .all(includingTests: false),
                parameters: .init(configuration: .release)
            )

            guard buildResult.succeeded else {
                print(buildResult.logText)
                print("Benchmark failed to run due to build error.")
                return
            }

            // Filter out all executable products which are Benchmarks we should run
            let benchmarks = buildResult.builtArtifacts
                .filter { benchmark in
                    filteredTargets.first(where: { $0.name == benchmark.path.lastComponent }) != nil ? true : false
                }

            if benchmarks.isEmpty {
                throw ArgumentParsingError.noMatchingTargetsForRegex
            }

            benchmarks.forEach { benchmark in
                args.append(contentsOf: ["--benchmark-executable-paths", benchmark.path.string])
            }
        }

        if outputFormat == .text {
            if quietRunning == 0 {
                print("Build complete!")
            }
        }

        if quietRunning > 0 {
            args.append(contentsOf: ["--quiet"])
        }

        if noProgress > 0 {
            args.append(contentsOf: ["--no-progress"])
        }

        if compareSpecified.count > 0 {
            args.append(contentsOf: ["--compare", comparisonBaseline])
        }

        filterSpecified.forEach { filter in
            args.append(contentsOf: ["--filter", filter])
        }

        skipSpecified.forEach { skip in
            args.append(contentsOf: ["--skip", skip])
        }

        if pathSpecified.count > 0 {
            args.append(contentsOf: ["--path", exportPath])
        }

        if commandToPerform == .run, positionalArguments.count > 0 {
            print("Can't specify baselines for normal run operation, superfluous arguments [\(positionalArguments)]")
            return
        }

        if commandToPerform == .baseline {
            if let firstBaselineArgument = positionalArguments.first {
                switch firstBaselineArgument {
                case "update":
                    positionalArguments.removeFirst()
                    args.append(contentsOf: ["--update"])

                    if positionalArguments.count > 1 {
                        print("Only a single baseline may be specified for update operations \(positionalArguments)")
                        return
                    }
                case "delete":
                    positionalArguments.removeFirst()
                    args.append(contentsOf: ["--delete"])
                case "compare":
                    positionalArguments.removeFirst()
                    if positionalArguments.count > 2 {
                        print("Multiple baselines can't be compared, only one or two baselines may be specified for comparisons \(positionalArguments)")
                        throw MyError.invalidArgument
                    }

                    // This will be the second if two, the first otherwise
                    args.append(contentsOf: ["--compare", positionalArguments.removeLast()])
                case "read": // to allow for a baseline named 'update'
                    positionalArguments.removeFirst()
                case "list":
                    positionalArguments.removeFirst()
                    args.append(contentsOf: ["--list-baselines"])
                default:
                    break
                }
            }
        }

        if commandToPerform == .baseline, positionalArguments.count == 0 {
            args.append(contentsOf: ["--baseline", "default"])
        } else {
            positionalArguments.forEach { baseline in
                args.append(contentsOf: ["--baseline", baseline])
            }
        }

        try withCStrings(args) { cArgs in
            let newPath = benchmarkTool.path
            // This doesn't work for external dependents
            // https://forums.swift.org/t/swiftpm-always-rebuilds-command-plugins-in-release-configuration/63225
//            let toolname = benchmarkTool.path.lastComponent
//            let newPath = benchmarkTool.path.removingLastComponent().removingLastComponent()
//                .appending(subpath: "release").appending(subpath: toolname)

            if debug > 0 {
                print("To debug, start BenchmarkTool in LLDB using:")
                print("lldb \(newPath.string)")
                print("")
                print("Then launch BenchmarkTool with:")
                print("run \(args.dropFirst().joined(separator: " "))")
                print("")
                return
            }

            var pid: pid_t = 0
            var status = posix_spawn(&pid, newPath.string, nil, nil, cArgs, environ)

            if status == 0 {
                if waitpid(pid, &status, 0) != -1 {
                    if status != 0 {
                        print("One or more benchmark suites had a threshold violation or crashed during runtime.")
                        throw MyError.benchmarkDeviationOrBenchmarkFailed
                    }
                } else {
                    print("waitpid() for pid \(pid) returned a non-zero exit code \(status), errno = \(errno)")
                    exit(errno)
                }
            } else {
                print("Failed to run BenchmarkTool, posix_spawn() returned [\(status)]")
            }
        }
    }

    enum MyError: Error {
        case benchmarkDeviationOrBenchmarkFailed
        case invalidArgument
    }
}
