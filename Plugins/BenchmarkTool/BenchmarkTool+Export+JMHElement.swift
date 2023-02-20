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

// This file was generated from JSON Schema using quicktype, do not modify it directly.
// To parse the JSON, add this file to your project and do:
//
//   let jMHJmh = try? JSONDecoder().decode(JMHJmh.self, from: jsonData)

import Foundation

// MARK: - JMHElement
struct JMHElement: Codable {
    var benchmark: String
    var mode: String
    var threads: Int
    var forks: Int
    var warmupIterations: Int
    var warmupTime: String
    var warmupBatchSize: Int
    var measurementIterations: Int
    var measurementTime: String
    var measurementBatchSize: Int
    var primaryMetric: JMHPrimaryMetric
    var secondaryMetrics: [String : JMHPrimaryMetric]?

    enum CodingKeys: String, CodingKey {
        case benchmark
        case mode
        case threads
        case forks
        case warmupIterations
        case warmupTime
        case warmupBatchSize
        case measurementIterations
        case measurementTime
        case measurementBatchSize
        case primaryMetric
        case secondaryMetrics
    }
}

// MARK: - JMHPrimaryMetric
struct JMHPrimaryMetric: Codable {
    var score: Double
    var scoreError: Double
    var scoreConfidence: [Double]
    var scorePercentiles: [String: Double]
    var scoreUnit: String
    var rawData: [[Double]]

    enum CodingKeys: String, CodingKey {
        case score
        case scoreError
        case scoreConfidence
        case scorePercentiles
        case scoreUnit
        case rawData
    }
}

// MARK: - JMHSecondaryMetrics
struct JMHSecondaryMetrics: Codable {
    var gcAllocRate: JMHPrimaryMetric
    var gcAllocRateNorm: JMHPrimaryMetric
    var gcChurnPsEdenSpace: JMHPrimaryMetric
    var gcChurnPsEdenSpaceNorm: JMHPrimaryMetric
    var gcChurnPsSurvivorSpace: JMHPrimaryMetric
    var gcChurnPsSurvivorSpaceNorm: JMHPrimaryMetric
    var gcCount: JMHGc
    var gcTime: JMHGc

    enum CodingKeys: String, CodingKey {
        case gcAllocRate
        case gcAllocRateNorm
        case gcChurnPsEdenSpace
        case gcChurnPsEdenSpaceNorm
        case gcChurnPsSurvivorSpace
        case gcChurnPsSurvivorSpaceNorm
        case gcCount
        case gcTime
    }
}

// MARK: - JMHGc
struct JMHGc: Codable {
    var score: Int
    var scoreError: String
    var scoreConfidence: [Int]
    var scorePercentiles: [String: Double]
    var scoreUnit: String
    var rawData: [[Int]]

    enum CodingKeys: String, CodingKey {
        case score
        case scoreError
        case scoreConfidence
        case scorePercentiles
        case scoreUnit
        case rawData
    }
}

typealias JMHJmh = [JMHElement]
