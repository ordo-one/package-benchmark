//
// Copyright (c) 2023 Ordo One AB
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0

// This is an example how generic support code for loading absolute thresholds can be done
import Benchmark
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

// We expect static thresholds to be in $CWD/Thresholds

func makeConfigurationFor(_ name: String) -> Benchmark.Configuration {
    var configuration: Benchmark.Configuration = .init(metrics: [.mallocCountTotal, .syscalls] + .arc,
                                                       warmupIterations: 1,
                                                       scalingFactor: .kilo,
                                                       maxDuration: .seconds(2),
                                                       maxIterations: .kilo(100))

    configuration.thresholds = readThresholdsFrom(FileManager.default.currentDirectoryPath, name: name)

    return configuration
}

func readThresholdsFrom(_ path:String, name: String) -> [BenchmarkMetric: BenchmarkThresholds]? {
    let moduleName = String("\(#fileID)".prefix(while: { $0 != "/" })) // https://forums.swift.org/t/pitch-introduce-module-to-get-the-current-module-name/45806/8

    var path = FilePath(path)
    path.append("Thresholds")
    path.append("\(moduleName).\(name).p90.json")

    var p90Thresholds: [BenchmarkMetric: BenchmarkThresholds] = [:]

    do {
        let fd = try FileDescriptor.open(path, .readOnly, options: [], permissions: .ownerRead)

        do {
            try fd.closeAfter {
                do {
                    var readBytes = [UInt8]()
                    let bufferSize = 16 * 1_024 * 1_024
                    var done = false

                    while done == false { // readBytes.count < bufferLength {
                        let nextBytes = try [UInt8](unsafeUninitializedCapacity: bufferSize) { buf, count in
                            count = try fd.read(into: UnsafeMutableRawBufferPointer(buf))
                            if count == 0 {
                                done = true
                            }
                        }
                        readBytes.append(contentsOf: nextBytes)
                    }

                    p90Thresholds = try XJSONDecoder().decode([BenchmarkMetric: BenchmarkThresholds].self, from: readBytes)

                } catch {
                    print("Failed to open file for reading \(path) [\(error)]")
                }
            }
        } catch {
            print("Failed to close fd for \(path) after reading.")
        }
    } catch {
        if errno != ENOENT { // file not found is ok, e.g. when no baselines exist
            print("Failed to open file \(path), errno = [\(errno)]")
        }
    }

    return p90Thresholds
}
