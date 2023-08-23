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
@main struct BenchmarkCommandPlugin: CommandPlugin {
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
        let quietRunning = argumentExtractor.extractFlag(named: "quiet")
        let noProgress = argumentExtractor.extractFlag(named: "no-progress")
        let checkAbsoluteThresholds = argumentExtractor.extractFlag(named: "check-absolute")
        let checkAbsoluteThresholdsPath = argumentExtractor.extractOption(named: "check-absolute-path")
        let groupingToUse = argumentExtractor.extractOption(named: "grouping")
        let metricsToUse = argumentExtractor.extractOption(named: "metric")
        let debug = argumentExtractor.extractFlag(named: "debug")
        let scale = argumentExtractor.extractFlag(named: "scale")
        var outputFormat: OutputFormat = .text
        var grouping = "benchmark"
        var exportPath = "."

        // Flush stdout so we see any failures clearly
        setbuf(stdout, nil)

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

        if outputFormats.count > 0 {
            if let format = OutputFormat(rawValue: outputFormats.first!) {
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

        var targetName = "Invalid"

        if commandToPerform == .`init` {
            guard positionalArguments.count == 1 else {
                print("Must specify exactly one benchmark target name to create, e.g.:")
                print("swift package --allow-writing-to-package-directory benchmark init MyBenchmarkName")
                return
            }
            targetName = positionalArguments.removeFirst()
            do {
                let targets = try context.package.targets(named: [targetName])
                if targets.isEmpty == false {
                    print("Can't create benchmark executable target named \(targetName), a target with that name already exists.")
                    return
                }
            } catch { // We will throw if we can use the target name (it's unused!)
            }
        }

        let swiftSourceModuleTargets: [SwiftSourceModuleTarget]

        // don't build any targets if we're creating a benchmark, otherwise specified targets
        if commandToPerform == .`init` {
            swiftSourceModuleTargets = []
        } else {
            if specifiedTargets.isEmpty {
                swiftSourceModuleTargets = context.package.targets(ofType: SwiftSourceModuleTarget.self)
            } else {
                swiftSourceModuleTargets = specifiedTargets
            }
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
            }
        }

        let benchmarkTool = try context.tool(named: "BenchmarkTool")

        var args: [String] = [benchmarkTool.path.lastComponent.description,
                              "--command", commandToPerform.rawValue,
                              "--baseline-storage-path", context.package.directory.string,
                              "--format", outputFormat.rawValue,
                              "--grouping", grouping]

        try filteredTargets.forEach { target in
            if outputFormat == .text {
                if quietRunning == 0 {
                    print("Building \(target.name)")
                }
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

        metricsToUse.forEach { metric in
            args.append(contentsOf: ["--metrics", metric.description])
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

        if checkAbsoluteThresholds > 0 {
            if checkAbsoluteThresholdsPath.count > 1 {
                print("Only a single path for thresholds can be specified, got \(checkAbsoluteThresholdsPath.count).")
                return
            }
            args.append(contentsOf: ["--check-absolute-thresholds"])
            if let path = checkAbsoluteThresholdsPath.first {
                args.append(contentsOf: ["--check-absolute-thresholds-path", path])
            }
        }

        if scale > 0 {
            args.append(contentsOf: ["--scale"])
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

        if commandToPerform == .`init` {
            args.append(contentsOf: ["--benchmark-executable-paths", "/tmp/\(targetName)"])
            args.append(contentsOf: ["--target-name", targetName])
        }

        if commandToPerform == .run, positionalArguments.count > 0 {
            print("Can't specify baselines for normal run operation, superfluous arguments [\(positionalArguments)]")
            return
        }

        if commandToPerform == .baseline {
            guard positionalArguments.count > 0,
                  let baselineOperation = BaselineOperation(rawValue: positionalArguments.removeFirst()) else {
                print("")
                print("A valid baseline command must be specified, one of: '\(BaselineOperation.allCases.description)'.")
                print("")
                print(help)
                print("")
                print("Please visit https://github.com/ordo-one/package-benchmark for more in-depth documentation")
                print("")
                return
            }

            args.append(contentsOf: ["--baseline-operation", baselineOperation.rawValue])

            // Check valid number of baselines specified per baseline operation
            switch baselineOperation {
            case .update:
                guard positionalArguments.count == 1 else {
                    print("A single baseline must be specified for update operations, got: \(positionalArguments)")
                    return
                }
            case .compare:
                fallthrough
            case .check:
                if checkAbsoluteThresholds > 0 {
                    let validRange = 0 ... 1
                    guard validRange.contains(positionalArguments.count) else {
                        print("Must specify exactly zero or one baseline for check against absolute thresholds, got: \(positionalArguments)")
                        throw MyError.invalidArgument
                    }
                } else {
                    let validRange = 1 ... 2
                    guard validRange.contains(positionalArguments.count) else {
                        print("Must specify exactly one or two baselines for comparisons or threshold violation checks, got: \(positionalArguments)")
                        throw MyError.invalidArgument
                    }
                }
            default:
                break
            }

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
                    // Ok, this sucks, but there is no way to get a C support target for plugins and
                    // the way the status is extracted portably is with macros - so we just need to
                    // reimplement the logic here in Swift according to the waitpid man page to
                    // get some nicer feedback on failure reason.
                    if let waitStatus = ExitCode(rawValue: (status & 0xFF00) >> 8) {
                        switch waitStatus {
                        case .success:
                            break
                        case .genericFailure:
                            print("One or more benchmark suites crashed during runtime.")
                            throw MyError.benchmarkCrashed
                        case .thresholdViolation:
                            throw MyError.benchmarkThresholdDeviation
                        case .benchmarkJobFailed:
                            print("One benchmark job failed during runtime, continuing with remaining.")
                            break
                        }
                    } else {
                        print("One or more benchmarks returned an unexpected return code \(status)")
                        throw MyError.benchmarkUnexpectedReturnCode
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
        case benchmarkThresholdDeviation
        case benchmarkCrashed
        case benchmarkUnexpectedReturnCode
        case invalidArgument
    }
}
