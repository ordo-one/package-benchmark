//
// Copyright (c) 2023 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
///

@testable import BenchmarkSupport
import XCTest

final class BenchmarkMetricsTests: XCTestCase {
    func testBenchmarkRunner() throws {
        let metrics: [BenchmarkMetric] = [
            .cpuUser,
            .cpuSystem,
            .cpuTotal,
            .wallClock,
            .throughput,
            .peakMemoryResident,
            .peakMemoryVirtual,
            .mallocCountSmall,
            .mallocCountLarge,
            .mallocCountTotal,
            .allocatedResidentMemory,
            .memoryLeaked,
            .syscalls,
            .contextSwitches,
            .threads,
            .threadsRunning,
            .readSyscalls,
            .writeSyscalls,
            .readBytesLogical,
            .writeBytesLogical,
            .readBytesPhysical,
            .writeBytesPhysical,
            .custom("test"),
            .custom("test2", polarity: .prefersLarger, useScalingFactor: true)
        ]

        var description = ""
        var rawValues = 0
        metrics.forEach { metric in
            description += metric.description
            rawValues += metric.useScalingFactor ? 0 : 1
            rawValues += metric.countable ? 0 : 1
            rawValues += metric.polarity == .prefersLarger ? 0 : 1
        }

        XCTAssert(rawValues > 10)
        XCTAssert(description.count > 10)
    }
}
