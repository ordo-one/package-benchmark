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

@main
struct MyBenchmark: BenchmarkRunnerReal {
    static func registerBenchmarks() {
        Benchmark.defaultConfiguration = .init(warmupIterations: 0,
                                               maxDuration: .seconds(1),
                                               maxIterations: Int.max,
                                               thresholds: [.wallClock: BenchmarkResult.PercentileThresholds.strict])

        //    Benchmark.startupHook = { print("Startup hook") }
        //    Benchmark.shutdownHook = { print("Shutdown hook") }
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
    }
}
