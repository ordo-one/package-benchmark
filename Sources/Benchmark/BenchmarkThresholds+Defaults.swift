//
// Copyright (c) 2023 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

// swiftlint: disable discouraged_none_name

/// Convenience benchmark relative thresholds
public extension BenchmarkThresholds {
    enum Relative {
        // The allowed regression per percentile in percent (e.g. '0.2% regression ok for .p25')
        public static var strict: RelativeThresholds {
            [.p25: 0.0,
             .p50: 0.0,
             .p75: 0.0,
             .p90: 0.0,
             .p99: 0.0]
        }

        public static var `default`: RelativeThresholds {
            [.p25: 5.0,
             .p50: 5.0,
             .p75: 5.0]
        }

        public static var relaxed: RelativeThresholds {
            [.p50: 25.0]
        }

        public static var none: RelativeThresholds {
            [:]
        }
    }
}

/// Convenience benchmark absolute thresholds
public extension BenchmarkThresholds {
    enum Absolute {
        // The tolerance for a given percentile in absolute numbers (e.g. '25 regression ok for .p25')
        // Useful for e.g. malloc counters
        public static var strict: AbsoluteThresholds {
            [.p0: 0,
             .p25: 0,
             .p50: 0,
             .p75: 0,
             .p90: 0,
             .p99: 0]
        }

        public static var `default`: AbsoluteThresholds {
            [:]
        }

        public static var relaxed: AbsoluteThresholds {
            [.p0: 10_000,
             .p25: 10_000,
             .p50: 10_000,
             .p75: 10_000,
             .p90: 10_000,
             .p99: 10_000,
             .p100: 10_000]
        }

        public static var none: AbsoluteThresholds {
            [:]
        }
    }
}

public extension BenchmarkThresholds {
    static var strict: BenchmarkThresholds {
        BenchmarkThresholds(relative: BenchmarkThresholds.Relative.strict,
                            absolute: BenchmarkThresholds.Absolute.strict)
    }

    static var `default`: BenchmarkThresholds {
        BenchmarkThresholds(relative: BenchmarkThresholds.Relative.default,
                            absolute: BenchmarkThresholds.Absolute.default)
    }

    static var relaxed: BenchmarkThresholds {
        BenchmarkThresholds(relative: BenchmarkThresholds.Relative.relaxed,
                            absolute: BenchmarkThresholds.Absolute.relaxed)
    }

    static var none: BenchmarkThresholds {
        BenchmarkThresholds()
    }
}

// swiftlint:enable discouraged_none_name
