//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

// swiftlint: disable file_length

import Statistics

/// Time units for cpu/wall clock time
public enum BenchmarkTimeUnits: Int, Codable, CustomStringConvertible {
    case nanoseconds = 1_000_000_000
    case microseconds = 1_000_000
    case milliseconds = 1_000
    case seconds = 1
    case automatic // will pick time unit above automatically

    /// Divisor of raw data to the desired time unit representation
    public var divisor: Int {
        switch self {
        case .nanoseconds:
            return 1
        case .microseconds:
            return 1_000
        case .milliseconds:
            return 1_000_000
        case .seconds:
            return 1_000_000_000
        case .automatic:
            fatalError("Should never extract scalingFactor for .automatic")
        }
    }

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

/// The scaling factor for benchmark iterations.
///
/// Typically used for very fast-running benchmarks.
/// In those cases, the time to measure the benchmark can impact as much as the time to run the code being benchmarked.
/// Use a scaling factor when running your short benchmarks to provide greater numerical stability to the results.
public enum BenchmarkScalingFactor: Int, Codable {
    /// No scaling factor, the raw count of iterations.
    case one = 1 // e.g. nanoseconds, or count
    /// Scaling factor of 1e03.
    case kilo = 1_000 // microseconds
    /// Scaling factor of 1e06.
    case mega = 1_000_000 // milliseconds
    /// Scaling factor of 1e09.
    case giga = 1_000_000_000 // seconds
    /// Scaling factor of 1e12.
    case tera = 1_000_000_000_000 // 1K seconds
    /// Scaling factor of 1e15.
    case peta = 1_000_000_000_000_000 // 1M

    public var description: String {
        switch self {
        case .one:
            return "#"
        case .kilo:
            return "K"
        case .mega:
            return "M"
        case .giga:
            return "G"
        case .tera:
            return "T"
        case .peta:
            return "P"
        }
    }
}

// How we should scale a result for a given time unit (all results counted in nanos)
public extension BenchmarkScalingFactor {
    init(_ units: BenchmarkTimeUnits) {
        switch units {
        case .automatic, .nanoseconds:
            self = .one
        case .microseconds:
            self = .kilo
        case .milliseconds:
            self = .mega
        case .seconds:
            self = .giga
        }
    }
}

// swiftlint:disable type_body_length

#if swift(>=5.8)
    @_documentation(visibility: internal)
#endif
public struct BenchmarkResult: Codable, Comparable, Equatable {
    public init(metric: BenchmarkMetric,
                timeUnits: BenchmarkTimeUnits,
                scalingFactor: BenchmarkScalingFactor,
                warmupIterations: Int,
                thresholds: PercentileThresholds? = nil,
                statistics: Statistics) {
        self.metric = metric
        self.timeUnits = timeUnits == .automatic ? BenchmarkTimeUnits(statistics.units()) : timeUnits
        self.scalingFactor = scalingFactor
        self.warmupIterations = warmupIterations
        self.thresholds = thresholds
        self.statistics = statistics
    }

    public var metric: BenchmarkMetric
    public var timeUnits: BenchmarkTimeUnits
    public var scalingFactor: BenchmarkScalingFactor
    public var warmupIterations: Int
    public var thresholds: PercentileThresholds?
    public var statistics: Statistics

    public var scaledTimeUnits: BenchmarkTimeUnits {
        switch timeUnits {
        case .nanoseconds:
            return .nanoseconds
        case .microseconds:
            switch scalingFactor {
            case .one:
                return .microseconds
            default:
                return .nanoseconds
            }
        case .milliseconds:
            switch scalingFactor {
            case .one:
                return .milliseconds
            case .kilo:
                return .microseconds
            default:
                return .nanoseconds
            }
        case .seconds:
            switch scalingFactor {
            case .one:
                return .seconds
            case .kilo:
                return .milliseconds
            case .mega:
                return .microseconds
            case .giga:
                return .nanoseconds
            case .tera, .peta: // shouldn't be possible as tera is only used internally to present scaled up throughput
                break
            }
        default:
            break
        }

        fatalError("scaledTimeUnits: \(scalingFactor), \(timeUnits)")
    }

