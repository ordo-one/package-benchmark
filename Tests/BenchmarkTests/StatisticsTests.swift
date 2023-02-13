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
import XCTest

final class StatisticsTests: XCTestCase {
    func testStatisticsResults() throws {
        var stats = Statistics()
        let measurementCount = 8_340

        // Add 2*measurementCount measurements, one 0, one max
        for measurement in (0 ..< measurementCount).reversed() {
            stats.add(measurement)
        }

        for measurement in 1 ... measurementCount {
            stats.add(measurement)
        }

        XCTAssertEqual(stats.measurementCount, measurementCount * 2)
        XCTAssertEqual(stats.timeUnits, .count)
        XCTAssertEqual(round(stats.averageMeasurement), round(Double(measurementCount / 2)))
        XCTAssertEqual(stats.bucketOverflowLinear, 0)
        XCTAssertEqual(stats.bucketOverflowPowerOfTwo, 0)

        stats.calculateStatistics()

        XCTAssertEqual(stats.percentileResults[0]!, 0)
        XCTAssertEqual(stats.percentileResults[1]!, Int(round(Double(measurementCount) * 0.25)))
        XCTAssertEqual(stats.percentileResults[2]!, Int(round(Double(measurementCount) * 0.5)))
        XCTAssertEqual(stats.percentileResults[3]!, Int(round(Double(measurementCount) * 0.75)))
        XCTAssertEqual(stats.percentileResults[4]!, Int(round(Double(measurementCount) * 0.9)))
        XCTAssertEqual(stats.percentileResults[5]!, Int(round(Double(measurementCount) * 0.99)))
        XCTAssertEqual(stats.percentileResults[6]!, Int(measurementCount))
    }

    func testOnlyZeroMeasurements() throws {
        var stats = Statistics()
        let measurementCount = 100
        let range = 0 ..< measurementCount

        for _ in range {
            stats.add(0)
        }

        XCTAssertEqual(stats.measurementCount, range.count)
        XCTAssertEqual(stats.timeUnits, .automatic)
        XCTAssertEqual(stats.averageMeasurement, 0.0)
        XCTAssertEqual(stats.bucketOverflowLinear, 0)
        XCTAssertEqual(stats.bucketOverflowPowerOfTwo, 0)

        XCTAssert(stats.onlyZeroMeasurements)

        stats.calculateStatistics()

        XCTAssert(stats.onlyZeroMeasurements)
        XCTAssertEqual(stats.timeUnits, .count)
        XCTAssertEqual(stats.percentileResults[0]!, 0)
        XCTAssertEqual(stats.percentileResults[1]!, 0)
        XCTAssertEqual(stats.percentileResults[2]!, 0)
        XCTAssertEqual(stats.percentileResults[3]!, 0)
        XCTAssertEqual(stats.percentileResults[4]!, 0)
        XCTAssertEqual(stats.percentileResults[5]!, 0)
        XCTAssertEqual(stats.percentileResults[6]!, 0)
    }

    func testFewerMeasurementsThanPercentiles() throws {
        var stats = Statistics()
        let measurementCount = 5
        let range = 1 ..< measurementCount
        var accumulatedMeasurement = 0

        for measurement in range {
            stats.add(measurement)
            accumulatedMeasurement += measurement
        }

        XCTAssertEqual(stats.measurementCount, range.count)
        XCTAssertEqual(stats.timeUnits, .count)
        XCTAssertEqual(round(stats.averageMeasurement), round(Double(accumulatedMeasurement) / Double(range.count)))
        XCTAssertEqual(stats.bucketOverflowLinear, 0)
        XCTAssertEqual(stats.bucketOverflowPowerOfTwo, 0)

        stats.calculateStatistics()

        XCTAssertEqual(stats.percentileResults[0]!, 1)
        XCTAssertEqual(stats.percentileResults[1]!, Int(round(Double(range.count) * 0.25)))
        XCTAssertEqual(stats.percentileResults[2]!, Int(round(Double(range.count) * 0.5)))
        XCTAssertEqual(stats.percentileResults[3]!, Int(round(Double(range.count) * 0.75)))
        XCTAssertEqual(stats.percentileResults[4]!, Int(round(Double(range.count) * 0.9)))
        XCTAssertEqual(stats.percentileResults[5]!, Int(round(Double(range.count) * 0.99)))
        XCTAssertEqual(stats.percentileResults[6]!, Int(range.count))
    }

