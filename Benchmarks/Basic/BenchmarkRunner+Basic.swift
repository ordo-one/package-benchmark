//
// Copyright (c) 2023 Ordo One AB
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0

import Benchmark

// quiet swiftlint for now
extension BenchmarkRunner {}

let benchmarks = {
    var thresholds: [BenchmarkMetric: BenchmarkThresholds]

    if Benchmark.checkAbsoluteThresholds {
        let absolute: BenchmarkThresholds.AbsoluteThresholds = [.p0: .microseconds(1),
                                                                .p25: .microseconds(1),
                                                                .p50: .microseconds(2_500),
                                                                .p75: .microseconds(1),
                                                                .p90: .microseconds(2),
                                                                .p99: .milliseconds(3),
                                                                .p100: .milliseconds(1)]

        thresholds = [BenchmarkMetric.wallClock: BenchmarkThresholds(absolute: absolute)]
    } else {
        thresholds = [BenchmarkMetric.wallClock: BenchmarkThresholds.relaxed]
    }

    Benchmark.defaultConfiguration = .init(warmupIterations: 0,
                                           maxDuration: .milliseconds(10), // .seconds(1),
                                           maxIterations: Int.max,
                                           thresholds: thresholds)

    // Benchmark.startupHook = { print("Startup hook") }
    // Benchmark.shutdownHook = { print("Shutdown hook") }
    // A way to define custom metrics fairly compact
    enum CustomMetrics {
        static var one: BenchmarkMetric { .custom("CustomMetricOne") }
        static var two: BenchmarkMetric { .custom("CustomMetricTwo", polarity: .prefersLarger, useScalingFactor: true) }
    }

    Benchmark("Basic",
              configuration: .init(metrics: [.wallClock, .throughput])) { _ in
    }

    Benchmark("Scaled metrics",
              configuration: .init(metrics: BenchmarkMetric.all + [CustomMetrics.two, CustomMetrics.one],
                                   scalingFactor: .kilo)) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(Int.random(in: benchmark.scaledIterations))
        }
        benchmark.measurement(CustomMetrics.two, Int.random(in: 1 ... 1_000_000))
        benchmark.measurement(CustomMetrics.one, Int.random(in: 1 ... 1_000))
    }

    Benchmark("All metrics",
              configuration: .init(metrics: BenchmarkMetric.all, skip: true)) { _ in
    }

    let stats = Statistics(numberOfSignificantDigits: .four)
    let measurementCount = 8_340

    for measurement in (0 ..< measurementCount).reversed() {
        stats.add(measurement)
    }

    Benchmark("Statistics",
              configuration: .init(metrics: BenchmarkMetric.arc + [.wallClock],
                                   scalingFactor: .kilo, maxDuration: .seconds(1))) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(stats.percentiles())
        }
    }
}
