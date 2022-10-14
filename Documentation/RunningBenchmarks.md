#  Running benchmarks

The simplest way to run all benchmarks is simply to run:

```
swift package benchmark
```

## Command verbs for `swift package benchmark`

* `list` - list available targets per benchmark target
* `run` - run the benchmarks - default action if none specified
* `compare` - compare a benchmark run with a specified baseline, or compare two different baselines if two are specified
* `update-baseline` - update either the default unnamed baseline, or a named specific baseline
* `baseline` - display the contents of either the default unnamed baseline, or a named specific baseline

## Options 

* `--target` - specify which target we should run the benchmark plugin for, multiple may be specified, default all targets
* `--skip` - specify that a given target should be skipped
* `--grouping` - `metric` or `test` - specifies how results should be grouped in tables, default `test`
* `--format` - `text` or `markdown` - specifes textual output format (markdown useful for e.g. GitHub CI), default `text`
* `--quiet` - suppress output (e.g. tables)

## Disk write permissions failures
We've seen one instance of strange permissioning failures for disk writes for tests that use LMDB (where only the lock file can be created, but the actual data file fails - even when specifying `--allow-writing-to-package-directory`).

To workaround such issues if needed, disable running in the sandbox with:

```
swift package --disable-sandbox benchmark
```

## Sample usage

### Run all benchmark targets:
```
swift package benchmark
```

### Run all benchmark targets, but display by metric instead of by test:
```
swift package benchmark --grouping metric
```

### List available benchmark targets:
```
swift package benchmark list
```

### Run specific benchmark target:
```
swift package benchmark run --target Frostflake-Benchmark
```

### Compare all benchmark targets with current baseline:
```
swift package benchmark compare
```

### Compare all benchmark targets with specific baseline:
```
swift package benchmark compare alpha
```

### Compare two named baselines
```
swift package benchmark compare alpha beta
```

### Compare two named baselines suppressing table output
```
swift package benchmark compare alpha beta --quiet
```

### Compare named baseline with the default
```
swift package benchmark compare alpha default
```

### Compare specific benchmark target with current baseline:
```
swift package benchmark compare --target Frostflake-Benchmark
```

### Update benchmark baseline for all targets:
```
swift package --allow-writing-to-package-directory benchmark update-baseline
```

### Update benchmark named baseline for all targets:
```
swift package --allow-writing-to-package-directory benchmark update-baseline alpha
```

### Update benchmark baseline for a specific target:
```
swift package --allow-writing-to-package-directory benchmark update-baseline --target Frostflake-Benchmark
```