    func testAutomaticUnits() throws {
        var stats = Statistics()

        stats.add(0)
        stats.calculateStatistics()
        XCTAssertEqual(stats.timeUnits, .count)

        stats.reset()
        stats.add(1)
        XCTAssertEqual(stats.timeUnits, .count)

        stats.reset()
        stats.add(9_999)
        XCTAssertEqual(stats.timeUnits, .count)

        stats.reset()
        stats.add(10_000)
        XCTAssertEqual(stats.timeUnits, .kilo)

        stats.reset()
        stats.add(100_000)
        XCTAssertEqual(stats.timeUnits, .kilo)

        stats.reset()
        stats.add(1_000_000)
        XCTAssertEqual(stats.timeUnits, .kilo)

        stats.reset()
        stats.add(9_999_999)
        XCTAssertEqual(stats.timeUnits, .kilo)

        stats.reset()
        stats.add(10_000_000)
        XCTAssertEqual(stats.timeUnits, .mega)

        stats.reset()
        stats.add(9_999_999_999)
        XCTAssertEqual(stats.timeUnits, .mega)

        stats.reset()
        stats.add(10_000_000_000)
        XCTAssertEqual(stats.timeUnits, .giga)

        stats.reset()
        stats.add(0)
        XCTAssertEqual(stats.timeUnits, .automatic)
        stats.calculateStatistics()
        XCTAssertEqual(stats.timeUnits, .count)
    }

    func testStatisticsOverflow() throws {
        let measurementCount = 300
        let bucketCount = 100
        var stats = Statistics(bucketCount: bucketCount)

        for measurement in 1 ... measurementCount {
            stats.add(measurement)
        }

        XCTAssertEqual(stats.bucketOverflowLinear, measurementCount - bucketCount)
        XCTAssertEqual(stats.bucketOverflowPowerOfTwo, 0)

        stats.calculateStatistics()

        XCTAssertEqual(stats.percentileResults[0]!, 1)
        XCTAssertEqual(stats.percentileResults[1]!, 75)
        XCTAssertEqual(stats.percentileResults[2]!, 256)
        XCTAssertEqual(stats.percentileResults[3]!, 256)
        XCTAssertEqual(stats.percentileResults[4]!, 512)
        XCTAssertEqual(stats.percentileResults[5]!, 512)
        XCTAssertEqual(stats.percentileResults[6]!, 512)
    }

    func testStatisticsOverflowReversePolarity() throws {
        let measurementCount = 300
        let bucketCount = 100
        var stats = Statistics(bucketCount: bucketCount, prefersLarger: true)

        for measurement in 1 ... measurementCount {
            stats.add(measurement)
        }

        XCTAssertEqual(stats.bucketOverflowLinear, measurementCount - bucketCount)
        XCTAssertEqual(stats.bucketOverflowPowerOfTwo, 0)

        stats.calculateStatistics()

        XCTAssertEqual(stats.percentileResults[0]!, 512)
        XCTAssertEqual(stats.percentileResults[1]!, 256)
        XCTAssertEqual(stats.percentileResults[2]!, 256)
        XCTAssertEqual(stats.percentileResults[3]!, 128)
        XCTAssertEqual(stats.percentileResults[4]!, 31)
        XCTAssertEqual(stats.percentileResults[5]!, 4)
        XCTAssertEqual(stats.percentileResults[6]!, 1)
    }

    func testHistograms() throws {
        let measurementCount = 300
        let bucketCount = 100
        var stats = Statistics(bucketCount: bucketCount, prefersLarger: true)

        for measurement in 1 ... measurementCount {
            stats.add(measurement)
        }

        let histograms = stats.output()

        XCTAssertGreaterThan(histograms.count, 100)
    }
}
