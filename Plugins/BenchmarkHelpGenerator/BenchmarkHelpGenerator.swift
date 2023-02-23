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

enum Grouping: String, ExpressibleByArgument {
    case metric
    case test
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
}

/*
 —format [text, markdown, jmh, percentiles, …]
 —compare baseline (if baseline only single)
 —path path (stdout default)
 —update
 —delete
 —target
 —filter
 —skip
 —skip-target
 —quiet
 —progress (progress bar)
 —verbose?
 */

@main
struct Benchmark: AsyncParsableCommand {
    @Argument(help: "The benchmark command to perform, one of: \((Command.allCases).map { String(describing: $0) }). 'baseline' can be followed by 0 or more named baselines (if 0, the baseline name 'default' is used)")
    var command: Command

    @Option(name: .long, help: "The output format to use, one of: \((OutputFormat.allCases).map { String(describing: $0) })")
    var format: OutputFormat

    @Option(name: .long, help: "The path where exported data is stored, default is current directory.")
    var path: String

    @Flag(name: .long, help: "Specifies that the baseline should be update with the data from the current run")
    var update: Int

    @Flag(name: .long, help: "Specifies that the baseline should be deleted")
    var delete: Int

    @Flag(name: .long, help: "True if we should supress output")
    var quiet: Int

    @Option(name: .long, help: "The named baseline we should update or compare with")
    var baseline: [String]

    @Option(name: .long, help: "The second named baseline we should update or compare with for A/B")
    var baselineNameSecond: String?

    @Option(name: .long, help: "The grouping to use, 'metric' or 'test'")
    var grouping: Grouping

    @Option(name: .long, help: "Benchmarks matching the regexp filter that should be run")
    var filter: [String] = []

    @Option(name: .long, help: "Benchmarks matching the regexp filter that should be skipped")
    var skip: [String] = []

    mutating func run() async throws {
    }
}
