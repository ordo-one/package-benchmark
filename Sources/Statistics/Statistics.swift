//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

import Numerics

public let defaultPercentilesToCalculate = [0.000001, 25.0, 50.0, 75.0, 90.0, 99.0, 100.0]
private let numberPadding = 10

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
}

/// A type that provides distribution / percentile calculations of latency measurements
public struct Statistics {
    public let bucketCountLinear: Int
    public let bucketCountPowerOfTwo = 32
    public var measurementBucketsLinear: [Int] // 1..bucketCount - histogram
    public var measurementBucketsPowerOfTwo: [Int] // we do 1, 2, 4, 8, ... bucketCount - histogram
    public let percentilesToCalculate: [Double] // current percentiles we calculate
    public var percentileResults: [Int?]
    public var bucketOverflowLinear = 0
    public var bucketOverflowPowerOfTwo = 0
    public var averageMeasurement = 0.0
    public var measurementCount = 0
    public var timeUnits: StatisticsUnits = .automatic

    public var onlyZeroMeasurements = true
    var prefersLarger = true
    var originalTimeUnitWasAutomatic: Bool

    public init(bucketCount: Int = 10_000,
                timeUnits: StatisticsUnits = .automatic,
                percentiles: [Double] = defaultPercentilesToCalculate,
                prefersLarger: Bool = false) {
        bucketCountLinear = bucketCount < 1 ? 1 : bucketCount + 1 // we don't use the zero bucket, so add one
        percentilesToCalculate = percentiles
        self.prefersLarger = prefersLarger
        measurementBucketsPowerOfTwo = [Int](repeating: 0, count: bucketCountPowerOfTwo)
        measurementBucketsLinear = [Int](repeating: 0, count: bucketCountLinear)
        percentileResults = [Int?](repeating: nil, count: percentilesToCalculate.count)
        self.timeUnits = timeUnits
        originalTimeUnitWasAutomatic = timeUnits == .automatic ? true : false
    }

    /// Add a measurement for inclusion in statistics
    /// - Parameter measurement: A measurement expressed in nanoseconds
    @inlinable
    @inline(__always)
    public mutating func add(_ measurement: Int) {
        var measurement = measurement
        guard measurement >= 0 else {
            return // We sometimes got a <0 measurement, should run with fatalError and try to see how that could occur
//            fatalError()
        }

        if timeUnits == .automatic,
           onlyZeroMeasurements,
           measurement != 0 { // deduce timeunit range from first non-zero sample if .automatic
            onlyZeroMeasurements = false

            let doubleMeasurement: Double = .log10(Double(measurement))
            switch doubleMeasurement {
            case ..<4.0:
                timeUnits = .count
            case 4.0 ..< 7.0:
                timeUnits = .kilo
            case 7.0 ..< 10.0:
                timeUnits = .mega
            case 10.0...:
                timeUnits = .giga
            default:
                timeUnits = .kilo
            }
        }

        let scaling = timeUnits == .automatic ? 1 : timeUnits.rawValue
        var roundedMeasurement = Double(measurement) / Double(scaling)
        roundedMeasurement.round(.toNearestOrAwayFromZero)
        measurement = Int(roundedMeasurement)

        let validBucketRangePowerOfTwo = 0 ..< bucketCountPowerOfTwo
        let log2Measurement: Double = .log2(Double(measurement)).rounded(.up)
        let bucket = measurement > 0 ? Int(log2Measurement) : 0

        averageMeasurement = (Double(measurementCount) * averageMeasurement + Double(measurement))
            / Double(measurementCount + 1)
        measurementCount += 1

        if validBucketRangePowerOfTwo.contains(bucket) {
            measurementBucketsPowerOfTwo[bucket] += 1
        } else {
            bucketOverflowPowerOfTwo += 1
        }

        let validBucketRangeLinear = 0 ..< bucketCountLinear

        if validBucketRangeLinear.contains(Int(measurement)) {
            measurementBucketsLinear[Int(measurement)] += 1
        } else {
            bucketOverflowLinear += 1
        }
    }

    /// Reset all acummulated statistics
    public mutating func reset() {
        averageMeasurement = 0.0
        measurementCount = 0
        bucketOverflowLinear = 0
        bucketOverflowPowerOfTwo = 0
        onlyZeroMeasurements = true
        if originalTimeUnitWasAutomatic {
            timeUnits = .automatic
        }
        measurementBucketsPowerOfTwo = [Int](repeating: 0, count: bucketCountPowerOfTwo)
        measurementBucketsLinear = [Int](repeating: 0, count: bucketCountLinear)
        percentileResults = [Int?](repeating: nil, count: percentilesToCalculate.count)
    }