    public var scaledScalingFactor: BenchmarkScalingFactor {
        guard metric == .throughput else {
            return scalingFactor
        }

        let timeUnitsMagnitude = Int(Double.log10(Double(timeUnits.divisor)))
        let scalingFactorMagnitude = Int(Double.log10(Double(scalingFactor.rawValue)))
        let totalMagnitude = timeUnitsMagnitude + scalingFactorMagnitude
        let newScale = pow(10, totalMagnitude)

        return BenchmarkScalingFactor(rawValue: newScale)!
    }

    // swiftlint:disable identifier_name
    // from SO to avoid Foundation/Numerics
    internal func pow<T: BinaryInteger>(_ base: T, _ power: T) -> T {
        func expBySq(_ y: T, _ x: T, _ n: T) -> T {
            precondition(n >= 0)
            if n == 0 {
                return y
            } else if n == 1 {
                return y * x
            } else if n.isMultiple(of: 2) {
                return expBySq(y, x * x, n / 2)
            } else { // n is odd
                return expBySq(y * x, x * x, (n - 1) / 2)
            }
        }

        return expBySq(1, base, power)
    }

    internal var remainingScalingFactor: BenchmarkScalingFactor {
        guard statistics.timeUnits == .automatic else {
            return scalingFactor
        }
        guard timeUnits != scaledTimeUnits else {
            return scalingFactor
        }
        let timeUnitsMagnitude = Int(Double.log10(Double(timeUnits.rawValue)))
        let scaledTimeUnitsMagnitude = Int(Double.log10(Double(scaledTimeUnits.rawValue)))
        let scalingFactorMagnitude = Int(Double.log10(Double(scalingFactor.rawValue)))
        let magnitudeDelta = scalingFactorMagnitude - (scaledTimeUnitsMagnitude - timeUnitsMagnitude)

        guard magnitudeDelta >= 0 else {
            fatalError("\(magnitudeDelta) \(scalingFactorMagnitude) \(scaledTimeUnitsMagnitude) \(timeUnitsMagnitude)")
        }
        let newScale = pow(10, magnitudeDelta)

        return BenchmarkScalingFactor(rawValue: newScale)!
    }

    // Scale a value according to timeunit/scaling factors in play
    public func scale(_ value: Int) -> Int {
        if metric == .throughput {
            return normalize(value)
        }
        return normalize(value) / remainingScalingFactor.rawValue
    }

    // Scale a value to the appropriate unit (from ns/count -> )
    public func normalize(_ value: Int) -> Int {
        value / timeUnits.divisor
    }

    public func normalizeCompare(_ value: Int) -> Int {
        value / timeUnits.rawValue
    }

    public var unitDescription: String {
        if metric.countable {
            let statisticsUnit = Statistics.Units(timeUnits)
            if statisticsUnit == .count {
                return ""
            }
            return statisticsUnit.description
        }
        return timeUnits.description
    }

    public var unitDescriptionPretty: String {
        if metric.countable {
            let statisticsUnit = Statistics.Units(timeUnits)
            if statisticsUnit == .count {
                return ""
            }
            return "(\(statisticsUnit.description))"
        }
        return "(\(timeUnits.description))"
    }

    public var scaledUnitDescriptionPretty: String {
        if metric == .throughput {
            if scalingFactor == .one {
                return "*"
            }
            return "(\(scaledScalingFactor.description)) *"
        }
        if metric.countable {
            let statisticsUnit = Statistics.Units(scaledTimeUnits)
            if statisticsUnit == .count {
                return "*"
            }
            return "(\(statisticsUnit.description)) *"
        }
        return statistics.timeUnits == .automatic ?
            "(\(scaledTimeUnits.description)) *" : "(\(timeUnits.description)) *"
    }

    public static func == (lhs: BenchmarkResult, rhs: BenchmarkResult) -> Bool {
        guard lhs.metric == rhs.metric else {
            return false
        }

        if lhs.statistics.measurementCount != rhs.statistics.measurementCount {
            return false
        }

        let lhsPercentiles = lhs.statistics.percentiles()
        let rhsPercentiles = rhs.statistics.percentiles()

        for percentile in 0 ..< lhsPercentiles.count where
            lhs.normalizeCompare(lhsPercentiles[percentile]) != rhs.normalizeCompare(rhsPercentiles[percentile]) {
            return false
        }

        return true
    }

