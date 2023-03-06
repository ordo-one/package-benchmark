# Running Benchmarks

Use the SwiftPM package plugin `benchmark` to run your benchmarks

## Overview

The most straightforward way to just run all benchmarks is simply:

```
swift package benchmark
```

To perform additional operations a command verb and/or additional options can be specified:

```
swift package benchmark <command verb> [<options>]
```

### Command verbs

- term `run`: run the benchmarks - default action if none specified
- term `list`: list available benchmarks that can be run per benchmark target
- term `baseline list`: Lists the available baselines stored per benchmark target
- term `baseline read|update|delete|compare`: perform the specified subaction on one or more specified benchmark baselines
- term `help`: Display usage help to the terminal

### Options 

- term `--filter <filter>`: Benchmarks matching the regexp filter that should be run
- term `--skip <skip>`: Benchmarks matching the regexp filter that should be skipped
- term `--target <target>`: Benchmark targets matching the regexp filter that should be run
- term `--skip-target <skip-target>`: Benchmark targets matching the regexp filter that should be skipped
- term `--format <format>`: The output format to use, one of: ["text", "markdown", "influx", "percentiles", "tsv", "jmh"], default is 'text'
- term `--path <path>`: The path where exported data is stored, default is the current directory ("."). 
- term `--quiet`: Specifies that output should be supressed (useful for if you just want to check return code)
- term `--scale`: Specifies that some of the text output should be scaled using the scalingFactor (denoted by '*' in output)
- term `--no-progress`: Specifies that benchmark progress information should not be displayed
- term `--grouping <grouping>`: The grouping to use, one of: ["metric", "benchmark"]. default is 'benchmark'

## Usage

`swift package benchmark help` provides usage notes

```
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
```

## Network or disk permissions failures

We've seen one instance of strange permissioning failures for disk writes for tests that use LMDB (where only the lock file can be created, but the actual data file fails - even when specifying `--allow-writing-to-package-directory`).

To workaround such issues if needed, disable running in the sandbox with:

```
swift package --disable-sandbox benchmark
```

This is also required for e.g. benchmarks that uses the network.

## Sample usage

### Run all benchmark targets:
```
swift package benchmark
```

### Run all benchmark targets, but display by metric instead of by test:
```
swift package benchmark --grouping metric
```
### Run targets / benchmarks with regex matching
```
swift package benchmark --target ".*Time" --filter ".*k\." --skip ".*UTC.*" --skip-target ".*Time"
```

### List available benchmark targets:
```
swift package benchmark list
```

### Run specific benchmark target:
```
swift package benchmark run --target Frostflake
```

### Compare with the current baseline:
```
swift package benchmark baseline compare baseline1
```

### Compare two named baselines
```
swift package benchmark baseline compare alpha beta
```

### Compare two named baselines suppressing table output
```
swift package benchmark baseline compare alpha beta --quiet
```

### Update benchmark baseline for all targets:
```
swift package --allow-writing-to-package-directory benchmark baseline update
```

### Update benchmark named baseline for all targets:
```
swift package --allow-writing-to-package-directory benchmark baseline update alpha
```

### Update benchmark baseline for a specific target:
```
swift package --allow-writing-to-package-directory benchmark baseline update --target Frostflake-Benchmark
```

### Export benchmark data:
```
swift package --allow-writing-to-package-directory benchmark --format jmh 
```

### Export benchmark data:
```
swift package --allow-writing-to-package-directory benchmark --format jmh --path xyz
```
