//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

/// Metrics supported by benchmark.
///
/// Some metrics are only available on macOS or Linux, but you can specify all the metrics without worrying about platform availability.
/// If a metric is unavailable on a specific platform, the Benchmark system filters unsupported metrics out as needed.
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
    /// Number of object allocations (implicit retain of one) (ARC)
    case objectAllocCount
    /// Number of retains (ARC)
    case retainCount
    /// Number of releases (ARC)
    case releaseCount
    /// ABS(retains-releases) - if this is non-zero, it would typically mean the benchmark has a retain cycle (use Memory Graph Debugger to troubleshoot) or that startMeasurement/stopMeasurement aren't used properly
    case retainReleaseDelta
    /// Custom metric
    case custom(_ name: String, polarity: Polarity = .prefersSmaller, useScalingFactor: Bool = true)

    /// Used internally as placeholders for formatting deltas in an easy way, please don't use
    #if swift(>=5.8)
        @_documentation(visibility: internal)
    #endif
    case delta
    #if swift(>=5.8)
        @_documentation(visibility: internal)
    #endif
    case deltaPercentage
}

// We don't want to take polarity and useScalingFactor into consideration as it makes dealing with custom metrics hard
#if swift(>=5.8)
    @_documentation(visibility: internal)
#endif
public extension BenchmarkMetric {
    func hash(into hasher: inout Hasher) {
        hasher.combine(description)
    }

    static func == (lhs: BenchmarkMetric, rhs: BenchmarkMetric) -> Bool {
        lhs.description == rhs.description
    }
}

public extension BenchmarkMetric {
    /// A constant that states whether larger or smaller measurements, relative to a set baseline, indicate better performance.
    enum Polarity: Codable { // same naming as XCTest uses, polarity is known for all metrics except custom
        /// A performance measurement where a larger value, relative to a set baseline, indicates better performance.
        case prefersLarger
        /// A performance measurement where a smaller value, relative to a set baseline, indicates better performance.
        case prefersSmaller
    }
}

public extension BenchmarkMetric {
    // True if the metric is countable (otherwise it's a time/throughput unit)
    var countable: Bool {
        switch self {
        case .cpuSystem, .cpuTotal, .cpuUser, .wallClock:
            return false
        default:
            return true
        }
    }

    /// True if this metric should be scaled to the scalingFactor if looking at scaled output.
    var useScalingFactor: Bool {
        switch self {
        case .cpuSystem, .cpuTotal, .cpuUser, .wallClock:
            return true
        case .mallocCountLarge, .mallocCountSmall, .mallocCountTotal, .memoryLeaked:
            return true
        case .syscalls, .throughput:
            return true
        case .readSyscalls, .readBytesLogical, .readBytesPhysical:
            return true
        case .writeSyscalls, .writeBytesLogical, .writeBytesPhysical:
            return true
        case .objectAllocCount, .retainCount, .releaseCount, .retainReleaseDelta:
            return true
        case let .custom(_, _, useScaleFactor):
            return useScaleFactor
        default:
            return false
        }
    }

    /// Indicates whether larger or smaller measurements, relative to a set baseline, indicate better performance.
    var polarity: BenchmarkMetric.Polarity {
        switch self {
        case .throughput:
            return .prefersLarger
        case let .custom(_, polarity, _):
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
            return "Throughput (# / s)"
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
        case .objectAllocCount:
            return "Object allocs"
        case .retainCount:
            return "Retains"
        case .releaseCount:
            return "Releases"
        case .retainReleaseDelta:
            return "(Alloc + Retain) - Release Δ"
        case .delta:
            return "Δ"
        case .deltaPercentage:
            return "Δ %"
        case let .custom(name, _, _):
            return name
        }
    }
}

#if swift(>=5.8)
    @_documentation(visibility: internal)
