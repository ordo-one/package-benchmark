# ``Benchmark``

Benchmark is a harness for easily creating Swift performance benchmarks for both macOS and Linux.

## Overview

More detail about Benchmark, why it's relevant, and intro to what's included.
On more than one line, generally.

Benchmark is suitable for both ad-hoc smaller benchmarks primarily caring about runtime (in the spirit of [Google's swift-benchmark](https://github.com/google/swift-benchmark)) and more extensive benchmarks that care about additional metrics such as memory allocations, syscalls, thread usage and more.

Benchmark supports both local usage and enforced performance evaluation for continuous integration.
Local usage includes baseline comparisons for an iterative workflow for the individual developer.
The continuous integration support for Benchmark is the primary intended use case for the package.
CI support has good support for integration with GitHub CI, and includes sample workflows for automated comparisons between a `main` branch and the branch of a pull request to allow CI to enforce performance validation with customizable thresholds.

Benchmark measurements are provided as percentiles to support analysis of the actual distribution of benchmark measurements.
An individual benchmark is typically run for a minimum amount of time and/or a given number of iterations.
The default percentiles presented are:

| `p0` | `p25` | `p50` | `p75` | `p90` | `p99` | `p100` |
| ---- | ----- | ----- | ----- | ----- | ----- | ------ |
| (min)|       | (median) |    |       |       | (max) |

You can also configure your own sets of percentiles within Benchmark configurations.
For more details on configuring benchmarks, see [LINK TBD].

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:WritingBenchmarks>
- <doc:Metrics>
- <doc:RunningBenchmarks>
- <doc:Workflows>

### All The Things

- ``Benchmark/Benchmark``
- ``Benchmark/Benchmark/!=(_:_:)``
- ``Benchmark/Benchmark/==(_:_:)``
- ``Benchmark/Benchmark/BenchmarkAsyncClosure``
- ``Benchmark/Benchmark/BenchmarkClosure``
- ``Benchmark/Benchmark/BenchmarkCustomMetricMeasurement``
- ``Benchmark/Benchmark/BenchmarkMeasurementSynchronization``
- ``Benchmark/Benchmark/Configuration-swift.struct``
- ``Benchmark/Benchmark/Configuration-swift.struct/desiredDuration``
- ``Benchmark/Benchmark/Configuration-swift.struct/desiredIterations``
- ``Benchmark/Benchmark/Configuration-swift.struct/init(from:)``
- ``Benchmark/Benchmark/Configuration-swift.struct/init(metrics:timeUnits:warmupIterations:throughputScalingFactor:desiredDuration:desiredIterations:skip:thresholds:)``
- ``Benchmark/Benchmark/Configuration-swift.struct/metrics``
- ``Benchmark/Benchmark/Configuration-swift.struct/skip``
- ``Benchmark/Benchmark/Configuration-swift.struct/thresholds``
- ``Benchmark/Benchmark/Configuration-swift.struct/throughputScalingFactor``
- ``Benchmark/Benchmark/Configuration-swift.struct/timeUnits``
- ``Benchmark/Benchmark/Configuration-swift.struct/warmupIterations``

- ``Benchmark/Benchmark/benchmarks``
- ``Benchmark/Benchmark/configuration-swift.property``
- ``Benchmark/Benchmark/currentIteration``
- ``Benchmark/Benchmark/customMetricMeasurement``
- ``Benchmark/Benchmark/defaultConfiguration``
- ``Benchmark/Benchmark/error(_:)``
- ``Benchmark/Benchmark/failureReason``
- ``Benchmark/Benchmark/hash(into:)``
- ``Benchmark/Benchmark/init(_:configuration:closure:)-5ra7m``
- ``Benchmark/Benchmark/init(_:configuration:closure:)-699lk``
- ``Benchmark/Benchmark/init(from:)``
- ``Benchmark/Benchmark/measurement(_:_:)``
- ``Benchmark/Benchmark/measurementPostSynchronization``
- ``Benchmark/Benchmark/measurementPreSynchronization``
- ``Benchmark/Benchmark/name``
- ``Benchmark/Benchmark/run()``
- ``Benchmark/Benchmark/startMeasurement()``
- ``Benchmark/Benchmark/stopMeasurement()``
- ``Benchmark/Benchmark/throughputIterations``
- ``Benchmark/BenchmarkCommandReply``
- ``Benchmark/BenchmarkCommandReply/end``
- ``Benchmark/BenchmarkCommandReply/error(_:)``
- ``Benchmark/BenchmarkCommandReply/init(from:)``
- ``Benchmark/BenchmarkCommandReply/list(benchmark:)``
- ``Benchmark/BenchmarkCommandReply/ready``
- ``Benchmark/BenchmarkCommandReply/result(benchmark:results:)``
- ``Benchmark/BenchmarkCommandReply/run``
- ``Benchmark/BenchmarkCommandRequest``
- ``Benchmark/BenchmarkCommandRequest/end``
- ``Benchmark/BenchmarkCommandRequest/init(from:)``
- ``Benchmark/BenchmarkCommandRequest/list``
- ``Benchmark/BenchmarkCommandRequest/run(benchmark:)``
- ``Benchmark/BenchmarkMetric``
- ``Benchmark/BenchmarkMetric/!=(_:_:)``

- ``Benchmark/BenchmarkMetric/Polarity``
- ``Benchmark/BenchmarkMetric/Polarity/!=(_:_:)``
- ``Benchmark/BenchmarkMetric/Polarity/init(from:)``
- ``Benchmark/BenchmarkMetric/Polarity/prefersLarger``
- ``Benchmark/BenchmarkMetric/Polarity/prefersSmaller``
- ``Benchmark/BenchmarkMetric/all``
- ``Benchmark/BenchmarkMetric/allocatedResidentMemory``
- ``Benchmark/BenchmarkMetric/contextSwitches``
- ``Benchmark/BenchmarkMetric/countable()``
- ``Benchmark/BenchmarkMetric/cpuSystem``
- ``Benchmark/BenchmarkMetric/cpuTotal``
- ``Benchmark/BenchmarkMetric/cpuUser``
- ``Benchmark/BenchmarkMetric/custom(_:polarity:)``
- ``Benchmark/BenchmarkMetric/default``
- ``Benchmark/BenchmarkMetric/delta``
- ``Benchmark/BenchmarkMetric/deltaPercentage``
- ``Benchmark/BenchmarkMetric/description``
- ``Benchmark/BenchmarkMetric/disk``
- ``Benchmark/BenchmarkMetric/extended``
- ``Benchmark/BenchmarkMetric/init(from:)``
- ``Benchmark/BenchmarkMetric/mallocCountLarge``
- ``Benchmark/BenchmarkMetric/mallocCountSmall``
- ``Benchmark/BenchmarkMetric/mallocCountTotal``
- ``Benchmark/BenchmarkMetric/memory``
- ``Benchmark/BenchmarkMetric/memoryLeaked``
- ``Benchmark/BenchmarkMetric/peakMemoryResident``
- ``Benchmark/BenchmarkMetric/peakMemoryVirtual``
- ``Benchmark/BenchmarkMetric/polarity()``
- ``Benchmark/BenchmarkMetric/readBytesLogical``
- ``Benchmark/BenchmarkMetric/readBytesPhysical``
- ``Benchmark/BenchmarkMetric/readSyscalls``
- ``Benchmark/BenchmarkMetric/syscalls``
- ``Benchmark/BenchmarkMetric/system``
- ``Benchmark/BenchmarkMetric/threads``
- ``Benchmark/BenchmarkMetric/threadsRunning``
- ``Benchmark/BenchmarkMetric/throughput``
- ``Benchmark/BenchmarkMetric/wallClock``
- ``Benchmark/BenchmarkMetric/writeBytesLogical``
- ``Benchmark/BenchmarkMetric/writeBytesPhysical``
- ``Benchmark/BenchmarkMetric/writeSyscalls``
- ``Benchmark/BenchmarkResult``
- ``Benchmark/BenchmarkResult/!=(_:_:)``
- ``Benchmark/BenchmarkResult/...(_:)-145l1``
- ``Benchmark/BenchmarkResult/...(_:)-9qsct``
- ``Benchmark/BenchmarkResult/...(_:_:)``
- ``Benchmark/BenchmarkResult/.._(_:)``
- ``Benchmark/BenchmarkResult/.._(_:_:)``
- ``Benchmark/BenchmarkResult/==(_:_:)``
- ``Benchmark/BenchmarkResult/Percentile``
- ``Benchmark/BenchmarkResult/Percentile/!=(_:_:)``
- ``Benchmark/BenchmarkResult/Percentile/init(from:)``
- ``Benchmark/BenchmarkResult/Percentile/p0``
- ``Benchmark/BenchmarkResult/Percentile/p100``
- ``Benchmark/BenchmarkResult/Percentile/p25``
- ``Benchmark/BenchmarkResult/Percentile/p50``
- ``Benchmark/BenchmarkResult/Percentile/p75``
- ``Benchmark/BenchmarkResult/Percentile/p90``
- ``Benchmark/BenchmarkResult/Percentile/p99``
- ``Benchmark/BenchmarkResult/PercentileAbsoluteThreshold``
- ``Benchmark/BenchmarkResult/PercentileAbsoluteThresholds``
- ``Benchmark/BenchmarkResult/PercentileRelativeThreshold``
- ``Benchmark/BenchmarkResult/PercentileRelativeThresholds``
- ``Benchmark/BenchmarkResult/PercentileThresholds``
- ``Benchmark/BenchmarkResult/PercentileThresholds/default``
- ``Benchmark/BenchmarkResult/PercentileThresholds/init(from:)``
- ``Benchmark/BenchmarkResult/PercentileThresholds/init(relative:absolute:)``
- ``Benchmark/BenchmarkResult/PercentileThresholds/none``
- ``Benchmark/BenchmarkResult/PercentileThresholds/relaxed``
- ``Benchmark/BenchmarkResult/PercentileThresholds/strict``
- ``Benchmark/BenchmarkResult/_(_:_:)-4nblm``
- ``Benchmark/BenchmarkResult/_(_:_:)-8mh6r``
- ``Benchmark/BenchmarkResult/_=(_:_:)-1se69``
- ``Benchmark/BenchmarkResult/_=(_:_:)-6q54v``
- ``Benchmark/BenchmarkResult/betterResultsOrEqual(than:thresholds:printOutput:)``
- ``Benchmark/BenchmarkResult/init(from:)``
- ``Benchmark/BenchmarkResult/init(metric:timeUnits:measurements:warmupIterations:thresholds:percentiles:)``
- ``Benchmark/BenchmarkResult/measurements``
- ``Benchmark/BenchmarkResult/metric``
- ``Benchmark/BenchmarkResult/percentiles``
- ``Benchmark/BenchmarkResult/scaleResults(to:)``
- ``Benchmark/BenchmarkResult/thresholds``
- ``Benchmark/BenchmarkResult/timeUnits``
- ``Benchmark/BenchmarkResult/unitDescription``
- ``Benchmark/BenchmarkResult/unitDescriptionPretty``
- ``Benchmark/BenchmarkResult/warmupIterations``
- ``Benchmark/BenchmarkTimeUnits``
- ``Benchmark/BenchmarkTimeUnits/!=(_:_:)``
- ``Benchmark/BenchmarkTimeUnits/automatic``
- ``Benchmark/BenchmarkTimeUnits/description``
- ``Benchmark/BenchmarkTimeUnits/encode(to:)``
- ``Benchmark/BenchmarkTimeUnits/hash(into:)``
- ``Benchmark/BenchmarkTimeUnits/hashValue``
- ``Benchmark/BenchmarkTimeUnits/init(_:)``
- ``Benchmark/BenchmarkTimeUnits/init(from:)``
- ``Benchmark/BenchmarkTimeUnits/init(rawValue:)``
- ``Benchmark/BenchmarkTimeUnits/microseconds``
- ``Benchmark/BenchmarkTimeUnits/milliseconds``
- ``Benchmark/BenchmarkTimeUnits/nanoseconds``
- ``Benchmark/BenchmarkTimeUnits/seconds``
- ``Benchmark/blackHole(_:)``
- ``Benchmark/registerBenchmarks()``
