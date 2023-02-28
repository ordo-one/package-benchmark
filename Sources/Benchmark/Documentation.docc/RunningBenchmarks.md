# Running Benchmarks

Use the SwiftPM package plugin `benchmark` to run your benchmarks

## Overview

The simplest way to run all benchmarks is simply to run:

```
swift package benchmark
```

### Command verbs for `swift package benchmark`

- term `list`: list available targets per benchmark target
- term `run`: run the benchmarks - default action if none specified
- term `compare`: compare a benchmark run with a specified baseline, or compare two different baselines if two are specified
- term `update-baseline`: update either the default unnamed baseline, or a named specific baseline
- term `baseline`: display the contents of either the default unnamed baseline, or a named specific baseline
- term `export`: export data into the specified format, currently only [influx](https://docs.influxdata.com/influxdb/cloud/write-data/developer-tools/csv) output format is implemented for exporting

### Options 

- term `--target`: specify which target we should run the benchmark plugin for (regex), multiple may be specified, default all targets
- term `--skip-target`: specify that a given target should be skipped matching regex, multiple can be specified
- term `--grouping`: `metric` or `test` - specifies how results should be grouped in tables, default `test`
- term `--format`: `text` or `markdown` - specifes textual output format (markdown useful for e.g. GitHub CI), default `text`
- term `--quiet`: suppress output (e.g. tables)
- term `--filter`: Include benchmarks matching regex, multiple can be provided
- term `--skip`: Skip benchmarks matching regex, multiple can be provided

### Disk write permissions failures

We've seen one instance of strange permissioning failures for disk writes for tests that use LMDB (where only the lock file can be created, but the actual data file fails - even when specifying `--allow-writing-to-package-directory`).

To workaround such issues if needed, disable running in the sandbox with:

```
swift package --disable-sandbox benchmark
```

### Running Benchmarks

**Run all benchmark targets:**

```
swift package benchmark
```

**Run all benchmark targets, but display by metric instead of by test:**

```
swift package benchmark --grouping metric
```

**Run targets / benchmarks with regex matching:**

```
swift package benchmark --target ".*Time" --filter ".*k\." --skip ".*UTC.*" --skip-target ".*Time"
```

**List available benchmark targets:**

```
swift package benchmark list
```

**Run specific benchmark target:**

```
swift package benchmark run --target Frostflake-Benchmark
```

### Comparing Benchmarks

**Compare all benchmark targets with current baseline**

```
swift package benchmark compare
```

**Compare all benchmark targets with specific baseline**

```
swift package benchmark compare alpha
```

**Compare two named baselines**

```
swift package benchmark compare alpha beta
```

**Compare two named baselines suppressing table output**

```
swift package benchmark compare alpha beta --quiet
```

**Compare named baseline with the default**

```
swift package benchmark compare alpha default
```

**Compare specific benchmark target with current baseline**

```
swift package benchmark compare --target Frostflake-Benchmark
```

### Updating Benchmarks

**Update benchmark baseline for all targets**

```
swift package --allow-writing-to-package-directory benchmark update-baseline
```

**Update benchmark named baseline for all targets**

```
swift package --allow-writing-to-package-directory benchmark update-baseline alpha
```

**Update benchmark baseline for a specific target**

```
swift package --allow-writing-to-package-directory benchmark update-baseline --target Frostflake-Benchmark
```

### Exporting Benchmarks

**Export benchmark data**

```
swift package --allow-writing-to-package-directory benchmark export <export_format>
```
