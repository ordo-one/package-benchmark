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
import XCTest

// swiftlint:disable function_body_length type_body_length file_length
final class BenchmarkResultTests: XCTestCase {
    func testBenchmarkResultEqual() throws {
        let firstStatistics = Statistics()
        firstStatistics.add(125_000_000_000)
        firstStatistics.add(150_000_000_000)
        firstStatistics.add(175_000_000_000)
        firstStatistics.add(190_000_000_000)

        let firstResult = BenchmarkResult(metric: .cpuUser,
                                          timeUnits: .nanoseconds,
                                          scalingFactor: .one,
                                          warmupIterations: 0,
                                          thresholds: .default,
                                          statistics: firstStatistics)

        let secondResult = BenchmarkResult(metric: .cpuUser,
                                           timeUnits: .nanoseconds,
                                           scalingFactor: .giga,
                                           warmupIterations: 20,
                                           thresholds: .default,
                                           statistics: firstStatistics)

        XCTAssertEqual(firstResult, secondResult)
    }

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

        let thirdStatistics = Statistics()
        thirdStatistics.add(225_000_000_000)
        thirdStatistics.add(251_000_000_000)
        thirdStatistics.add(275_000_000_000)

        let firstResult = BenchmarkResult(metric: .cpuUser,
                                          timeUnits: .nanoseconds,
                                          scalingFactor: .one,
                                          warmupIterations: 0,
                                          thresholds: .default,
                                          statistics: firstStatistics)

        var secondResult = BenchmarkResult(metric: .cpuUser,
                                           timeUnits: .microseconds,
                                           scalingFactor: .one,
                                           warmupIterations: 0,
                                           thresholds: .default,
                                           statistics: secondStatistics)

        var thirdResult = BenchmarkResult(metric: .cpuUser,
                                          timeUnits: .microseconds,
                                          scalingFactor: .one,
                                          warmupIterations: 0,
                                          thresholds: .default,
                                          statistics: thirdStatistics)

        XCTAssertLessThan(firstResult, secondResult)
        XCTAssertGreaterThan(thirdResult, secondResult)

        secondResult = BenchmarkResult(metric: .throughput,
                                       timeUnits: .microseconds,
                                       scalingFactor: .one,
                                       warmupIterations: 0,
                                       thresholds: .default,
                                       statistics: secondStatistics)

        thirdResult = BenchmarkResult(metric: .throughput,
                                      timeUnits: .microseconds,
                                      scalingFactor: .one,
                                      warmupIterations: 0,
                                      thresholds: .default,
                                      statistics: thirdStatistics)

        // Should be reversed for throughput measurements
        XCTAssertLessThan(thirdResult, secondResult)
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

        XCTAssertNotEqual(firstResult, secondResult)
        XCTAssertFalse(firstResult > secondResult)
        XCTAssertFalse(firstResult < secondResult)
        XCTAssertNotEqual(firstResult, secondResult)
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

        let (betterOrEqual, _) = secondResult.betterResultsOrEqual(than: firstResult)
        XCTAssert(betterOrEqual)
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
        secondStatistics.add(5)
        secondStatistics.add(136)
        secondStatistics.add(160)
        secondStatistics.add(175)
        secondStatistics.add(190)
        secondStatistics.add(199)
        secondStatistics.add(210)

        let relative: BenchmarkThresholds.RelativeThresholds = [.p0: 0.0,
                                                                .p25: 0.0,
                                                                .p50: 0.0,
                                                                .p75: 0.0,
                                                                .p90: 0.0,
                                                                .p99: 0.0,
                                                                .p100: 0.0]

        let relativeRelaxed: BenchmarkThresholds.RelativeThresholds = [.p0: 10.0,
                                                                       .p25: 10.0,
                                                                       .p50: 10.0,
                                                                       .p75: 10.0,
                                                                       .p90: 10.0,
                                                                       .p99: 10.0,
                                                                       .p100: 10.0]

        let absolute: BenchmarkThresholds.AbsoluteThresholds = [.p0: 1,
                                                                .p25: 1,
                                                                .p50: 1,
                                                                .p75: 0,
                                                                .p90: 0,
                                                                .p99: 0,
                                                                .p100: 0]

        let bothThresholds = BenchmarkThresholds(relative: relative, absolute: absolute)
        let absoluteThresholds = BenchmarkThresholds(absolute: absolute)
        let relativeThresholds = BenchmarkThresholds(relative: relative)
        let relativeRelaxedThresholds = BenchmarkThresholds(relative: relativeRelaxed)

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

        var (betterOrEqual, _) = secondResult.betterResultsOrEqual(than: firstResult, thresholds: bothThresholds)
        XCTAssertFalse(betterOrEqual)

        (betterOrEqual, _) = secondResult.betterResultsOrEqual(than: firstResult, thresholds: relativeRelaxedThresholds)
        XCTAssert(betterOrEqual)

        (betterOrEqual, _) = secondResult.betterResultsOrEqual(than: firstResult, thresholds: relativeThresholds)
        XCTAssertFalse(betterOrEqual)

        (betterOrEqual, _) = secondResult.betterResultsOrEqual(than: firstResult, thresholds: absoluteThresholds)
        XCTAssertFalse(betterOrEqual)

        (betterOrEqual, _) = firstResult.betterResultsOrEqual(than: secondResult, thresholds: bothThresholds)
        XCTAssert(betterOrEqual)

        (betterOrEqual, _) = firstResult.betterResultsOrEqual(than: secondResult, thresholds: relativeRelaxedThresholds)
        XCTAssert(betterOrEqual)

