// swiftlint:disable all
//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

import Histogram
import Numerics

public let defaultPercentilesToCalculate = [0.000001, 25.0, 50.0, 75.0, 90.0, 99.0, 100.0]
private let numberPadding = 10
public let defaultMaximumMeasurement = 60_000_000_000 // 1 min in nanoseconds

public enum StatisticsUnits: Int, Codable {
    case count = 1 // e.g. nanoseconds
    case kilo = 1_000 // microseconds
    case mega = 1_000_000 // milliseconds
    case giga = 1_000_000_000 // seconds
    case automatic = 0 // will pick time unit above automatically

    public var description: String {
        switch self {
        case .count:
            return "#"
        case .kilo:
            return "K"
        case .mega:
            return "M"
        case .giga:
            return "G"
        case .automatic:
            return "#"
        }
    }

    init(fromMagnitudeOf value: Double) {
        let magnitude = Double.log10(value)
        switch magnitude {
        case ..<4.0:
            self = .count
        case 4.0 ..< 7.0:
            self = .kilo
        case 7.0 ..< 10.0:
            self = .mega
        case 10.0...:
            self = .giga
        default:
            self = .kilo
        }
    }
}

/// A type that provides distribution / percentile calculations of latency measurements
public struct Statistics: Codable {
    public let numberOfSignificantDigits: SignificantDigits
    public let prefersLarger: Bool

    public let percentilesToCalculate: [Double] // current percentiles we calculate
    public var percentileResults: [Int?] = []

    private let _timeUnits: StatisticsUnits

    public var timeUnits: StatisticsUnits {
        // set timeUnits for proper scaling
        if _timeUnits != .automatic {
            return _timeUnits
        }

        if onlyZeroMeasurements {
            return .count
        }

        return StatisticsUnits(fromMagnitudeOf: histogram.mean)
    }

    public var histogram: Histogram<UInt>

    public var onlyZeroMeasurements = true

    public var measurementCount: Int {
        Int(histogram.totalCount)
    }

    public var averageMeasurement: Double {
        histogram.mean
    }

    public init(maximumMeasurement: Int = defaultMaximumMeasurement,
                numberOfSignificantDigits: SignificantDigits = .three,
                timeUnits: StatisticsUnits = .automatic,
                percentiles: [Double] = defaultPercentilesToCalculate,
                prefersLarger: Bool = false) {
        self.numberOfSignificantDigits = numberOfSignificantDigits
        self.prefersLarger = prefersLarger
        percentilesToCalculate = percentiles
        _timeUnits = timeUnits

        histogram = Histogram(highestTrackableValue: UInt64(maximumMeasurement), numberOfSignificantValueDigits: numberOfSignificantDigits)
        histogram.autoResize = true

        reset()
    }

    /// Add a measurement for inclusion in statistics
    /// - Parameter measurement: A measurement expressed in nanoseconds
    @inlinable
    @inline(__always)
    public mutating func add(_ measurement: Int) {
        guard measurement >= 0 else {
            return // We sometimes got a <0 measurement, should run with fatalError and try to see how that could occur
//            fatalError()
        }

        if measurement != 0, onlyZeroMeasurements {
            onlyZeroMeasurements = false
        }

        histogram.record(UInt64(measurement))
    }

    /// Reset all acummulated statistics
    public mutating func reset() {
        histogram.reset()

        onlyZeroMeasurements = true

        percentileResults.removeAll(keepingCapacity: true)
    }

    /// Perform percentile calculations based on the accumulated statistics
    public mutating func calculateStatistics() {
        percentileResults.removeAll(keepingCapacity: true)
        percentileResults.reserveCapacity(percentilesToCalculate.count)

        let scaling = timeUnits.rawValue

        for var p in percentilesToCalculate {
            if prefersLarger {
                p = 100.0 - p
            }

            let value = histogram.valueAtPercentile(p)
            let scaledValue = (Double(value) / Double(scaling)).rounded(.toNearestOrAwayFromZero)

            percentileResults.append(Int(scaledValue))
        }
    }

    /// A printable text-based histogram+percentiles suitable for display in a fixed-size font
    /// - Returns: All collected statistics
    public mutating func output() -> String {
        var out = ""
        histogram.outputPercentileDistribution(to: &out, outputValueUnitScalingRatio: Double(timeUnits.rawValue))
        return out
    }
}

// Rounds decimals for display
public func roundToDecimalplaces(_ original: Double, _ decimals: Int = 2) -> Double {
    let factor: Double = .pow(10.0, Double(decimals))
    var original: Double = original * factor
    original.round(.toNearestOrEven)
    return original / factor
}
