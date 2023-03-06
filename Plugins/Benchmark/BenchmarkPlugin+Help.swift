//
// Copyright (c) 2023 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

let help =
    """
    OVERVIEW: Runs your benchmark targets located in Benchmarks/

    Runs the benchmarks, lists or operates on baselines (a named, stored set of results).

    For the 'text' default format, the output is implicitly 'stdout' unless otherwise specified.
    For all other formats, the output is to a file in either the current working directory, or
    the directory specified by the '--path' option, unless the special 'stdout' path is specified
    in which case output will go to stdout (useful for e.g. baseline 'tsv' format export piped to youplot).

    To allow writing to the package directory, you may need to pass the appropriate option to swift package:
    swift package --allow-writing-to-package-directory benchmark <command> <options>

    USAGE: swift package benchmark <command>

       swift package benchmark run <options>
       swift package benchmark list
       swift package benchmark baseline list
       swift package benchmark baseline [read|update|delete|compare] [baseline1 baseline2 ... baselineN] <options>
       swift package benchmark help

    ARGUMENTS:
    <command>               The benchmark command to perform, one of: ["run", "list", "baseline", "help"]. If not specified, 'run' is implied.

    OPTIONS:
    --filter <filter>       Benchmarks matching the regexp filter that should be run
    --skip <skip>           Benchmarks matching the regexp filter that should be skipped
    --target <target>       Benchmark targets matching the regexp filter that should be run
    --skip-target <skip-target>
                          Benchmark targets matching the regexp filter that should be skipped
    --format <format>       The output format to use, one of: ["text", "markdown", "influx", "percentiles", "tsv", "jmh"], default is 'text'
    --path <path>           The path where exported data is stored, default is the current directory (".").
    --quiet                 Specifies that output should be supressed (useful for if you just want to check return code)
    --scale                 Specifies that some of the text output should be scaled using the scalingFactor (denoted by '*' in output)
    --no-progress           Specifies that benchmark progress information should not be displayed
    --grouping <grouping>   The grouping to use, one of: ["metric", "benchmark"]. default is 'benchmark'
    -h, --help              Show help information.
    """
