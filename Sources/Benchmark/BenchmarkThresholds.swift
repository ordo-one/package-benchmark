//
// Copyright (c) 2023 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

/// Definitions of benchmark thresholds per metric
public struct BenchmarkThresholds: Codable {
    public typealias RelativeThreshold = Double
    public typealias AbsoluteThreshold = Int

    public typealias RelativeThresholds = [BenchmarkResult.Percentile: RelativeThreshold]
    public typealias AbsoluteThresholds = [BenchmarkResult.Percentile: AbsoluteThreshold]

    /// Initializing BenchmarkThresholds
    /// - Parameters:
    ///   - relative: A dictionary with relative thresholds per percentile (using for delta comparisons)
    ///   - absolute: A dictionary with absolute thresholds per percentile (used both for delta and absolute comparisons)
    public init(relative: RelativeThresholds = Self.Relative.none,
                absolute: AbsoluteThresholds = Self.Absolute.none) {
        self.relative = relative
        self.absolute = absolute
    }

    let relative: RelativeThresholds
    let absolute: AbsoluteThresholds
}
