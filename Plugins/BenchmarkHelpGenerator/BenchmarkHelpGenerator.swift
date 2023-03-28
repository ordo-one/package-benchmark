//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

// Just a dummy target that helps us generate the help output for the plugin
// instead of writing it by hand

import ArgumentParser

let availableMetrics = [
    "cpuUser",
    "cpuSystem",
    "cpuTotal",
    "wallClock",
    "throughput",
    "peakMemoryResident",
    "peakMemoryVirtual",
    "mallocCountSmall",
    "mallocCountLarge",
    "mallocCountTotal",
    "allocatedResidentMemory",
    "memoryLeaked",
    "syscalls",
    "contextSwitches",
    "threads",
    "threadsRunning",
    "readSyscalls",
    "writeSyscalls",
    "readBytesLogical",
    "writeBytesLogical",
    "readBytesPhysical",
    "writeBytesPhysical",
    "retainCount",
    "releaseCount",
    "retainReleaseDelta",
    "custom"
]

extension Command: ExpressibleByArgument {}
extension Grouping: ExpressibleByArgument {}
extension OutputFormat: ExpressibleByArgument {}
extension BaselineOperation: ExpressibleByArgument {}

@main
struct Benchmark: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Run benchmarks or update, compare or check performance baselines",
        usage: """
        swift package benchmark <command>

        swift package benchmark [run] <options>
        swift package benchmark init <benchmarkTargetName>
        swift package benchmark list
        swift package benchmark baseline list
        swift package benchmark baseline read <baseline> [<baseline2> ... <baselineN>] [<options>]
        swift package benchmark baseline update <baseline> [<options>]
        swift package benchmark baseline delete <baseline> [<baseline2> ... <baselineN>] [<options>]
        swift package benchmark baseline check <baseline> [<otherBaseline>] [<options>]
        swift package benchmark baseline compare <baseline> [<otherBaseline>] [<options>]
        swift package benchmark help
        """,
        discussion: """
        Performs operations on benchmarks (running or listing them), as well as storing, comparing baselines as well as checking them for threshold deviations.

        The init command will create a skeleton benchmark suite for you and add it to Package.swift.

        For the 'text' default format, the output is implicitly 'stdout' unless otherwise specified.
        For all other formats, the output is to a file in either the current working directory, or
        the directory specified by the '--path' option, unless the special 'stdout' path is specified
        in which case output will go to stdout (useful for e.g. baseline 'tsv' format export piped to youplot).

        To allow writing to the package directory, you may need to pass the appropriate option to swift package:
        swift package --allow-writing-to-package-directory benchmark <command> <options>
        """
    )

    @Argument(help: "The benchmark command to perform, one of: \((Command.allCases).map { String(describing: $0) }). If not specified, 'run' is implied.")
    var command: Command

    @Option(name: .long, help: "Benchmarks matching the regexp filter that should be run")
    var filter: [String] = []

    @Option(name: .long, help: "Benchmarks matching the regexp filter that should be skipped")
    var skip: [String] = []

    @Option(name: .long, help: "Benchmark targets matching the regexp filter that should be run")
    var target: [String] = []

    @Option(name: .long, help: "Benchmark targets matching the regexp filter that should be skipped")
    var skipTarget: [String] = []

    @Option(name: .long, help: "The output format to use, one of: \((OutputFormat.allCases).map { String(describing: $0) }), default is '\(OutputFormat.text.rawValue)'")
    var format: OutputFormat

    @Option(name: .long, help: "Specifies that the benchmark run should use one or more specific metrics instead of the ones defined by the benchmarks, valid values are: \(availableMetrics)")
    var metric: [String] = []

    @Option(name: .long, help: "The path where exported data is stored, default is the current directory (\".\"). ")
    var path: String

    @Flag(name: .long, help: "Specifies that output should be suppressed (useful for if you just want to check return code)")
    var quiet: Int

    @Flag(name: .long, help: "Specifies that some of the text output should be scaled using the scalingFactor (denoted by '*' in output)")
    var scale: Int

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

    @Flag(name: .long, help: "Specifies that benchmark progress information should not be displayed")
    var noProgress: Int

    @Option(name: .long, help: "The grouping to use, one of: \((Grouping.allCases).map { String(describing: $0) }). default is '\(Grouping.benchmark.rawValue)'")
    var grouping: Grouping

    mutating func run() async throws {}
}
