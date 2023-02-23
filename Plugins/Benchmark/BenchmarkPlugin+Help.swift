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
USAGE: benchmark <command> --format <format> --path <path> [--update ...] [--delete ...] [--quiet ...] --baseline <baseline> ... [--baseline-name-second <baseline-name-second>] --grouping <grouping> [--filter <filter> ...] [--skip <skip> ...]

ARGUMENTS:
  <command>               The benchmark command to perform, one of: ["run", "list", "baseline"]. 'baseline' can be followed by 0 or more named baselines (if 0, the baseline name 'default' is used)

OPTIONS:
  --format <format>       The output format to use, one of: ["text", "markdown", "influx", "percentiles", "tsv", "jmh"]
  --path <path>           The path where exported data is stored, default is current directory.
  --update                Specifies that the baseline should be update with the data from the current run
  --delete                Specifies that the baseline should be deleted
  --quiet                 True if we should supress output
  --baseline <baseline>   The named baseline we should update or compare with
  --baseline-name-second <baseline-name-second>
                          The second named baseline we should update or compare with for A/B
  --grouping <grouping>   The grouping to use, 'metric' or 'test'
  --filter <filter>       Benchmarks matching the regexp filter that should be run
  --skip <skip>           Benchmarks matching the regexp filter that should be skipped
  -h, --help              Show help information.
"""
