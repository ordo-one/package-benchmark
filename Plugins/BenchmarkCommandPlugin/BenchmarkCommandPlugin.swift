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
        let checkAbsoluteThresholdsPath = argumentExtractor.extractOption(named: "check-absolute-path")
        let checkAbsoluteThresholds = checkAbsoluteThresholdsPath.count > 0 ? 1 : argumentExtractor.extractFlag(named: "check-absolute")
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
                throw MyError.invalidArgument
            }
            print("")
            print(help)
            print("")
            print("Please visit https://github.com/ordo-one/package-benchmark for more in-depth documentation")
            print("")
            exit(0)
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
                throw MyError.invalidArgument
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
                throw MyError.invalidArgument
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
                throw MyError.invalidArgument
            }
            targetName = positionalArguments.removeFirst()
            do {
                let targets = try context.package.targets(named: [targetName])
                if targets.isEmpty == false {
                    print("Can't create benchmark executable target named \(targetName), a target with that name already exists.")
                    throw MyError.invalidArgument
                }
            } catch { // We will throw if we can use the target name (it's unused!)
            }
        }

        let swiftSourceModuleTargets: [SwiftSourceModuleTarget]
        var shouldBuildTargets = true // We don't rebuild the targets when we dont need to execute them, e.g. baseline read/compare

        let packageBenchmarkIdentifier = "package-benchmark"
        let benchmarkToolName = "BenchmarkTool"
        let benchmarkTool: PackagePlugin.Path // = try context.tool(named: benchmarkToolName)

        var args: [String] = [benchmarkToolName,
                              "--command", commandToPerform.rawValue,
                              "--baseline-storage-path", context.package.directory.string,
                              "--format", outputFormat.rawValue,
                              "--grouping", grouping]

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
                throw MyError.invalidArgument
            }
            args.append(contentsOf: ["--check-absolute"])
            if let path = checkAbsoluteThresholdsPath.first {
                args.append(contentsOf: ["--check-absolute-path", path])
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
            throw MyError.invalidArgument
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
                throw MyError.invalidArgument
            }

            args.append(contentsOf: ["--baseline-operation", baselineOperation.rawValue])

            // Check valid number of baselines specified per baseline operation
            switch baselineOperation {
            case .update:
                guard positionalArguments.count == 1 else {
                    print("A single baseline must be specified for update operations, got: \(positionalArguments)")
                    throw MyError.invalidArgument
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
                    if positionalArguments.count == validRange.upperBound { // dont check if we just read baselines
                        shouldBuildTargets = false
                    }
                } else {
                    let validRange = 1 ... 2
                    guard validRange.contains(positionalArguments.count) else {
                        print("Must specify exactly one or two baselines for comparisons or threshold violation checks, got: \(positionalArguments)")
                        throw MyError.invalidArgument
                    }
                    if positionalArguments.count == validRange.upperBound { // dont check if we just read baselines
                        shouldBuildTargets = false
                    }
                }
            case .read, .list, .delete:
                shouldBuildTargets = false
            }

            positionalArguments.forEach { baseline in
                args.append(contentsOf: ["--baseline", baseline])
            }
        }

        // don't build any targets if we don't need to run it for the operation, otherwise specified targets
        if commandToPerform == .`init` {
            swiftSourceModuleTargets = []
        } else {
            if specifiedTargets.isEmpty {
                swiftSourceModuleTargets = context.package.targets(ofType: SwiftSourceModuleTarget.self)
            } else {
                swiftSourceModuleTargets = specifiedTargets
            }
        }

        let benchmarkToolModuleTargets: [SwiftSourceModuleTarget]
        if context.package.id == packageBenchmarkIdentifier {
            benchmarkToolModuleTargets = context.package.targets(ofType: SwiftSourceModuleTarget.self)
        } else {
            if let benchmarkPackage = context.package.dependencies.first (where: { $0.package.id == packageBenchmarkIdentifier}) {
                benchmarkToolModuleTargets = benchmarkPackage.package.targets(ofType: SwiftSourceModuleTarget.self)
            } else {
                print("Benchmark failed to find the package-benchmark module.")
                throw MyError.buildFailed
            }
        }

        // Build the BenchmarkTool manually in release mode to work around https://github.com/apple/swift-package-manager/issues/7210
        if let benchmarkToolModule = benchmarkToolModuleTargets.first(where: { $0.kind == .executable && $0.name == benchmarkToolName}) {
            if outputFormat == .text {
                if quietRunning == 0 {
                    print("Building \(benchmarkToolModule.name) in release mode...")
                }
            }

            let buildResult = try packageManager.build(
                .product(benchmarkToolModule.name),
                parameters: .init(configuration: .release)
            )

            guard buildResult.succeeded else {
                print(buildResult.logText)
                print("Benchmark failed to build the BenchmarkTool in release mode.")
                throw MyError.buildFailed
            }

            let tool = buildResult.builtArtifacts.first(where: {$0.kind == .executable && $0.path.lastComponent == benchmarkToolName })

            guard let tool else {
                throw MyError.buildFailed
            }

            benchmarkTool = tool.path
        } else {
            print("Benchmark failed to find the BenchmarkTool target.")
            throw MyError.buildFailed
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
            if quietRunning == 0 && shouldBuildTargets {
                print("Building benchmark targets in release mode for benchmark run...")
            }
        }

        // Build targets in release mode
        try filteredTargets.forEach { target in
            args.append(contentsOf: ["--targets", target.name])

            if shouldBuildTargets {
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
                    throw MyError.buildFailed
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
        }

        var failedBenchmarkCount = 0

        try withCStrings(args) { cArgs in
            if debug > 0 {
                print("To debug, start \(benchmarkToolName) in LLDB using:")
                print("lldb \(benchmarkTool.string)")
                print("")
                print("Then launch \(benchmarkToolName) with:")
                print("run \(args.dropFirst().joined(separator: " "))")
                print("")
                return
            }

            var pid: pid_t = 0
            var status = posix_spawn(&pid, benchmarkTool.string, nil, nil, cArgs, environ)

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
                        case .baselineNotFound:
                            throw MyError.baselineNotFound
                        case .genericFailure:
                            print("One or more benchmark suites crashed during runtime.")
                            throw MyError.benchmarkCrashed
                        case .thresholdRegression:
                            throw MyError.benchmarkThresholdRegression
                        case .thresholdImprovement:
                            throw MyError.benchmarkThresholdImprovement
                        case .benchmarkJobFailed:
                            failedBenchmarkCount += 1
                        case .noPermissions:
                            throw MyError.noPermissions
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

        if failedBenchmarkCount > 0 {
            print("\(failedBenchmarkCount) benchmark job(s) failed during runtime.")
            throw MyError.benchmarkCrashed
        }
    }

    enum MyError: Int32, Error {
        case successs = 0
        case benchmarkUnexpectedReturnCode = 1
        case benchmarkThresholdRegression = 2
        case benchmarkCrashed = 3
        case benchmarkThresholdImprovement = 4
        case baselineNotFound = 5
        case noPermissions = 6
        case invalidArgument = 101
        case buildFailed = 102
    }
}
