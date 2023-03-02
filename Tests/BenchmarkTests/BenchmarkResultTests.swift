//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

@testable import BenchmarkSupport
import XCTest

// swiftlint:disable function_body_length
final class BenchmarkResultTests: XCTestCase {
    func testBenchmarkResultLessThan() throws {
        let firstStatistics = Statistics()
        firstStatistics.add(125_000_000_000)
        firstStatistics.add(150_000_000_000)
        firstStatistics.add(175_000_000_000)
        firstStatistics.add(190_000_000_000)

        let secondStatistics = Statistics()
        secondStatistics.add(125_000_000_000)
        secondStatistics.add(151_000_000_000)
        secondStatistics.add(175_000_000_000)

        let firstResult = BenchmarkResult(metric: .cpuUser,
                                          timeUnits: .nanoseconds,
                                          scalingFactor: .one,
                                          warmupIterations: 0,
                                          thresholds: .default,
                                          statistics: firstStatistics)

        let secondResult = BenchmarkResult(metric: .cpuUser,
                                           timeUnits: .microseconds,
                                           scalingFactor: .one,
                                           warmupIterations: 0,
                                           thresholds: .default,
                                           statistics: secondStatistics)

        XCTAssertLessThan(firstResult, secondResult)
    }

    func testBenchmarkResultLessThanFailure() throws {
        let firstStatistics = Statistics()
        firstStatistics.add(125_000_000_000)
        firstStatistics.add(150_000_000_000)
        firstStatistics.add(175_000_000_000)
        firstStatistics.add(190_000_000_000)
        firstStatistics.add(198_000_000_000)
        firstStatistics.add(200_000_000_000)

        let firstResult = BenchmarkResult(metric: .cpuUser,
                                          timeUnits: .microseconds,
                                          scalingFactor: .one,
                                          warmupIterations: 0,
                                          thresholds: .default,
                                          statistics: firstStatistics)

        let secondResult = BenchmarkResult(metric: .cpuSystem,
                                           timeUnits: .microseconds,
                                           scalingFactor: .one,
                                           warmupIterations: 0,
                                           thresholds: .default,
                                           statistics: firstStatistics)

        XCTAssert(firstResult != secondResult)
        XCTAssertFalse(firstResult > secondResult)
        XCTAssertFalse(firstResult < secondResult)
        XCTAssertFalse(firstResult == secondResult)
    }

    func testBenchmarkResultBetterOrEqualWithDefaultThresholds() throws {
        let firstStatistics = Statistics()
        firstStatistics.add(0)
        firstStatistics.add(125_000_000)
        firstStatistics.add(150_000_000)
        firstStatistics.add(175_000_000)
        firstStatistics.add(190_000_000)
        firstStatistics.add(199_000_000)
        firstStatistics.add(200_000_000)

        let secondStatistics = Statistics()
        secondStatistics.add(2)
        secondStatistics.add(124_999)
        secondStatistics.add(149_999)
        secondStatistics.add(175_001)
        secondStatistics.add(189_999)
        secondStatistics.add(199_001)
        secondStatistics.add(200_004)

        let firstResult = BenchmarkResult(metric: .cpuUser,
                                          timeUnits: .milliseconds,
                                          scalingFactor: .one,
                                          warmupIterations: 0,
                                          thresholds: .default,
                                          statistics: firstStatistics)

        let secondResult = BenchmarkResult(metric: .cpuUser,
                                           timeUnits: .microseconds,
                                           scalingFactor: .one,
                                           warmupIterations: 0,
                                           thresholds: .default,
                                           statistics: secondStatistics)

        XCTAssert(secondResult.betterResultsOrEqual(than: firstResult))
    }

