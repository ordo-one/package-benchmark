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
    func testBenchmarkResultEquality() throws {
        let measurementCount = 100
        let firstPercentiles: [BenchmarkResult.Percentile: Int] = [.p0: 0,
                                                                   .p25: 125,
                                                                   .p50: 150,
                                                                   .p75: 175,
                                                                   .p90: 190,
                                                                   .p99: 199,
                                                                   .p100: 200]

        let secondPercentiles: [BenchmarkResult.Percentile: Int] = [.p0: 0,
                                                                    .p25: 125_000,
                                                                    .p50: 150_000,
                                                                    .p75: 175_000,
                                                                    .p90: 190_000,
                                                                    .p99: 199_000,
                                                                    .p100: 200_000]

        let firstResult = BenchmarkResult(metric: .cpuUser,
                                          timeUnits: .milliseconds,
                                          measurements: measurementCount,
                                          warmupIterations: 0,
                                          thresholds: .default,
                                          percentiles: firstPercentiles)

        let secondResult = BenchmarkResult(metric: .cpuUser,
                                           timeUnits: .microseconds,
                                           measurements: measurementCount,
                                           warmupIterations: 0,
                                           thresholds: .default,
                                           percentiles: secondPercentiles)

        XCTAssert(firstResult == secondResult)
    }

    func testBenchmarkResultLessThan() throws {
        let measurementCount = 100
        let firstPercentiles: [BenchmarkResult.Percentile: Int] = [.p0: 0,
                                                                   .p25: 125,
                                                                   .p50: 150,
                                                                   .p75: 175,
                                                                   .p90: 190,
                                                                   .p99: 199,
                                                                   .p100: 200]

        let secondPercentiles: [BenchmarkResult.Percentile: Int] = [.p0: 0,
                                                                    .p25: 125_000,
                                                                    .p50: 150_000,
                                                                    .p75: 175_000,
                                                                    .p90: 190_000,
                                                                    .p99: 199_001,
                                                                    .p100: 200_000]

        let firstResult = BenchmarkResult(metric: .cpuUser,
                                          timeUnits: .milliseconds,
                                          measurements: measurementCount,
                                          warmupIterations: 0,
                                          thresholds: .default,
                                          percentiles: firstPercentiles)

        let secondResult = BenchmarkResult(metric: .cpuUser,
                                           timeUnits: .microseconds,
                                           measurements: measurementCount,
                                           warmupIterations: 0,
                                           thresholds: .default,
                                           percentiles: secondPercentiles)

        XCTAssert(firstResult < secondResult)
    }

    func testBenchmarkResultLessThanFailure() throws {
        let measurementCount = 100
        let firstPercentiles: [BenchmarkResult.Percentile: Int] = [.p0: 0,
                                                                   .p25: 125,
                                                                   .p50: 150,
                                                                   .p75: 175,
                                                                   .p90: 190,
                                                                   .p99: 199,
                                                                   .p100: 200]

        let firstResult = BenchmarkResult(metric: .cpuUser,
                                          timeUnits: .microseconds,
                                          measurements: measurementCount,
                                          warmupIterations: 0,
                                          thresholds: .default,
                                          percentiles: firstPercentiles)

        let secondResult = BenchmarkResult(metric: .cpuSystem,
                                           timeUnits: .microseconds,
                                           measurements: measurementCount,
                                           warmupIterations: 0,
                                           thresholds: .default,
                                           percentiles: firstPercentiles)

        XCTAssert(firstResult != secondResult)
        XCTAssertFalse(firstResult > secondResult)
        XCTAssertFalse(firstResult < secondResult)
        XCTAssertFalse(firstResult == secondResult)
    }

    func testBenchmarkResultBetterOrEqualWithDefaultThresholds() throws {
        let measurementCount = 100
        let firstPercentiles: [BenchmarkResult.Percentile: Int] = [.p0: 0,
                                                                   .p25: 125,
                                                                   .p50: 150,
                                                                   .p75: 175,
                                                                   .p90: 190,
                                                                   .p99: 199,
                                                                   .p100: 200]

        let secondPercentiles: [BenchmarkResult.Percentile: Int] = [.p0: 2,
                                                                    .p25: 124_999,
                                                                    .p50: 149_999,
                                                                    .p75: 175_001,
                                                                    .p90: 189_999,
                                                                    .p99: 199_001,
                                                                    .p100: 200_004]

        let firstResult = BenchmarkResult(metric: .cpuUser,
                                          timeUnits: .milliseconds,
                                          measurements: measurementCount,
                                          warmupIterations: 0,
                                          thresholds: .default,
                                          percentiles: firstPercentiles)

        let secondResult = BenchmarkResult(metric: .cpuUser,
                                           timeUnits: .microseconds,
                                           measurements: measurementCount,
                                           warmupIterations: 0,
                                           thresholds: .default,
                                           percentiles: secondPercentiles)

        XCTAssert(secondResult.betterResultsOrEqual(than: firstResult))
    }

    func testBenchmarkResultBetterOrEqualWithCustomThresholds() throws {
        let measurementCount = 100
        let firstPercentiles: [BenchmarkResult.Percentile: Int] = [.p0: 0,
                                                                   .p25: 125,
                                                                   .p50: 150,
                                                                   .p75: 175,
                                                                   .p90: 190,
                                                                   .p99: 199,
                                                                   .p100: 200]

        let secondPercentiles: [BenchmarkResult.Percentile: Int] = [.p0: 0,
                                                                    .p25: 126,
                                                                    .p50: 160,
                                                                    .p75: 175,
                                                                    .p90: 190,
                                                                    .p99: 199,
                                                                    .p100: 200]

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
                                          timeUnits: .microseconds,
                                          measurements: measurementCount,
                                          warmupIterations: 0,
                                          thresholds: .default,
                                          percentiles: firstPercentiles)

        let secondResult = BenchmarkResult(metric: .cpuUser,
                                           timeUnits: .microseconds,
                                           measurements: measurementCount,
                                           warmupIterations: 0,
                                           thresholds: .default,
                                           percentiles: secondPercentiles)

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
        let measurementCount = 100
        let firstPercentiles: [BenchmarkResult.Percentile: Int] = [.p0: 0,
                                                                   .p25: 125,
                                                                   .p50: 150,
                                                                   .p75: 175,
                                                                   .p90: 190,
                                                                   .p99: 199,
                                                                   .p100: 200]

        let firstResult = BenchmarkResult(metric: .cpuUser,
                                          timeUnits: .milliseconds,
                                          measurements: measurementCount,
                                          warmupIterations: 0,
                                          thresholds: .default,
                                          percentiles: firstPercentiles)

        XCTAssert((firstResult.unitDescription + firstResult.unitDescriptionPretty).count > 5)
    }
}
