//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

import Statistics

/// Time units for cpu/wall clock time
public enum BenchmarkTimeUnits: Int, Codable, CustomStringConvertible {
    case nanoseconds = 1_000_000_000
    case microseconds = 1_000_000
    case milliseconds = 1_000
    case seconds = 1
    case automatic // will pick time unit above automatically

    public var description: String {
        switch self {
        case .nanoseconds:
            return "ns"
        case .microseconds:
            return "μs"
        case .milliseconds:
            return "ms"
        case .seconds:
            return "s"
        case .automatic:
            return "#"
        }
    }
}

public enum BenchmarkScalingFactor: Int, Codable {
    case automatic // will pick scaling factor automatically
    case none = 1 // e.g. nanoseconds, or count
    case kilo = 1_000 // microseconds
    case mega = 1_000_000 // milliseconds
    case giga = 1_000_000_000 // seconds

    public var description: String {
        switch self {
        case .automatic:
            return "#"
        case .none:
            return "#"
        case .kilo:
            return "K"
        case .mega:
            return "M"
        case .giga:
            return "G"
        }
    }
}

// How we should scale a result for a given time unit (all results counted in nanos)
public extension BenchmarkScalingFactor {
    init(_ units:BenchmarkTimeUnits) {
        switch units {
        case .nanoseconds:
            self = .none
        case .microseconds:
            self = .kilo
        case .milliseconds:
            self = .mega
        case .seconds:
            self = .giga
        case .automatic:
            self = .automatic
        }
    }
}

public struct BenchmarkResult: Codable, Comparable, Equatable {
    
    public init(metric: BenchmarkMetric,
                timeUnits: BenchmarkTimeUnits,
                scalingFactor: BenchmarkScalingFactor,
//                measurements: Int,
                warmupIterations: Int,
                thresholds: PercentileThresholds? = nil,
//                percentiles: [Statistics.Percentile: Int],
                statistics: Statistics) {
        self.metric = metric
        self.timeUnits = timeUnits
        self.scalingFactor = scalingFactor
//        self.measurements = measurements
        self.warmupIterations = warmupIterations
        self.thresholds = thresholds
//        self.percentiles = percentiles
        self.statistics = statistics
    }

    public var metric: BenchmarkMetric
    public var timeUnits: BenchmarkTimeUnits
    public var scalingFactor: BenchmarkScalingFactor
//    public var measurements: Int
    public var warmupIterations: Int
    public var thresholds: PercentileThresholds?
//    public var percentiles: [Statistics.Percentile: Int]
    public var statistics: Statistics

    /*
    public mutating func scaleResults(to otherResult: BenchmarkResult) {
        guard timeUnits != otherResult.timeUnits else {
            return
        }
        let ratio = Double(otherResult.timeUnits.rawValue) / Double(timeUnits.rawValue)

        percentiles.forEach { percentile, value in
            self.percentiles[percentile] = Int(ratio * Double(value))
        }

        timeUnits = otherResult.timeUnits
    }
*/
    public var unitDescription: String {
        if metric.countable() {
            let statisticsUnit = Statistics.Units(timeUnits)
            if statisticsUnit == .count {
                return ""
            }
            return statisticsUnit.description
        }
        return timeUnits.description
    }

    public var unitDescriptionPretty: String {
        if metric.countable() {
            let statisticsUnit = Statistics.Units(timeUnits)
            if statisticsUnit == .count {
                return ""
            }
            return "(\(statisticsUnit.description))"
        }
        return "(\(timeUnits.description))"
    }

    public static func == (lhs: BenchmarkResult, rhs: BenchmarkResult) -> Bool {
//        var rhs = rhsRaw

        return lhs.metric == rhs.metric && lhs.statistics.histogram == rhs.statistics.histogram
/*
        rhs.scaleResults(to: lhs)

        return lhs.metric == rhs.metric &&
            lhs.timeUnits == rhs.timeUnits &&
            lhs.percentiles == rhs.percentiles */
    }

