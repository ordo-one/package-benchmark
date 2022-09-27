//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

// Convenience sets of metrics
public extension BenchmarkMetric {
    static var `default`: [BenchmarkMetric] {
        [.wallClock,
         .cpuTotal,
         .mallocCountTotal,
         .throughput,
         .peakMemoryResident]
    }

    static var extended: [BenchmarkMetric] {
        [.wallClock,
         .cpuTotal,
         .mallocCountTotal,
         .throughput,
         .peakMemoryResident,
         .memoryLeaked,
         .syscalls]
    }

    static var memory: [BenchmarkMetric] {
        [.peakMemoryResident,
         .peakMemoryVirtual,
         .mallocCountSmall,
         .mallocCountLarge,
         .mallocCountTotal,
         .memoryLeaked,
         .allocatedResidentMemory]
    }

    static var system: [BenchmarkMetric] {
        [.wallClock,
         .syscalls,
         .contextSwitches,
         .threads,
         .threadsRunning,
         .cpuSystem]
    }

    static var disk: [BenchmarkMetric] {
        [.readSyscalls,
         .writeSyscalls,
         .readBytesLogical,
         .writeBytesLogical,
         .readBytesPhysical,
         .writeBytesPhysical]
    }

    static var all: [BenchmarkMetric] {
        [.cpuUser,
         .cpuSystem,
         .cpuTotal,
         .wallClock,
         .throughput,
         .peakMemoryResident,
         .peakMemoryVirtual,
         .mallocCountSmall,
         .mallocCountLarge,
         .mallocCountTotal,
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
         .allocatedResidentMemory]
    }
}
