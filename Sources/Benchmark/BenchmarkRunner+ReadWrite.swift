//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

// swiftlint disable: file_length type_body_length
import ArgumentParser
import Foundation
import SystemPackage

// For test dependency injection
@available(macOS 13, iOS 16, tvOS 16, *)
protocol BenchmarkRunnerReadWrite {
    func write(_ reply: BenchmarkCommandReply) throws
    func read() throws -> BenchmarkCommandRequest
}

@available(macOS 13, iOS 16, tvOS 16, *)
extension BenchmarkRunner {
    func write(_ reply: BenchmarkCommandReply) throws {
        guard outputFD != nil else {
            return
        }
        let bytesArray = try JSONEncoder().encode(reply)
        let count: Int = bytesArray.count
        let output = FileDescriptor(rawValue: outputFD!)

        // Length header
        try withUnsafeBytes(of: count) { (intPtr: UnsafeRawBufferPointer) in
            _ = try output.write(intPtr)
        }

        // JSON serialization
        try bytesArray.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            let written = try output.write(bytes)
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

        let request = try JSONDecoder().decode(BenchmarkCommandRequest.self, from: Data(readBytes))

        return request
    }
}
