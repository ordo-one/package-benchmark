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
// swiftlint disable: file_length type_body_length
import ArgumentParser
@_exported import Benchmark
import ExtrasJSON
@_exported import Statistics
import SystemPackage

// For test dependency injection
protocol BenchmarkRunnerReadWrite {
    func write(_ reply: BenchmarkCommandReply) throws
    func read() throws -> BenchmarkCommandRequest
}

extension BenchmarkRunner {
    func write(_ reply: BenchmarkCommandReply) throws {
        guard outputFD != nil else {
            return
        }
        let bytesArray = try XJSONEncoder().encode(reply)
        let count: Int = bytesArray.count
        let output = FileDescriptor(rawValue: outputFD!)

        // Length header
        try withUnsafeBytes(of: count) { (intPtr: UnsafeRawBufferPointer) in
            _ = try output.write(intPtr)
        }

        // JSON serialization
        try bytesArray.withUnsafeBufferPointer {
            let written = try output.write(UnsafeRawBufferPointer($0))
            if count != written {
                fatalError("count != written \(count) ---- \(written)")
            }
        }
    }

    func read() throws -> BenchmarkCommandRequest {
        guard inputFD != nil else {
            return .end
        }
        let input = FileDescriptor(rawValue: inputFD!)
        var bufferLength = 0

        // Length header
        try withUnsafeMutableBytes(of: &bufferLength) { (intPtr: UnsafeMutableRawBufferPointer) in
            _ = try input.read(into: intPtr)
        }

        // JSON serialization
        var readBytes = [UInt8]()

        while readBytes.count < bufferLength {
            let nextBytes = try [UInt8](unsafeUninitializedCapacity: bufferLength - readBytes.count) { buf, count in
                count = try input.read(into: UnsafeMutableRawBufferPointer(buf))
            }
            readBytes.append(contentsOf: nextBytes)
        }

        let request = try XJSONDecoder().decode(BenchmarkCommandRequest.self, from: readBytes)

        return request
    }
}

extension BenchmarkRunner {
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

extension BenchmarkRunner {
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
