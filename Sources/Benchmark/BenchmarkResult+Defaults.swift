//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

// Convenience sets of benchmark result comparisons, these define
// the allowed deviation from the comparison baseline to a benchmark
// comparison to succeed, both in relative and absolute terms.

// swiftlint:disable discouraged_none_name
// swiftlint:disable identifier_name

public extension BenchmarkResult {
    typealias PercentileRelativeThreshold = Double
    typealias PercentileAbsoluteThreshold = Int
    typealias PercentileRelativeThresholds = [BenchmarkResult.Percentile: PercentileRelativeThreshold]
    typealias PercentileAbsoluteThresholds = [BenchmarkResult.Percentile: PercentileAbsoluteThreshold]

    struct PercentileThresholds: Codable {
        public init(relative: BenchmarkResult.PercentileRelativeThresholds = .none,
                    absolute: BenchmarkResult.PercentileAbsoluteThresholds = .none) {
            self.relative = relative
            self.absolute = absolute
        }

        let relative: PercentileRelativeThresholds
        let absolute: PercentileAbsoluteThresholds
    }

    enum Percentile: Codable {
        case p0
        case p25
        case p50
        case p75
        case p90
        case p99
        case p100
    }
}

public extension BenchmarkResult.PercentileRelativeThresholds {
    // The allowed regression per percentile in percent (e.g. '0.2% regression ok for .p25')
    static var strict: BenchmarkResult.PercentileRelativeThresholds {
        [.p25: 0.0,
         .p50: 0.0,
         .p75: 0.0,
         .p90: 0.0,
         .p99: 0.0]
    }

    static var `default`: BenchmarkResult.PercentileRelativeThresholds {
        [.p25: 5.0,
         .p50: 5.0,
         .p75: 5.0]
    }

    static var relaxed: BenchmarkResult.PercentileRelativeThresholds {
        [.p50: 25.0]
    }

    static var none: BenchmarkResult.PercentileRelativeThresholds {
        [:]
    }
}

public extension BenchmarkResult.PercentileAbsoluteThresholds {
    // The allowed regression for a given percentile in absolute numbers (e.g. '25 regression ok for .p25')
    // Useful for e.g. malloc counters
    static var strict: BenchmarkResult.PercentileAbsoluteThresholds {
        [.p0: 0,
         .p25: 0,
         .p50: 0,
         .p75: 0,
         .p90: 0,
         .p99: 0]
    }

    static var `default`: BenchmarkResult.PercentileAbsoluteThresholds {
        [:]
    }

    static var relaxed: BenchmarkResult.PercentileAbsoluteThresholds {
        [.p0: 10_000,
         .p25: 10_000,
         .p50: 10_000,
         .p75: 10_000,
         .p90: 10_000,
         .p99: 10_000,
         .p100: 10_000]
    }

    static var none: BenchmarkResult.PercentileAbsoluteThresholds {
        [:]
    }
}

public extension BenchmarkResult.PercentileThresholds {
    static var strict: BenchmarkResult.PercentileThresholds {
        BenchmarkResult.PercentileThresholds(relative: BenchmarkResult.PercentileRelativeThresholds.strict,
                                             absolute: BenchmarkResult.PercentileAbsoluteThresholds.strict)
    }

    static var `default`: BenchmarkResult.PercentileThresholds {
        BenchmarkResult.PercentileThresholds(relative: BenchmarkResult.PercentileRelativeThresholds.default,
                                             absolute: BenchmarkResult.PercentileAbsoluteThresholds.default)
    }

    static var relaxed: BenchmarkResult.PercentileThresholds {
        BenchmarkResult.PercentileThresholds(relative: BenchmarkResult.PercentileRelativeThresholds.relaxed,
                                             absolute: BenchmarkResult.PercentileAbsoluteThresholds.relaxed)
    }

    static var none: BenchmarkResult.PercentileThresholds {
        BenchmarkResult.PercentileThresholds()
    }
}

// Convenience functions for defining absolute thresholds
public extension BenchmarkResult.PercentileAbsoluteThreshold {
    static func hours(_ hours: Int) -> BenchmarkResult.PercentileAbsoluteThreshold {
        hours * 1_000_000_000 * 60 * 60
    }

    static func minutes(_ minutes: Int) -> BenchmarkResult.PercentileAbsoluteThreshold {
        minutes * 1_000_000_000 * 60
    }

    static func seconds(_ seconds: Int) -> BenchmarkResult.PercentileAbsoluteThreshold {
        seconds * 1_000_000_000
    }

    static func milliseconds(_ milliseconds: Int) -> BenchmarkResult.PercentileAbsoluteThreshold {
        milliseconds * 1_000_000
    }

    static func microseconds(_ microseconds: Int) -> BenchmarkResult.PercentileAbsoluteThreshold {
        microseconds * 1_000
    }

    static func nanoseconds(_ value: Int) -> BenchmarkResult.PercentileAbsoluteThreshold {
        value
    }

    static func nanoseconds(_ value: UInt) -> BenchmarkResult.PercentileAbsoluteThreshold {
        Int(value)
    }

    static func giga(_ value: Int) -> BenchmarkResult.PercentileAbsoluteThreshold {
        value * 1_000_000_000
    }

    static func mega(_ value: Int) -> BenchmarkResult.PercentileAbsoluteThreshold {
        value * 1_000_000
    }

    static func kilo(_ value: Int) -> BenchmarkResult.PercentileAbsoluteThreshold {
        value * 1_000
    }

    static func count(_ value: Int) -> BenchmarkResult.PercentileAbsoluteThreshold {
        value
    }

    static func count(_ value: UInt) -> BenchmarkResult.PercentileAbsoluteThreshold {
        Int(value)
    }
}
