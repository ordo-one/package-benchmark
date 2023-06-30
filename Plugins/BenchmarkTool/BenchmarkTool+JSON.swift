//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

// JSON serialization of benchmark request/reply command sent to controlled process

import Benchmark
import ExtrasJSON
import SystemPackage

extension BenchmarkTool {
    func write(_ reply: BenchmarkCommandRequest) throws {
        let bytesArray = try XJSONEncoder().encode(reply)
        let count: Int = bytesArray.count
        let output = FileDescriptor(rawValue: outputFD)

        try withUnsafeBytes(of: count) { (intPtr: UnsafeRawBufferPointer) in
            _ = try output.write(intPtr)
        }

        try bytesArray.withUnsafeBufferPointer {
            let written = try output.write(UnsafeRawBufferPointer($0))
            if written != count {
                fatalError("written != count \(written) ---- \(count)")
            }
        }
    }

    func read() throws -> BenchmarkCommandReply {
        let input = FileDescriptor(rawValue: inputFD)
        var bufferLength = 0

        try withUnsafeMutableBytes(of: &bufferLength) { (intPtr: UnsafeMutableRawBufferPointer) in
            let readBytes = try input.read(into: intPtr)
            if readBytes == 0 {
                throw RunCommandError.WaitPIDError
            }
        }

        var readBytes = [UInt8]()

        while readBytes.count < bufferLength {
            let nextBytes = try [UInt8](unsafeUninitializedCapacity: bufferLength - readBytes.count) { buf, count in
                count = try input.read(into: UnsafeMutableRawBufferPointer(buf))
            }
            readBytes.append(contentsOf: nextBytes)
        }

        let request = try XJSONDecoder().decode(BenchmarkCommandReply.self, from: readBytes)

        return request
    }
}
