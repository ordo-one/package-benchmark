//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//
import BenchmarkSupport
import Histogram

@main
extension BenchmarkRunner {}

// swiftlint disable: attributes
@_dynamicReplacement(for: registerBenchmarks)
func benchmarks() {
    Benchmark.defaultDesiredDuration = .seconds(2)
    Benchmark.defaultDesiredIterations = .kilo(1)
    Benchmark.defaultThroughputScalingFactor = .mega

    Benchmark("Record",
              metrics: [.wallClock, .throughput] + BenchmarkMetric.memory,
              skip: false) { benchmark in
        let maxValue: UInt64 = 1_000_000

        var histogram = Histogram<UInt64>(highestTrackableValue: maxValue, numberOfSignificantValueDigits: .three)

        let numValues = 1_024 // so compiler can optimize modulo below
        let values = [UInt64]((0 ..< numValues).map { _ in UInt64.random(in: 100 ... 1_000) })

        benchmark.startMeasurement()

        for i in benchmark.throughputIterations {
            blackHole(histogram.record(values[i % numValues]))
        }
    }

    Benchmark("Record to autoresizing",
              metrics: [.wallClock, .throughput] + BenchmarkMetric.memory,
              skip: false) { benchmark in
        var histogram = Histogram<UInt64>(numberOfSignificantValueDigits: .three)

        let numValues = 1_024 // so compiler can optimize modulo below
        let values = [UInt64]((0 ..< numValues).map { _ in UInt64.random(in: 100 ... 10_000) })

        benchmark.startMeasurement()

        for i in benchmark.throughputIterations {
            blackHole(histogram.record(values[i % numValues]))
        }
    }

    Benchmark("ValueAtPercentile",
              metrics: [.wallClock, .throughput],
              throughputScalingFactor: .kilo,
              skip: false) { benchmark in
        let maxValue: UInt64 = 1_000_000

        var histogram = Histogram<UInt64>(highestTrackableValue: maxValue, numberOfSignificantValueDigits: .three)

        // fill histogram with some data
        for _ in 0 ..< 10_000 {
            blackHole(histogram.record(UInt64.random(in: 10 ... 1_000)))
        }

        let percentiles = [0.0, 25.0, 50.0, 75.0, 80.0, 90.0, 99.0, 100.0]

        benchmark.startMeasurement()

        for i in benchmark.throughputIterations {
            blackHole(histogram.valueAtPercentile(percentiles[i % percentiles.count]))
        }
    }

    Benchmark("Mean",
              metrics: [.wallClock, .throughput],
              throughputScalingFactor: .kilo,
              skip: false) { benchmark in
        let maxValue: UInt64 = 1_000_000

        var histogram = Histogram<UInt64>(highestTrackableValue: maxValue, numberOfSignificantValueDigits: .three)

        // fill histogram with some data
        for _ in 0 ..< 10_000 {
            blackHole(histogram.record(UInt64.random(in: 10 ... 1_000)))
        }

        benchmark.startMeasurement()

        for _ in benchmark.throughputIterations {
            blackHole(histogram.mean)
        }
    }
}
