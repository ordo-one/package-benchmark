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
import XCTest

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#else
    #error("Unsupported Platform")
#endif

final class OperatingSystemAndMallocTests: XCTestCase {
    func testOperatingSystemStatsProducer() throws {
        let operatingSystemStatsProducer = OperatingSystemStatsProducer()
        operatingSystemStatsProducer.startSampling(1)
        let startOperatingSystemStats = operatingSystemStatsProducer.makeOperatingSystemStats()
        for outerloop in 0 ..< 100 {
            for innerloop in 0 ..< 10 {
                blackHole(outerloop * outerloop * outerloop * innerloop * innerloop)
                usleep(1)
                blackHole(malloc(1))
            }
        }
        let stopOperatingSystemStats = operatingSystemStatsProducer.makeOperatingSystemStats()
        operatingSystemStatsProducer.stopSampling()
        XCTAssert(stopOperatingSystemStats.cpuTotal >= startOperatingSystemStats.cpuTotal)
        XCTAssert(stopOperatingSystemStats.cpuUser >= startOperatingSystemStats.cpuUser)
        XCTAssert(stopOperatingSystemStats.cpuSystem >= startOperatingSystemStats.cpuSystem)
        XCTAssert(stopOperatingSystemStats.peakMemoryResident >= startOperatingSystemStats.peakMemoryResident)
        XCTAssert(stopOperatingSystemStats.peakMemoryVirtual >= startOperatingSystemStats.peakMemoryVirtual)
    }

    func testOperatingSystemStatsProducerMetricSupported() throws {
        let operatingSystemStatsProducer = OperatingSystemStatsProducer()
        blackHole(operatingSystemStatsProducer.metricSupported(.throughput))
        blackHole(operatingSystemStatsProducer.metricSupported(.syscalls))
        blackHole(operatingSystemStatsProducer.metricSupported(.threadsRunning))
        blackHole(operatingSystemStatsProducer.metricSupported(.threads))
        blackHole(operatingSystemStatsProducer.metricSupported(.writeSyscalls))
        blackHole(operatingSystemStatsProducer.metricSupported(.writeBytesLogical))
        blackHole(operatingSystemStatsProducer.metricSupported(.writeBytesPhysical))
        blackHole(operatingSystemStatsProducer.metricSupported(.throughput))
    }

    func testMallocProducerLeaks() throws {
        let mallocStatsProducer = MallocStatsProducer()
        let startMallocStats = mallocStatsProducer.makeMallocStats()

        for outerloop in 1 ... 100 {
            blackHole(malloc(outerloop * 1_024))
        }

        let stopMallocStats = mallocStatsProducer.makeMallocStats()

        XCTAssert(stopMallocStats.mallocCountTotal - startMallocStats.mallocCountTotal >= 100)
        XCTAssert(stopMallocStats.allocatedResidentMemory - startMallocStats.allocatedResidentMemory >= 100 * 1_024)
    }
}
