//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

import XCTest
@testable import Benchmark
@testable import BenchmarkSupport

final class BenchmarkTests: XCTestCase {

    func testBenchmarkRun() throws {
        let benchmark = Benchmark("Minimal benchmark") { benchmark in
        }
        XCTAssertNotNil(benchmark)
        benchmark?.run()
    }

    func testBenchmarkRunAsync() throws {
        func asyncFunc() async {
        }
        let benchmark = Benchmark("Minimal async benchmark") { benchmark in
            await asyncFunc()
        }
        XCTAssertNotNil(benchmark)
        benchmark?.runAsync()
    }

    func testBenchmarkRunCustomMetric() throws {
        let benchmark = Benchmark("Minimal benchmark", metrics: [.custom("customMetric")]) { benchmark in
            for measurement in 1...100 {
                benchmark.measurement(.custom("customMetric"), measurement)
            }
        }
        XCTAssertNotNil(benchmark)
        benchmark?.run()
    }

    func testBenchmarkEqualityAndDifference() throws {
        let benchmark = Benchmark("Minimal benchmark") { benchmark in
        }
        let benchmark2 = Benchmark("Another minimal benchmark") { benchmark in
        }
        let benchmark3 = Benchmark("Minimal benchmark") { benchmark in
        }
        XCTAssert(benchmark != benchmark2)
        XCTAssert(benchmark == benchmark)
        XCTAssert(benchmark == benchmark3)
    }

    func testBenchmarkRunFailure() throws {
        let benchmark = Benchmark("Minimal benchmark", metrics: [.custom("customMetric")]) { benchmark in
            benchmark.error("Benchmark failed")
        }
        XCTAssertNotNil(benchmark)
        benchmark?.run()
        XCTAssertNotNil(benchmark?.failureReason)
        XCTAssert(benchmark?.failureReason == "Benchmark failed")
    }

    func testBenchmarkRunMoreParameters() throws {
        let benchmark = Benchmark("Minimal benchmark",
                                  metrics: BenchmarkMetric.all,
                                  timeUnits: .milliseconds,
                                  warmup: false,
                                  throughputScalingFactor: .mega) { benchmark in
            for i in benchmark.throughputIterations {
                blackHole(i)
            }
        }
        XCTAssertNotNil(benchmark)
        benchmark?.run()
    }

}
