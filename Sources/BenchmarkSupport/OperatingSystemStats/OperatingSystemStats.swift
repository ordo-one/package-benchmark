//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

/// The  stats that the OperatingSystemStatsProducer can provide
public struct OperatingSystemStats {
    /// CPU user space time spent for running the test
    var cpuUser: Int = 0
    /// CPU system time spent for running the test
    var cpuSystem: Int = 0
    /// CPU total time spent for running the test (system + user)
    var cpuTotal: Int = 0
    /// Measure resident memory usage - sampled during runtime
    var peakMemoryResident: Int = 0
    /// Measure virtual memory usage - sampled during runtime
    var peakMemoryVirtual: Int = 0
    /// Measure number of syscalls made during the test
    var syscalls: Int = 0
    /// Measure number of context switches made during the test
    var contextSwitches: Int = 0
    /// Sample the maximum number of threads in the process under the test (not exact)
    var threads: Int = 0
    /// Sample the maximum number of threads actually running under the test (not exact)
    var threadsRunning: Int = 0
    /// The number of I/O read syscalls performed e.g. read(2) / pread(2) -- Linux only
    var readSyscalls: Int = 0
    /// The number of I/O write syscalls performed e.g. write(2) / pwrite(2) -- Linux only
    var writeSyscalls: Int = 0
    /// The number of bytes read from storage (but may be satisfied by pagecache!) -- Linux only
    var readBytesLogical: Int = 0
    /// The number bytes written to storage (but may be cached) -- Linux only
    var writeBytesLogical: Int = 0
    /// The number of bytes physically read from a block device (i.e. disk) -- Linux only
    var readBytesPhysical: Int = 0
    /// The number of bytes physicall written to a block device (i.e. disk) -- Linux only
    var writeBytesPhysical: Int = 0
}