    public static func < (lhs: BenchmarkResult, rhs: BenchmarkResult) -> Bool {
        let reversedComparison = lhs.metric.polarity == .prefersLarger

        guard lhs.metric == rhs.metric else {
            return false
        }

        let lhsPercentiles = lhs.statistics.percentiles()
        let rhsPercentiles = rhs.statistics.percentiles()

        if reversedComparison {
            for percentile in 0 ..< lhsPercentiles.count where
                lhs.normalizeCompare(lhsPercentiles[percentile]) < rhs.normalizeCompare(rhsPercentiles[percentile]) {
                return false
            }
        } else {
            for percentile in 0 ..< lhsPercentiles.count where
                lhs.normalizeCompare(lhsPercentiles[percentile]) > rhs.normalizeCompare(rhsPercentiles[percentile]) {
                return false
            }
        }

        return true
    }

    public struct ThresholdDeviation {
        public let name: String
        public let target: String
        public let metric: BenchmarkMetric
        public let percentile: BenchmarkResult.Percentile
        public let baseValue: Int
        public let comparisonValue: Int
        public let difference: Int
        public let differenceThreshold: Int
        public let relative: Bool
        public let units: Statistics.Units
    }

    // swiftlint:disable function_body_length
    public func betterResultsOrEqual(than otherResult: BenchmarkResult,
                                     thresholds: BenchmarkResult.PercentileThresholds = .default,
                                     name: String = "unknown name",
                                     target: String = "unknown target") -> (Bool, [ThresholdDeviation]) {
        var violationDescriptions: [ThresholdDeviation] = []
        var rhs: BenchmarkResult
        var lhs: BenchmarkResult

        lhs = self
        rhs = otherResult

        guard lhs.metric == rhs.metric else {
            fatalError("Tried to compare two different metrics \(lhs.metric) - \(rhs.metric)")
        }

        // swiftlint:disable function_parameter_count
        func worseResult(_ metric: BenchmarkMetric,
                         _ lhs: Int,
                         _ rhs: Int,
                         _ percentile: BenchmarkResult.Percentile,
                         _ thresholds: BenchmarkResult.PercentileThresholds,
                         _ scalingFactor: Statistics.Units) -> (Bool, [ThresholdDeviation]) {
            let relativeDifference = rhs != 0 ? (100 - (100.0 * Double(lhs) / Double(rhs))) : 0.0
            let absoluteDifference = lhs - rhs
            let reverseComparison = metric.polarity == .prefersLarger
            var violationDescriptions: [ThresholdDeviation] = []
            var thresholdViolated = false

            if let threshold = thresholds.relative[percentile] {
                if reverseComparison ? relativeDifference > threshold : -relativeDifference > threshold {
                    let relativeDiff = Statistics.roundToDecimalplaces(abs(relativeDifference), 1)
                    violationDescriptions.append(ThresholdDeviation(name: name,
                                                                    target: target,
                                                                    metric: metric,
                                                                    percentile: percentile,
                                                                    baseValue: normalize(lhs),
                                                                    comparisonValue: normalize(rhs),
                                                                    difference: Int(relativeDiff),
                                                                    differenceThreshold: Int(threshold),
                                                                    relative: true,
                                                                    units: scalingFactor))
                    thresholdViolated = true
                }
            }

            if var threshold = thresholds.absolute[percentile] {
                threshold /= (1_000_000_000 / scalingFactor.rawValue)
                if reverseComparison ? -absoluteDifference > threshold : absoluteDifference > threshold {
                    violationDescriptions.append(ThresholdDeviation(name: name,
                                                                    target: target,
                                                                    metric: metric,
                                                                    percentile: percentile,
                                                                    baseValue: normalize(lhs),
                                                                    comparisonValue: normalize(rhs),
                                                                    difference: normalize(absoluteDifference),
                                                                    differenceThreshold: threshold,
                                                                    relative: false,
                                                                    units: scalingFactor))
                    thresholdViolated = true
                }
            }
            return (thresholdViolated, violationDescriptions)
        }

        let lhsPercentiles = lhs.statistics.percentiles()
        let rhsPercentiles = rhs.statistics.percentiles()
        var worse = false

        for percentile in 0 ..< lhsPercentiles.count {
            let (lastCheck, failureDescriptions) = worseResult(lhs.metric,
                                                               lhsPercentiles[percentile],
                                                               rhsPercentiles[percentile],
                                                               Self.Percentile(rawValue: percentile)!,
                                                               thresholds,
                                                               lhs.statistics.units())
            violationDescriptions.append(contentsOf: failureDescriptions)
            worse = lastCheck || worse
        }

        return (worse == false, violationDescriptions)
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