    /// Perform percentile calculations based on the accumulated statistics
    public mutating func calculateStatistics() {
        // Unfortunate code duplication, but it's a bit messy with reversed ranges
        // in Swift, couldn't find any clean way to parameterize it
        func calculatePercentiles(for measurementBuckets: [Int],
                                  startSamples: Int,
                                  stopSamples _: Int,
                                  powerOfTwo: Bool) {
            var accumulatedSamples = startSamples // current accumulation of sample during processing

            accumulatedSamples = 0
            for (bucketIndex, currentBucket) in measurementBuckets.enumerated() {
                accumulatedSamples += currentBucket

                for percentile in 0 ..< percentilesToCalculate.count {
                    if percentileResults[percentile] == nil,
                       Double(accumulatedSamples) / Double(totalSamples) >= (percentilesToCalculate[percentile] / 100)
                    {
                        percentileResults[percentile] = powerOfTwo ? 1 << bucketIndex : bucketIndex
                    }
                }
            }
        }

        func calculateReversedPercentiles(for measurementBuckets: [Int],
                                          startSamples: Int,
                                          stopSamples: Int,
                                          powerOfTwo: Bool) {
            var accumulatedSamples = startSamples // current accumulation of sample during processing

            for (bucketIndex, currentBucket) in measurementBuckets.enumerated().reversed() {
                if accumulatedSamples >= stopSamples {
                    return
                }

                accumulatedSamples += currentBucket

                for percentile in 0 ..< percentilesToCalculate.count {
                    if percentileResults[percentile] == nil,
                       Double(accumulatedSamples) / Double(totalSamples) >= (percentilesToCalculate[percentile] / 100)
                    {
                        percentileResults[percentile] = powerOfTwo ? 1 << bucketIndex : bucketIndex
                    }
                }
            }
        }

        // Set timeUnits to .count if we only had zero samples and had automatic setting of scale
        if timeUnits == .automatic, onlyZeroMeasurements {
            timeUnits = .count
        }

        let linearSamples = measurementBucketsLinear.reduce(0, +)
        let powerOfTwoSamples = measurementBucketsPowerOfTwo.reduce(0, +)
        let totalSamples = powerOfTwoSamples + bucketOverflowPowerOfTwo

        // We use linear buckets primarily but fill outliers with power of two
        if prefersLarger {
            calculateReversedPercentiles(for: measurementBucketsPowerOfTwo,
                                         startSamples: 0,
                                         stopSamples: totalSamples - linearSamples,
                                         powerOfTwo: true)
            calculateReversedPercentiles(for: measurementBucketsLinear,
                                         startSamples: totalSamples - linearSamples,
                                         stopSamples: totalSamples,
                                         powerOfTwo: false)
        } else {
            calculatePercentiles(for: measurementBucketsLinear,
                                 startSamples: 0,
                                 stopSamples: linearSamples,
                                 powerOfTwo: false)
            calculatePercentiles(for: measurementBucketsPowerOfTwo,
                                 startSamples: 0,
                                 stopSamples: totalSamples,
                                 powerOfTwo: true)
        }
    }

    // We currently don't expose the histograms, maybe in the future
    private func generateHistogram(for measurementBuckets: [Int], totalSamples: Int, powerOfTwo: Bool) -> String {
        var histogram = ""
        let bucketCount = measurementBuckets.count

        guard bucketCount > 0 else {
            return ""
        }

        let firstNonEmptyBucket = measurementBuckets.firstIndex(where: { $0 > 0 }) ?? 0
        let lastNonEmptyBucket = measurementBuckets.lastIndex(where: { $0 > 0 }) ?? 0

        for currentBucket in firstNonEmptyBucket ... lastNonEmptyBucket {
            var histogramMarkers = "\((powerOfTwo ? 1 << currentBucket : currentBucket).paddedString(to: numberPadding)) = "
            var markerCount = Int((Double(measurementBuckets[currentBucket]) / Double(totalSamples)) * 100.0)
            // always print a single * if there's any samples in the bucket
            if measurementBuckets[currentBucket] > 0, markerCount == 0 {
                markerCount = 1
            }

            for _ in 0 ..< markerCount {
                histogramMarkers += "*"
            }
            histogram += histogramMarkers + "\n"

            if firstNonEmptyBucket == lastNonEmptyBucket, measurementBuckets[currentBucket] == 0 {
                histogram = ""
            }
        }
        return histogram
    }