        (betterOrEqual, _) = firstResult.betterResultsOrEqual(than: secondResult, thresholds: relativeThresholds)
        XCTAssert(betterOrEqual)

        (betterOrEqual, _) = firstResult.betterResultsOrEqual(than: secondResult, thresholds: absoluteThresholds)
        XCTAssert(betterOrEqual)
    }

    func testBenchmarkAbsoluteThresholds() throws {
        let firstStatistics = Statistics()
        firstStatistics.add(0)
        firstStatistics.add(125)
        firstStatistics.add(150)
        firstStatistics.add(175)
        firstStatistics.add(190)
        firstStatistics.add(199)
        firstStatistics.add(200)

        let secondStatistics = Statistics()
        secondStatistics.add(5)
        secondStatistics.add(136)
        secondStatistics.add(160)
        secondStatistics.add(175)
        secondStatistics.add(190)
        secondStatistics.add(199)
        secondStatistics.add(210)

        let thirdStatistics = Statistics()
        thirdStatistics.add(1_501)
        thirdStatistics.add(1_501)
        thirdStatistics.add(1_501)
        thirdStatistics.add(1_501)
        thirdStatistics.add(1_501)

        let fourthStatistics = Statistics()
        fourthStatistics.add(1_499)
        fourthStatistics.add(1_500)
        fourthStatistics.add(1_501)
        fourthStatistics.add(1_501)
        fourthStatistics.add(1_501)
        fourthStatistics.add(1_501)

        let absolute: BenchmarkThresholds.AbsoluteThresholds = [.p0: 1,
                                                                .p25: 1,
                                                                .p50: 1,
                                                                .p75: 1,
                                                                .p90: 1,
                                                                .p99: 1]

        let absoluteThresholds = BenchmarkThresholds(absolute: absolute)

        let absoluteTwo: BenchmarkThresholds.AbsoluteThresholds = [.p0: 1_500,
                                                                   .p25: 1_500,
                                                                   .p50: 1_500,
                                                                   .p75: 1_500,
                                                                   .p90: 1_500,
                                                                   .p99: 1_500]

        let absoluteThresholdsTwo = BenchmarkThresholds(absolute: absoluteTwo)

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

        let thirdResult = BenchmarkResult(metric: .cpuUser,
                                          timeUnits: .nanoseconds,
                                          scalingFactor: .one,
                                          warmupIterations: 0,
                                          thresholds: .default,
                                          statistics: thirdStatistics)

        let fourthResult = BenchmarkResult(metric: .cpuUser,
                                           timeUnits: .nanoseconds,
                                           scalingFactor: .one,
                                           warmupIterations: 0,
                                           thresholds: .default,
                                           statistics: fourthStatistics)

        var (betterOrEqual, failures) = secondResult.betterResultsOrEqual(than: firstResult,
                                                                          thresholds: absoluteThresholds)
        XCTAssertFalse(betterOrEqual)
        XCTAssertFalse(failures.isEmpty, "Failures: \(failures)")

        (betterOrEqual, failures) = firstResult.betterResultsOrEqual(than: secondResult,
                                                                     thresholds: absoluteThresholds)
        XCTAssert(betterOrEqual)
        XCTAssert(failures.isEmpty)

        Benchmark.checkAbsoluteThresholds = true
        let results = thirdResult.failsAbsoluteThresholdChecks(thresholds: absoluteThresholdsTwo,
                                                               name: "test",
                                                               target: "test")
        XCTAssert(results.regressions.count > 4)

        Benchmark.checkAbsoluteThresholds = true
        let mixedResults = fourthResult.failsAbsoluteThresholdChecks(thresholds: absoluteThresholdsTwo,
                                                                     name: "test",
                                                                     target: "test")
        XCTAssertEqual(mixedResults.regressions.count, 4)
        XCTAssertEqual(mixedResults.improvements.count, 1)
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

    func testBenchmarkResultScalingAndNormalization() throws {
        let firstStatistics = Statistics()
        firstStatistics.add(125_000_000_000)

        var result = BenchmarkResult(metric: .cpuUser,
                                     timeUnits: .milliseconds,
                                     scalingFactor: .giga,
                                     warmupIterations: 0,
                                     thresholds: .default,
                                     statistics: firstStatistics)

        XCTAssertEqual(result.normalize(125_000_000), result.scale(125_000_000_000))

        result = BenchmarkResult(metric: .cpuUser,
                                 timeUnits: .microseconds,
                                 scalingFactor: .mega,
                                 warmupIterations: 0,
                                 thresholds: .default,
                                 statistics: firstStatistics)

        XCTAssertEqual(result.normalize(125_000_000), result.scale(125_000_000_000))

        result = BenchmarkResult(metric: .cpuUser,
                                 timeUnits: .nanoseconds,
                                 scalingFactor: .kilo,
                                 warmupIterations: 0,
                                 thresholds: .default,
                                 statistics: firstStatistics)

        XCTAssertEqual(result.normalize(125_000_000), result.scale(125_000_000_000))
    }

    func testBenchmarkResultEnumerations() throws {
        var scalingFactor: BenchmarkScalingFactor = .one
        var description = ""
        description += scalingFactor.description
        scalingFactor = .kilo
        description += scalingFactor.description
        scalingFactor = .mega
        description += scalingFactor.description
        scalingFactor = .giga
        description += scalingFactor.description
        scalingFactor = .tera
        description += scalingFactor.description
        XCTAssert(description.count > 4)
    }
}

// swiftlint:enable function_body_length type_body_length
