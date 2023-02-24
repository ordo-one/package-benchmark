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

enum Grouping: String, ExpressibleByArgument, CaseIterable {
    case metric
    case benchmark
}

enum OutputFormat: String, ExpressibleByArgument, CaseIterable {
    case text
    case markdown
    case influx
    case percentiles
    case tsv
    case jmh
}

enum Command: String, ExpressibleByArgument, CaseIterable {
    case run
    case list
    case baseline
    case help
}

@main
struct Benchmark: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Runs your benchmark targets located in Benchmarks/",
        usage: """
        swift package benchmark <command>

        swift package benchmark run <options>
        swift package benchmark list
        swift package benchmark baseline [baseline1 baseline2 ... baselineN] <options>
        swift package benchmark help
        """,
        discussion: """
        Runs the benchmarks, lists or operates on baselines (a named, stored set of results).
        Some of the flags are only applicable to baseline operations and are so noted below.

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

    @Option(name: .long, help: "The path where exported data is stored, default is the current directory (\".\"). ")
    var path: String

    @Option(name: .long, help: "Compare either a benchmark run, or one baseline with the specified 'compare' baseline.")
    var compare: String

    @Flag(name: .long, help: "Specifies that the named baseline should be updated with the data from the current run")
    var update: Int

    @Flag(name: .long, help: "Specifies that the named baseline should be deleted")
    var delete: Int

    @Flag(name: .long, help: "Specifies that output should be supressed (useful for if you just want to check return code)")
    var quiet: Int

    @Flag(name: .long, help: "Specifies that benchmark progress information should not be displayed")
    var noProgress: Int

    @Option(name: .long, help: "The grouping to use, one of: \((Grouping.allCases).map { String(describing: $0) }). default is '\(Grouping.benchmark.rawValue)'")
    var grouping: Grouping

    mutating func run() async throws {}
}
