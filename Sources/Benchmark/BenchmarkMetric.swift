//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

/// Supported benchmark metrics, some are only available on macOS, some on Linux, but all can be specified to share
/// benchmarks across platforms easily - the results will just be filtered out as needed.
public enum BenchmarkMetric: Hashable, Equatable, Codable, CustomStringConvertible {
    /// CPU user space time spent for running the test
    case cpuUser
    /// CPU system time spent for running the test
    case cpuSystem
    /// CPU total time spent for running the test (system + user)
    case cpuTotal
    /// Wall clock time for running the test
    case wallClock
    /// Operations / second, `.prefersLarger`
    case throughput
    /// Measure resident memory usage - sampled during runtime
    case peakMemoryResident
    /// Measure virtual memory usage - sampled during runtime
    case peakMemoryVirtual
    /// Number of small malloc calls
    case mallocCountSmall
    /// Number of large malloc calls
    case mallocCountLarge
    /// Number of small+large mallocs
    case mallocCountTotal
    /// The amount of allocated resident memory according to the memory allocator
    /// by the application (does not include metadata overhead etc)
    case allocatedResidentMemory
    /// Number of small+large mallocs - small+large frees in resident memory
    case memoryLeaked
    /// Measure number of syscalls made during the test
    case syscalls
    /// Measure number of context switches made during the test
    case contextSwitches
    /// Sample the maximum number of threads in the process under the test (not exact)
    case threads
    /// Sample the maximum number of threads actually running under the test (not exact)
    case threadsRunning
    /// The number of I/O read syscalls performed e.g. read(2) / pread(2) -- Linux only
    case readSyscalls
    /// The number of I/O write syscalls performed e.g. write(2) / pwrite(2) -- Linux only
    case writeSyscalls
    /// The number of bytes read from storage (but may be satisfied by pagecache!) -- Linux only
    case readBytesLogical
    /// The number bytes written to storage (but may be cached) -- Linux only
    case writeBytesLogical
    /// The number of bytes physically read from a block device (i.e. disk) -- Linux only
    case readBytesPhysical
    /// The number of bytes physicall written to a block device (i.e. disk) -- Linux only
    case writeBytesPhysical
    /// Custom metric
    case custom(_ name: String, polarity: Polarity = .prefersSmaller)

    /// Used internally as placeholders for formatting deltas in an easy way, please don't use
    case delta
    case deltaPercentage
}

public extension BenchmarkMetric {
    enum Polarity: Codable { // same naming as XCTest uses, polarity is known for all metrics except custom
        case prefersLarger
        case prefersSmaller
    }
}

public extension BenchmarkMetric {
    // True if the metric is countable (otherwise it's a time/throughput unit)
    func countable() -> Bool {
        switch self {
        case .cpuUser:
            return false
        case .cpuSystem:
            return false
        case .cpuTotal:
            return false
        case .wallClock:
            return false
        default:
            return true
        }
    }

    func polarity() -> BenchmarkMetric.Polarity {
        switch self {
        case .throughput:
            return .prefersLarger
        case let .custom(_, polarity):
            return polarity
        default:
            return .prefersSmaller
        }
    }

    var description: String {
        switch self {
        case .cpuUser:
            return "Time (user CPU)"
        case .cpuSystem:
            return "Time (system CPU)"
        case .cpuTotal:
            return "Time (total CPU)"
        case .wallClock:
            return "Time (wall clock)"
        case .throughput:
            return "Throughput (scaled / s)"
        case .peakMemoryResident:
            return "Memory (resident peak)"
        case .peakMemoryVirtual:
            return "Memory (virtual peak)"
        case .mallocCountSmall:
            return "Malloc (small)"
        case .mallocCountLarge:
            return "Malloc (large)"
        case .mallocCountTotal:
            return "Malloc (total)"
        case .allocatedResidentMemory:
            return "Memory (allocated)"
        case .memoryLeaked:
            return "Malloc / free Δ"
        case .syscalls:
            return "Syscalls (total)"
        case .contextSwitches:
            return "Context switches"
        case .threads:
            return "Threads (peak)"
        case .threadsRunning:
            return "Threads (running)"
        case .readSyscalls:
            return "Syscalls (read)"
        case .writeSyscalls:
            return "Syscalls (write)"
        case .readBytesLogical:
            return "Bytes (read logical)"
        case .writeBytesLogical:
            return "Bytes (write logical)"
        case .readBytesPhysical:
            return "Bytes (read physical)"
        case .writeBytesPhysical:
            return "Bytes (write physical)"
        case .delta:
            return "Δ"
        case .deltaPercentage:
            return "Δ %"
        case let .custom(name, _):
            return name
        }
    }
}