#endif
public extension BenchmarkMetric {
    var rawDescription: String { // As we can't have raw values due to custom support, we do this...
        switch self {
        case .cpuUser:
            return "cpuUser"
        case .cpuSystem:
            return "cpuSystem"
        case .cpuTotal:
            return "cpuTotal"
        case .wallClock:
            return "wallClock"
        case .throughput:
            return "throughput"
        case .peakMemoryResident:
            return "peakMemoryResident"
        case .peakMemoryVirtual:
            return "peakMemoryVirtual"
        case .mallocCountSmall:
            return "mallocCountSmall"
        case .mallocCountLarge:
            return "mallocCountLarge"
        case .mallocCountTotal:
            return "mallocCountTotal"
        case .allocatedResidentMemory:
            return "allocatedResidentMemory"
        case .memoryLeaked:
            return "memoryLeaked"
        case .syscalls:
            return "syscalls"
        case .contextSwitches:
            return "contextSwitches"
        case .threads:
            return "threads"
        case .threadsRunning:
            return "threadsRunning"
        case .readSyscalls:
            return "readSyscalls"
        case .writeSyscalls:
            return "writeSyscalls"
        case .readBytesLogical:
            return "readBytesLogical"
        case .writeBytesLogical:
            return "writeBytesLogical"
        case .readBytesPhysical:
            return "readBytesPhysical"
        case .writeBytesPhysical:
            return "writeBytesPhysical"
        case .objectAllocCount:
            return "objectAllocCount"
        case .retainCount:
            return "retainCount"
        case .releaseCount:
            return "releaseCount"
        case .retainReleaseDelta:
            return "retainReleaseDelta"
        case .delta:
            return "Δ"
        case .deltaPercentage:
            return "Δ %"
        case let .custom(name, _, _):
            return name
        }
    }
}

// swiftlint:disable cyclomatic_complexity function_body_length
// As we can't have raw values and associated data we add this...
#if swift(>=5.8)
    @_documentation(visibility: internal)
#endif
public extension BenchmarkMetric {
    init?(argument: String) {
        switch argument {
        case "cpuUser":
            self = BenchmarkMetric.cpuUser
        case "cpuSystem":
            self = BenchmarkMetric.cpuSystem
        case "cpuTotal":
            self = BenchmarkMetric.cpuTotal
        case "wallClock":
            self = BenchmarkMetric.wallClock
        case "throughput":
            self = BenchmarkMetric.throughput
        case "peakMemoryResident":
            self = BenchmarkMetric.peakMemoryResident
        case "peakMemoryVirtual":
            self = BenchmarkMetric.peakMemoryVirtual
        case "mallocCountSmall":
            self = BenchmarkMetric.mallocCountSmall
        case "mallocCountLarge":
            self = BenchmarkMetric.mallocCountLarge
        case "mallocCountTotal":
            self = BenchmarkMetric.mallocCountTotal
        case "allocatedResidentMemory":
            self = BenchmarkMetric.allocatedResidentMemory
        case "memoryLeaked":
            self = BenchmarkMetric.memoryLeaked
        case "syscalls":
            self = BenchmarkMetric.syscalls
        case "contextSwitches":
            self = BenchmarkMetric.contextSwitches
        case "threads":
            self = BenchmarkMetric.threads
        case "threadsRunning":
            self = BenchmarkMetric.threadsRunning
        case "readSyscalls":
            self = BenchmarkMetric.readSyscalls
        case "writeSyscalls":
            self = BenchmarkMetric.writeSyscalls
        case "readBytesLogical":
            self = BenchmarkMetric.readBytesLogical
        case "writeBytesLogical":
            self = BenchmarkMetric.writeBytesLogical
        case "readBytesPhysical":
            self = BenchmarkMetric.readBytesPhysical
        case "writeBytesPhysical":
            self = BenchmarkMetric.writeBytesPhysical
        case "objectAllocCount":
            self = BenchmarkMetric.objectAllocCount
        case "retainCount":
            self = BenchmarkMetric.retainCount
        case "releaseCount":
            self = BenchmarkMetric.releaseCount
        case "retainReleaseDelta":
            self = BenchmarkMetric.retainReleaseDelta
        default:
            self = BenchmarkMetric.custom(argument)
        }
    }
}

// swiftlint:enable cyclomatic_complexity function_body_length
