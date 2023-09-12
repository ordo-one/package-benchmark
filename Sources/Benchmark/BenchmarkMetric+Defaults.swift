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
    /// The default collection of metrics used for a benchmark.
    ///
    /// The defaults include ``wallClock``, ``cpuTotal``, ``mallocCountTotal``, ``throughput``, and ``peakMemoryResident``.
    ///
    /// There is also an convenience extension on Array defined such that you can write just `.default` rather than `BenchmarkMetric.default`
    ///
    static var `default`: [BenchmarkMetric] {
        [.wallClock,
         .cpuTotal,
         .mallocCountTotal,
         .throughput,
         .peakMemoryResident]
    }

    /// A collection of extended system benchmarks.
    static var extended: [BenchmarkMetric] {
        [.wallClock,
         .cpuUser,
         .cpuTotal,
         .mallocCountTotal,
         .throughput,
         .peakMemoryResident,
         .memoryLeaked,
         .syscalls]
    }

    /// A collection of memory benchmarks.
    static var memory: [BenchmarkMetric] {
        [.peakMemoryResident,
         .peakMemoryVirtual,
         .mallocCountSmall,
         .mallocCountLarge,
         .mallocCountTotal,
         .memoryLeaked,
         .allocatedResidentMemory]
    }

    /// A collection of ARC metrics
    static var arc: [BenchmarkMetric] {
        [.objectAllocCount,
         .retainCount,
         .releaseCount,
         .retainReleaseDelta]
    }

    /// A collection of system benchmarks.
    static var system: [BenchmarkMetric] {
        [.wallClock,
         .syscalls,
         .contextSwitches,
         .threads,
         .threadsRunning,
         .cpuSystem]
    }

    /// A collection of disk benchmarks.
    static var disk: [BenchmarkMetric] {
        [.readSyscalls,
         .writeSyscalls,
         .readBytesLogical,
         .writeBytesLogical,
         .readBytesPhysical,
         .writeBytesPhysical]
    }

    /// A collection of all benchmarks supported by this library.
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
         .allocatedResidentMemory,
         .objectAllocCount,
         .retainCount,
         .releaseCount,
         .retainReleaseDelta]
    }
}

// Nicer convenience extension for Array so one can write `.extended` instead of `BenchmarkMetric.extended`
public extension [BenchmarkMetric] {
    /// The default collection of metrics used for a benchmark.
    ///
    /// The defaults include ``wallClock``, ``cpuTotal``, ``mallocCountTotal``, ``throughput``, and ``peakMemoryResident``.
    static var `default`: [BenchmarkMetric] {
        BenchmarkMetric.default
    }

    /// A collection of extended system benchmarks.
    static var extended: [BenchmarkMetric] {
        BenchmarkMetric.extended
    }

    /// A collection of memory benchmarks.
    static var memory: [BenchmarkMetric] {
        BenchmarkMetric.memory
    }

    /// A collection of ARC metrics
    static var arc: [BenchmarkMetric] {
        BenchmarkMetric.arc
    }

    /// A collection of system benchmarks.
    static var system: [BenchmarkMetric] {
        BenchmarkMetric.system
    }

    /// A collection of disk benchmarks.
    static var disk: [BenchmarkMetric] {
        BenchmarkMetric.disk
    }

    /// A collection of all benchmarks supported by this library.
    static var all: [BenchmarkMetric] {
        BenchmarkMetric.all
    }
}
