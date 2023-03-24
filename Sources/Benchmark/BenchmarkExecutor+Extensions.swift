//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//
// swiftlint:disable cyclomatic_complexity

extension BenchmarkExecutor {
    func mallocStatsProducerNeeded(_ metric: BenchmarkMetric) -> Bool {
        switch metric {
        case .mallocCountLarge:
            return true
        case .memoryLeaked:
            return true
        case .mallocCountSmall:
            return true
        case .mallocCountTotal:
            return true
        case .allocatedResidentMemory:
            return true
        default:
            return false
        }
    }
}

extension BenchmarkExecutor {
    func operatingSystemsStatsProducerNeeded(_ metric: BenchmarkMetric) -> Bool {
        switch metric {
        case .cpuUser:
            return true
        case .cpuSystem:
            return true
        case .cpuTotal:
            return true
        case .peakMemoryResident:
            return true
        case .peakMemoryVirtual:
            return true
        case .syscalls:
            return true
        case .contextSwitches:
            return true
        case .threads:
            return true
        case .threadsRunning:
            return true
        case .readSyscalls:
            return true
        case .writeSyscalls:
            return true
        case .readBytesLogical:
            return true
        case .writeBytesLogical:
            return true
        case .readBytesPhysical:
            return true
        case .writeBytesPhysical:
            return true
        default:
            return false
        }
    }
}

extension BenchmarkExecutor {
    func arcStatsProducerNeeded(_ metric: BenchmarkMetric) -> Bool {
        switch metric {
        case .retainCount, .releaseCount, .retainReleaseDelta:
            return true
        default:
            return false
        }
    }
}
