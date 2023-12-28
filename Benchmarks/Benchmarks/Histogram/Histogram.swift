//
// Copyright (c) 2023 Ordo One AB
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0

import Benchmark
import Histogram

let benchmarks = {
    let metrics:[BenchmarkMetric] = [
        .wallClock,
        .throughput,
        .peakMemoryResident,
        .contextSwitches,
        .syscalls,
        .cpuTotal,
        .mallocCountTotal,
        .allocatedResidentMemory,
        .threads,
        .threadsRunning
    ]
    Benchmark.defaultConfiguration = .init(metrics: metrics,
                                           scalingFactor: .mega,
                                           maxDuration: .seconds(1),
                                           maxIterations: .kilo(1))
    Benchmark("Record") { benchmark in
        let maxValue: UInt64 = 1_000_000

        var histogram = Histogram<UInt64>(highestTrackableValue: maxValue, numberOfSignificantValueDigits: .three)

        let numValues = 1_024 // so compiler can optimize modulo below
        let values = [UInt64]((0 ..< numValues).map { _ in UInt64.random(in: 100 ... 1_000) })

        benchmark.startMeasurement()

        for i in benchmark.scaledIterations {
            blackHole(histogram.record(values[i % numValues]))
        }

        benchmark.stopMeasurement()
    }

    Benchmark("Record to autoresizing") { benchmark in
        benchmark.startMeasurement()
        var histogram = Histogram<UInt64>(numberOfSignificantValueDigits: .three)

        let numValues = 1_024 // so compiler can optimize modulo below
        let values = [UInt64]((0 ..< numValues).map { _ in UInt64.random(in: 100 ... 10_000) })

        for i in benchmark.scaledIterations {
            blackHole(histogram.record(values[i % numValues]))
        }

        benchmark.stopMeasurement()
    }

    Benchmark("ValueAtPercentile",
              configuration: .init(scalingFactor: .kilo)) { benchmark in
        let maxValue: UInt64 = 1_000_000

        var histogram = Histogram<UInt64>(highestTrackableValue: maxValue, numberOfSignificantValueDigits: .three)

        // fill histogram with some data
        for _ in 0 ..< 10_000 {
            blackHole(histogram.record(UInt64.random(in: 10 ... 1_000)))
        }

        let percentiles = [0.0, 25.0, 50.0, 75.0, 80.0, 90.0, 99.0, 100.0]

        benchmark.startMeasurement()

        for i in benchmark.scaledIterations {
            blackHole(histogram.valueAtPercentile(percentiles[i % percentiles.count]))
        }

        benchmark.stopMeasurement()
    }

    Benchmark("Mean",
              configuration: .init(scalingFactor: .kilo)) { benchmark in
        let maxValue: UInt64 = 1_000_000

        var histogram = Histogram<UInt64>(highestTrackableValue: maxValue, numberOfSignificantValueDigits: .three)

        // fill histogram with some data
        for _ in 0 ..< 10_000 {
            blackHole(histogram.record(UInt64.random(in: 10 ... 1_000)))
        }

        benchmark.startMeasurement()

        for _ in benchmark.scaledIterations {
            blackHole(histogram.mean)
        }

        benchmark.stopMeasurement()
    }
}