    public static func < (lhs: BenchmarkResult, rhs: BenchmarkResult) -> Bool {
//        var rhs = rhsRaw

        guard lhs.metric == rhs.metric else {
            return false
        }
        let reversedComparison = lhs.metric.polarity() == .prefersLarger

        // TODO: Should add proper comparison to Histograms instead

        if reversedComparison {
            if lhs.statistics.histogram.mean > rhs.statistics.histogram.mean {
                return true
            }
        } else {
            if lhs.statistics.histogram.mean < rhs.statistics.histogram.mean {
                return true
            }
        }

        return false
    }
/*
        rhs.scaleResults(to: lhs)

        let reversedComparison = lhs.metric.polarity() == .prefersLarger
        var allIsLess = true

        lhs.percentiles.forEach { percentile, value in
            if let rhsPercentile = rhs.percentiles[percentile] {
                if reversedComparison {
                    if value < rhsPercentile {
                        allIsLess = false
                    }
                } else {
                    if value > rhsPercentile {
                        allIsLess = false
                    }
                }
            } else {
                allIsLess = false
            }
        }

        return allIsLess
    }
*/

    // swiftlint:disable function_body_length
    public func betterResultsOrEqual(than otherResult: BenchmarkResult,
                                     thresholds: BenchmarkResult.PercentileThresholds = .default,
                                     printOutput: Bool = false) -> Bool {
        var rhs: BenchmarkResult
        var lhs: BenchmarkResult

        lhs = self
        rhs = otherResult

        guard lhs.metric == rhs.metric else {
            return false
        }

//        rhs.scaleResults(to: lhs)
        // swiftlint:disable function_parameter_count
        func worseResult(_ lhs: Int,
                         _ rhs: Int,
                         _ percentile: Statistics.Percentile,
                         _ thresholds: BenchmarkResult.PercentileThresholds,
                         _ scalingFactor: Int,
                         _ printOutput: Bool) -> Bool {
            let relativeDifference = (100 - (100.0 * Double(lhs) / Double(rhs)))
            let absoluteDifference = lhs - rhs
            let reverseComparison = metric.polarity() == .prefersLarger

            var thresholdViolated = false

            if let threshold = thresholds.relative[percentile] {
                if reverseComparison ? relativeDifference > threshold : -relativeDifference > threshold {
                    if printOutput {
                        print("`\(metric.description)` relative threshold violated, [\(percentile)] result" +
                              " (\(Statistics.roundToDecimalplaces(abs(relativeDifference), 1))) > threshold (\(threshold))")
                    }
                    thresholdViolated = true
                }
            }

            if var threshold = thresholds.absolute[percentile] {
                threshold /= (1_000_000_000 / scalingFactor)
                if reverseComparison ? -absoluteDifference > threshold : absoluteDifference > threshold {
                    if printOutput {
                        print("`\(metric.description)` absolute threshold violated, [\(percentile)] result" +
                            " (\(abs(absoluteDifference))) > threshold (\(threshold))")
                    }
                    thresholdViolated = true
                }
            }
            return thresholdViolated
        }

// TODO: Should compare actual percentiles in use here instead

        if lhs.statistics.histogram.mean < rhs.statistics.histogram.mean {
            return false
        }
        /*
        var worse = false
        let percentiles = lhs.statistics.percentiles

        percentiles.forEach { lhsPercentile in
            if let rhsPercentile = rhs.percentiles[percentile] {
                worse = worseResult(lhsPercentile,
                                    rhsPercentile,
                                    percentile,
                                    thresholds,
                                    lhs.timeUnits.rawValue,
                                    printOutput) || worse
            } else {
                print("\(rhs.metric) missing value for percentile \(percentile), skipping it.")
            }
        }

        if worse {
            return false
        }
*/
        return true
    }
}

public extension Statistics.Units {
    init(_ timeUnits: BenchmarkTimeUnits) {
        switch timeUnits {
        case .nanoseconds:
            self = .count
        case .microseconds:
            self = .kilo
        case .milliseconds:
            self = .mega
        case .seconds:
            self = .giga
        case .automatic:
            self = .automatic
        }
    }
}

public extension Statistics.Units {
    init(_ timeUnits: BenchmarkTimeUnits?) {
        switch timeUnits {
        case .nanoseconds:
            self = .count
        case .microseconds:
            self = .kilo
        case .milliseconds:
            self = .mega
        case .seconds:
            self = .giga
        case .automatic:
            self = .automatic
        case .none:
            self = .count
        }
    }
}

public extension BenchmarkTimeUnits {
    init(_ timeUnits: Statistics.Units) {
        switch timeUnits {
        case .count:
            self = .nanoseconds
        case .kilo:
            self = .microseconds
        case .mega:
            self = .milliseconds
        case .giga:
            self = .seconds
        case .automatic:
            self = .automatic
        }
    }
}