    /// A printable text-based histogram suitable for display in a fixed-size font
    /// - Returns: The histogram - linear buckets
    public func histogramLinear() -> String {
        let totalSamples = measurementBucketsLinear.reduce(0, +) + bucketOverflowLinear
        var histogram = ""

        assert(measurementCount == totalSamples, "measurementCount != totalSamples")

        guard totalSamples > 0 else {
            return "Zero samples, no linear histogram available.\n"
        }

        if measurementBucketsLinear.count > 1 {
            histogram += "Linear histogram (\(totalSamples) samples): \n" + generateHistogram(for: measurementBucketsLinear,
                                                                                              totalSamples: totalSamples,
                                                                                              powerOfTwo: false)
            if bucketOverflowLinear > 0 {
                var histogramMarkers = ""
                for _ in 0 ..< Int((Double(bucketOverflowLinear) / Double(totalSamples)) * 100.0) {
                    histogramMarkers += "*"
                }
                if histogramMarkers.isEmpty {
                    histogramMarkers += "*"
                }
                histogram += "\((measurementBucketsLinear.count - 1).paddedString(to: numberPadding)) > \(histogramMarkers)\n"
            }
            histogram += "\n"
        }

        return histogram
    }

    /// A printable text-based histogram suitable for display in a fixed-size font
    /// - Returns: The histogram - power of two buckets
    public mutating func histogramPowerOfTwo() -> String {
        let totalSamples = measurementBucketsPowerOfTwo.reduce(0, +) + bucketOverflowPowerOfTwo
        var histogram = ""

        assert(measurementCount == totalSamples, "measurementCount != totalSamples")

        guard totalSamples > 0 else {
            return "Zero samples, no power of two histogram available.\n"
        }

        histogram += "Power of Two histogram (\(totalSamples) samples):\n" +
            generateHistogram(for: measurementBucketsPowerOfTwo,
                              totalSamples: totalSamples,
                              powerOfTwo: true)

        if bucketOverflowPowerOfTwo > 0 {
            var histogramMarkers = ""
            for _ in 0 ..< Int((Double(bucketOverflowPowerOfTwo) / Double(totalSamples)) * 100.0) {
                histogramMarkers += "*"
            }
            if histogramMarkers.isEmpty {
                histogramMarkers += "*"
            }
            histogram += "\((1 << measurementBucketsPowerOfTwo.count).paddedString(to: numberPadding)) > \(histogramMarkers)\n"
        }

        return histogram
    }

    /// A printable text-based  percentile statistics suitable for display in a fixed-size font
    /// - Returns: The percentiles
    public mutating func percentileStatistics() -> String {
        let totalSamples = measurementBucketsPowerOfTwo.reduce(0, +) + bucketOverflowPowerOfTwo

        assert(measurementCount == totalSamples, "measurementCount != totalSamples")

//        var result = "Percentile measurements (\(totalSamples) samples," +
//                     " average \(String(format: "%.2f", averageMeasurement))):\n"

        var result = "Percentile measurements (\(totalSamples) samples," +
            " average \(roundToDecimalplaces(averageMeasurement, 1)):\n"

        guard totalSamples > 0 else {
            return "Zero samples, no percentile distribution available.\n"
        }

        calculateStatistics()

        for percentile in 0 ..< percentilesToCalculate.count {
            if percentileResults[percentile] != nil {
                result += "\(percentilesToCalculate[percentile].paddedString(to: numberPadding)) <= \(percentileResults[percentile] ?? 0)μs \n"
            } else {
                result += "\(percentilesToCalculate[percentile].paddedString(to: numberPadding))  > \(1 << bucketCountPowerOfTwo)μs \n"
            }
        }

        if bucketOverflowPowerOfTwo > 0 {
            result += "Warning: discarded out of bound samples with time > \(1 << bucketCountPowerOfTwo) = \(bucketOverflowPowerOfTwo)\n"
        }

        return result
    }

    /// A printable text-based histogram+percentiles suitable for display in a fixed-size font
    /// - Returns: All collected statistics
    public mutating func output() -> String {
        percentileStatistics() + "\n" + histogramLinear() + "\n" + histogramPowerOfTwo()
    }
}

extension Int {
    func paddedString(to: Int) -> String {
        var result = String(self)
        for _ in 0 ..< (to - result.count) {
            result = " " + result
        }
        return result
    }
}

extension Double {
    func paddedString(to: Int) -> String {
        var result = String(self)
        for _ in 0 ..< (to - result.count) {
            result = " " + result
        }
        return result
    }
}

// Rounds decimals for display
public func roundToDecimalplaces(_ original: Double, _ decimals: Int = 2) -> Double {
    let factor: Double = .pow(10.0, Double(decimals))
    var original: Double = original * factor
    original.round(.toNearestOrEven)
    return original / factor
}