    func testBenchmarkResultBetterOrEqualWithCustomThresholds() throws {
        let firstStatistics = Statistics()
        firstStatistics.add(0)
        firstStatistics.add(125)
        firstStatistics.add(150)
        firstStatistics.add(175)
        firstStatistics.add(190)
        firstStatistics.add(199)
        firstStatistics.add(200)

        let secondStatistics = Statistics()
        secondStatistics.add(0)
        secondStatistics.add(126)
        secondStatistics.add(160)
        secondStatistics.add(175)
        secondStatistics.add(190)
        secondStatistics.add(199)
        secondStatistics.add(200)

        let relative: BenchmarkResult.PercentileRelativeThresholds = [.p0: 0.0,
                                                                      .p25: 0.0,
                                                                      .p50: 0.0,
                                                                      .p75: 0.0,
                                                                      .p90: 0.0,
                                                                      .p99: 0.0,
                                                                      .p100: 0.0]

        let relativeRelaxed: BenchmarkResult.PercentileRelativeThresholds = [.p0: 10.0,
                                                                             .p25: 10.0,
                                                                             .p50: 10.0,
                                                                             .p75: 10.0,
                                                                             .p90: 10.0,
                                                                             .p99: 10.0,
                                                                             .p100: 10.0]

        let absolute: BenchmarkResult.PercentileAbsoluteThresholds = [.p0: 1,
                                                                      .p25: 1,
                                                                      .p50: 1,
                                                                      .p75: 0,
                                                                      .p90: 0,
                                                                      .p99: 0,
                                                                      .p100: 0]
        let bothThresholds = BenchmarkResult.PercentileThresholds(relative: relative, absolute: absolute)
        let absoluteThresholds = BenchmarkResult.PercentileThresholds(absolute: absolute)
        let relativeThresholds = BenchmarkResult.PercentileThresholds(relative: relative)
        let relativeRelaxedThresholds = BenchmarkResult.PercentileThresholds(relative: relativeRelaxed)

        let firstResult = BenchmarkResult(metric: .cpuUser,
                                          timeUnits: .nanoseconds,
                                          scalingFactor: .one,
                                          warmupIterations: 0,
                                          thresholds: .default,
                                          statistics: firstStatistics)

        let secondResult = BenchmarkResult(metric: .cpuUser,
                                           timeUnits: .nanoseconds,
                                           scalingFactor: .one,
                                           warmupIterations: 0,
                                           thresholds: .default,
                                           statistics: secondStatistics)

        XCTAssertFalse(secondResult.betterResultsOrEqual(than: firstResult, thresholds: bothThresholds))
        XCTAssert(secondResult.betterResultsOrEqual(than: firstResult, thresholds: relativeRelaxedThresholds))
        XCTAssertFalse(secondResult.betterResultsOrEqual(than: firstResult, thresholds: relativeThresholds))
        XCTAssertFalse(secondResult.betterResultsOrEqual(than: firstResult, thresholds: absoluteThresholds))

        XCTAssert(firstResult.betterResultsOrEqual(than: secondResult, thresholds: bothThresholds))
        XCTAssert(firstResult.betterResultsOrEqual(than: secondResult, thresholds: relativeRelaxedThresholds))
        XCTAssert(firstResult.betterResultsOrEqual(than: secondResult, thresholds: relativeThresholds))
        XCTAssert(firstResult.betterResultsOrEqual(than: secondResult, thresholds: absoluteThresholds))
    }

    func testBenchmarkResultDescriptions() throws {
        let firstStatistics = Statistics()
        firstStatistics.add(0)
        firstStatistics.add(125)
        firstStatistics.add(150)
        firstStatistics.add(175)
        firstStatistics.add(190)
        firstStatistics.add(199)
        firstStatistics.add(200)

        let firstResult = BenchmarkResult(metric: .cpuUser,
                                          timeUnits: .nanoseconds,
                                          scalingFactor: .one,
                                          warmupIterations: 0,
                                          thresholds: .default,
                                          statistics: firstStatistics)

        XCTAssertGreaterThan((firstResult.unitDescription + firstResult.unitDescriptionPretty).count, 5)
    }
}
