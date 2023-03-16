//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//
import Histogram
import BenchmarkSupport

@main
struct DateTimeBenchmark: BenchmarkRunnerReal {
    static func registerBenchmarks() {
        Benchmark.defaultConfiguration = .init(scalingFactor: .mega,
                                               maxDuration: .seconds(1),
                                               maxIterations: .kilo(1))

        Benchmark("Record",
                  configuration: .init(metrics: [.wallClock, .throughput] + BenchmarkMetric.memory)) { benchmark in
            let maxValue: UInt64 = 1_000_000

            var histogram = Histogram<UInt64>(highestTrackableValue: maxValue, numberOfSignificantValueDigits: .three)

            let numValues = 1_024 // so compiler can optimize modulo below
            let values = [UInt64]((0 ..< numValues).map { _ in UInt64.random(in: 100 ... 1_000) })

            benchmark.startMeasurement()

            for i in benchmark.scaledIterations {
                blackHole(histogram.record(values[i % numValues]))
            }
        }

        Benchmark("Record to autoresizing",
                  configuration: .init(metrics: [.wallClock, .throughput] + BenchmarkMetric.memory)) { benchmark in
            var histogram = Histogram<UInt64>(numberOfSignificantValueDigits: .three)

            let numValues = 1_024 // so compiler can optimize modulo below
            let values = [UInt64]((0 ..< numValues).map { _ in UInt64.random(in: 100 ... 10_000) })

            benchmark.startMeasurement()

            for i in benchmark.scaledIterations {
                blackHole(histogram.record(values[i % numValues]))
            }
        }

        Benchmark("ValueAtPercentile",
                  configuration: .init(metrics: [.wallClock, .throughput] + BenchmarkMetric.memory,
                                       scalingFactor: .kilo)) { benchmark in
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
        }

        Benchmark("Mean",
                  configuration: .init(metrics: BenchmarkMetric.all, scalingFactor: .kilo)) { benchmark in
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
        }
    }
}
