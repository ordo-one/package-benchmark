//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

@testable import Benchmark
@testable import BenchmarkSupport
import XCTest

final class BenchmarkTests: XCTestCase {
    func testBenchmarkRun() throws {
        let benchmark = Benchmark("testBenchmarkRun benchmark") { _ in
        }
        XCTAssertNotNil(benchmark)
        benchmark?.run()
    }

    func testBenchmarkRunAsync() throws {
        func asyncFunc() async {}
        let benchmark = Benchmark("testBenchmarkRunAsync benchmark") { _ in
            await asyncFunc()
        }
        XCTAssertNotNil(benchmark)
        benchmark?.runAsync()
    }

    func testBenchmarkRunCustomMetric() throws {
        let benchmark = Benchmark("testBenchmarkRunCustomMetric benchmark",
                                  metrics: [.custom("customMetric")]) { benchmark in
            for measurement in 1 ... 100 {
                benchmark.measurement(.custom("customMetric"), measurement)
            }
        }
        XCTAssertNotNil(benchmark)
        benchmark?.run()
    }

    func testBenchmarkEqualityAndDifference() throws {
        let benchmark = Benchmark("testBenchmarkEqualityAndDifference benchmark") { _ in
        }
        let benchmark2 = Benchmark("testBenchmarkEqualityAndDifference benchmark 2") { _ in
        }
        XCTAssert(benchmark != benchmark2)
    }

    func testBenchmarkRunFailure() throws {
        let benchmark = Benchmark("testBenchmarkRunFailure benchmark",
                                  metrics: [.custom("customMetric")]) { benchmark in
            benchmark.error("Benchmark failed")
        }
        XCTAssertNotNil(benchmark)
        benchmark?.run()
        XCTAssertNotNil(benchmark?.failureReason)
        XCTAssert(benchmark?.failureReason == "Benchmark failed")
    }

    func testBenchmarkRunMoreParameters() throws {
        let benchmark = Benchmark("testBenchmarkRunMoreParameters benchmark",
                                  metrics: BenchmarkMetric.all,
                                  timeUnits: .milliseconds,
                                  warmupIterations: 0,
                                  throughputScalingFactor: .mega) { benchmark in
            for outerloop in benchmark.throughputIterations {
                blackHole(outerloop)
            }
        }
        XCTAssertNotNil(benchmark)
        benchmark?.run()
    }
}
