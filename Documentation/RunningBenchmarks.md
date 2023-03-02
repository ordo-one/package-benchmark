#  Running benchmarks

The simplest way to run all benchmarks is simply to run:

```
swift package benchmark
```

## Usage

`swift package benchmark help` provides usage notes for the plugin:

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

## Command verbs for `swift package benchmark`

* `list` - list available benchmarks per target
* `run` - run the benchmarks - default action if none specified
* `baseline` - Operates on baselines - a stored set of benchmark results
** `list` - display all stored baselines
** `read` - read the named baselines
** `update` - update a specific baseline from a new benchmark run
** `delete` - delete the named baseline
** `compare` - compare two baselines (if a single baseline is specified, it will be compared with the default baseline)

## Options 

* `--filter <filter>`       Benchmarks matching the regexp filter that should be run
* `--skip <skip>`           Benchmarks matching the regexp filter that should be skipped
* `--target <target>`       Benchmark targets matching the regexp filter that should be run
* `--skip-target <skip-target>` Benchmark targets matching the regexp filter that should be skipped
* `--format <format>`       The output format to use, one of: ["text", "markdown", "influx", "percentiles", "tsv", "jmh"], default is 'text'
* `--path <path>`           The path where exported data is stored, default is the current directory ("."). 
* `--quiet`                 Specifies that output should be supressed (useful for if you just want to check return code)
* `--scale`                 Specifies that some of the text output should be scaled using the scalingFactor (denoted by '*' in output)
* `--no-progress`           Specifies that benchmark progress information should not be displayed
* `--grouping <grouping>`   The grouping to use, one of: ["metric", "benchmark"]. default is 'benchmark'

Export file output one or more files in the filesystem depending on the format:
* Text for output to terminal
* Markdown for output to e.g. GitHub workflow actions
* [Influx](https://docs.influxdata.com/influxdb/cloud/write-data/developer-tools/csv) output format for time series
* Percentiles for [HDR Histogram](http://hdrhistogram.github.io/HdrHistogram/plotFiles.html) analytics
* JMH for analytics with http://jmh.morethan.io


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
