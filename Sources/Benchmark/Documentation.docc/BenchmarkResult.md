# ``Benchmark/BenchmarkResult``

## Topics

### Creating Benchmark Results

- ``Benchmark/BenchmarkResult/init(metric:timeUnits:measurements:warmupIterations:thresholds:percentiles:)``
- ``Benchmark/BenchmarkResult/PercentileThresholds``

### Decoding Benchmark Results

- ``Benchmark/BenchmarkResult/init(from:)``

### Inspecting Benchmark Results

- ``Benchmark/BenchmarkResult/measurements``
- ``Benchmark/BenchmarkResult/metric``
- ``Benchmark/BenchmarkResult/unitDescription``
- ``Benchmark/BenchmarkResult/unitDescriptionPretty``
- ``Benchmark/BenchmarkResult/timeUnits``
- ``Benchmark/BenchmarkResult/percentiles``
- ``Benchmark/BenchmarkResult/Percentile``
- ``Benchmark/BenchmarkResult/thresholds``
- ``Benchmark/BenchmarkResult/warmupIterations``

### Calculating Thresholds of Results

- ``Benchmark/BenchmarkResult/betterResultsOrEqual(than:thresholds:printOutput:)``

### Scaling Results

- ``Benchmark/BenchmarkResult/scaleResults(to:)``

### Supporting Types

- ``Benchmark/BenchmarkResult/PercentileAbsoluteThreshold``
- ``Benchmark/BenchmarkResult/PercentileAbsoluteThresholds``
- ``Benchmark/BenchmarkResult/PercentileRelativeThreshold``
- ``Benchmark/BenchmarkResult/PercentileRelativeThresholds``

