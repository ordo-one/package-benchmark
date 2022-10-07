//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
///

@testable import Benchmark
@testable import BenchmarkSupport
import XCTest

// @main extension BenchmarkRunner {}      // Required for main() definition to not get linker errors

@_dynamicReplacement(for: registerBenchmarks) // Register benchmarks
func benchmarks() {
    Benchmark("Minimal benchmark", metrics: BenchmarkMetric.all, desiredIterations: 1) { _ in
    }
    Benchmark("Minimal benchmark 2", warmupIterations: 0, desiredIterations: 2) { _ in
    }
    Benchmark("Minimal benchmark 3", timeUnits: .seconds, desiredIterations: 3) { _ in
    }
}

final class BenchmarkRunnerTests: XCTestCase, BenchmarkRunnerReadWrite {
    private var readMessage: Int = 0
    private var writeCount: Int = 0

    // swiftlint:disable test_case_accessibility
    internal func write(_: BenchmarkCommandReply) throws {
        writeCount += 1
//        print("write \(reply)")
    }

    internal func read() throws -> BenchmarkCommandRequest {
        //      print("read request")
        Benchmark.testSkipBenchmarkRegistrations = true
        let benchmark = Benchmark("Minimal benchmark") { _ in
        }
        let benchmark2 = Benchmark("Minimal benchmark 2") { _ in
        }
        let benchmark3 = Benchmark("Minimal benchmark 3") { _ in
        }
        let returnValues: [BenchmarkCommandRequest] = [.run(benchmark: benchmark!),
                                                       .run(benchmark: benchmark2!),
                                                       .run(benchmark: benchmark3!),
                                                       .end]

        readMessage += 1
        return returnValues[readMessage - 1]
    }

    func testBenchmarkRunner() async throws {
        BenchmarkRunner.testReadWrite = self
        var runner = BenchmarkRunner()
        runner.inputFD = 0
        runner.outputFD = 0
        runner.debug = false
        try await runner.run()
        XCTAssert(writeCount == 6) // 3 tests results + 3 end markers
    }
}
