//
// Copyright (c) 2023 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

import Benchmark
import DateTime
import ExtrasJSON
import SystemPackage

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#else
    #error("Unsupported Platform")
#endif

extension BenchmarkTool {
    func write(exportData: String,
               hostIdentifier: String? = nil,
               fileName: String = "results.txt") throws {
        // Set up desired output path and create any intermediate directories for structure as required:
        var outputPath: FilePath

        if let path {
            if path == "stdout" {
                print(exportData)
                return
            }

            let subPath = FilePath(path).removingRoot()

            if FilePath(path).root != nil {
                outputPath = FilePath(root: FilePath(path).root)
            } else {
                outputPath = FilePath(".")
            }
            outputPath.createSubPath(subPath)
            outputPath.append(subPath.components)
        } else {
            outputPath = FilePath(".")
        }

        var csvFile = FilePath()
        if let hostIdentifier {
            csvFile.append("\(hostIdentifier).\(fileName)")
        } else {
            csvFile.append(fileName)
        }

        outputPath.append(csvFile.components)

        do {
            let fd = try FileDescriptor.open(
                outputPath, .writeOnly, options: [.truncate, .create], permissions: .ownerReadWrite
            )

            do {
                try fd.closeAfter {
                    do {
                        var bytes = exportData
                        try bytes.withUTF8 {
                            _ = try fd.write(UnsafeRawBufferPointer($0))
                        }
                    } catch {
                        print("Failed to write to file \(outputPath) [\(error)]")
                    }
                }
            } catch {
                print("Failed to close fd for \(outputPath) after write [\(error)].")
            }
        } catch {
            if errno == EPERM {
                print("Lacking permissions to write to \(outputPath)")
                print("Give benchmark plugin permissions by running with e.g.:")
                print("")
                print("swift package --allow-writing-to-package-directory benchmark --format jmh")
                print("")
            } else {
                print("Failed to open file \(outputPath), errno = [\(errno)]")
            }
        }
    }

    func exportResults(baseline: BenchmarkBaseline) throws {
        let baselineName = baseline.baselineName == "Current baseline" ? "default" : baseline.baselineName
        switch format {
        case .text:
            fallthrough
        case .markdown:
            prettyPrint(baseline, header: "Baseline '\(baselineName)'")
        case .influx:
            try write(exportData: "\(convertToInflux(baseline))",
                      fileName: "\(baselineName)-influx-export.csv")
        case .percentiles:
            try baseline.results.forEach { key, results in
                try results.forEach { values in
                    let outputString = values.statistics!.histogram
                    let description = values.metric.description
                    try write(exportData: "\(outputString)",
                              fileName: cleanupStringForShellSafety("\(baselineName).\(key.name).\(description).histogram-export.txt"))
                }
            }
        case .jmh:
            try write(exportData: "\(convertToJMH(baseline))",
                      fileName: cleanupStringForShellSafety("\(baselineName)-jmh-export.json"))
        case .tsv:
            try baseline.results.forEach { key, results in
                var outputString = ""

                try results.forEach { values in
                    if let histogram = values.statistics?.histogram {
                        histogram.recordedValues().forEach { value in
                            for _ in 0 ..< value.count {
                                outputString += "\(value.value)\n"
                            }
                        }
                    }
                    try write(exportData: "\(outputString)",
                              fileName: cleanupStringForShellSafety("\(baselineName).\(key.target).\(key.name).\(values.metric).tsv"))
                }
            }
        }
    }
}
