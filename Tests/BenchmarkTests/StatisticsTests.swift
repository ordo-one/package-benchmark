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
@testable import Statistics
import XCTest
/*
final class StatisticsTests: XCTestCase {
    func testStatisticsResults() throws {
        var stats = Statistics(numberOfSignificantDigits: .four)
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
        XCTAssertEqual(round(stats.histogram.mean), round(Double(measurementCount / 2)))

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
        XCTAssertEqual(stats.histogram.mean, 0.0)

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
        XCTAssertEqual(round(stats.histogram.mean), round(Double(accumulatedMeasurement) / Double(range.count)))

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
        typealias Case = (value: Int, units: Statistics.Units)

        let cases = [
            Case(value: 0, units: .count),
            Case(value: 1, units: .count),
            Case(value: 9_999, units: .count),
            Case(value: 10_000, units: .kilo),
            Case(value: 100_000, units: .kilo),
            Case(value: 1_000_000, units: .kilo),
            Case(value: 9_999_999, units: .kilo),
            Case(value: 10_000_000, units: .mega),
            Case(value: 9_999_999_999, units: .mega),
            Case(value: 10_000_000_000, units: .giga)
        ]

        for (value, expectedUnits) in cases {
            let units = Statistics.Units(fromMagnitudeOf: Double(value))
            XCTAssertEqual(units, expectedUnits, "Expected units for \(value) are \(expectedUnits)")
        }
    }

    func testHistograms() throws {
        let measurementCount = 300
        var stats = Statistics(prefersLarger: true)

        for measurement in 1 ... measurementCount {
            stats.add(measurement)
        }

        XCTAssertGreaterThan(stats.histogram.totalCount, 100)
    }
}
*/
