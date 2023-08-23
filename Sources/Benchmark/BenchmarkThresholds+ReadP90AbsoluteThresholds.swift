//
// Copyright (c) 2023 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

import ExtrasJSON
import Foundation
import SystemPackage

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#else
    #error("Unsupported Platform")
#endif

public extension BenchmarkThresholds {
    /// `makeBenchmarkThresholds` is a convenience function for reading p90 static thresholds that previously have been exported with `metricP90AbsoluteThresholds`
    ///
    /// - Parameters:
    ///   - path: The path where the `Thresholds` directory should be located, containing statis thresholds files using the naming pattern
    ///   `moduleName.benchmarkName.p90.json`
    ///   - moduleName: The name of the benchmark module, can be extracted using `String("\(#fileID)".prefix(while: { $0 != "/" }))` in the benchmark
    ///   - benchmarkName: The name of the benchmark
    /// - Returns: A dictionary with static benchmark thresholds per metric or nil if
    static func makeBenchmarkThresholds(path: String,
                                        moduleName: String,
                                        benchmarkName: String) -> [BenchmarkMetric: BenchmarkThresholds]? {
        var path = FilePath(path)
        path.append("Thresholds")
        path.append("\(moduleName).\(benchmarkName).p90.json")

        var p90Thresholds: [BenchmarkMetric: BenchmarkThresholds]?

        do {
            let fileDescriptor = try FileDescriptor.open(path, .readOnly, options: [], permissions: .ownerRead)

            do {
                try fileDescriptor.closeAfter {
                    do {
                        var readBytes = [UInt8]()
                        let bufferSize = 16 * 1_024 * 1_024

                        while true {
                            let nextBytes = try [UInt8](unsafeUninitializedCapacity: bufferSize) { buf, count in
                                count = try fileDescriptor.read(into: UnsafeMutableRawBufferPointer(buf))
                            }
                            if nextBytes.isEmpty {
                                break
                            }
                            readBytes.append(contentsOf: nextBytes)
                        }

                        p90Thresholds = try XJSONDecoder().decode([BenchmarkMetric: BenchmarkThresholds].self, from: readBytes)
                    } catch {
                        print("Failed to read file at \(path) [\(error)] \(Errno(rawValue: errno).description)")
                    }
                }
            } catch {
                print("Failed to close fd for \(path) after reading.")
            }
        } catch {
            if errno != ENOENT { // file not found is ok, e.g. no thresholds found, then silently return nil
                print("Failed to open file \(path), errno = [\(errno)] \(Errno(rawValue: errno).description)")
            }
        }
        return p90Thresholds
    }
}
