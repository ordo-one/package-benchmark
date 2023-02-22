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

struct ExportableBenchmark: Codable {
    var benchmarkMachine: BenchmarkMachine
    var target: String
    var benchmarks: [TestData]
}

struct TestData: Codable {
    var test: String
    var iterations: Int
    var warmupIterations: Int
    var data: [TestMetricData]
}

struct TestMetricData: Codable {
    var metric: String
    var units: String
    var average: Double
    var metricsdata: [Int]
    var percentiles: [BenchmarkResult.Percentile: Int]
}

extension BenchmarkTool {
    func write(_ exportablebenchmark: String,
               hostIdentifier: String? = nil,
               fileName: String = "results.txt") throws {

        // Set up desired output path and create any intermediate directories for structure as required:
        var outputPath: FilePath

        if let exportPath {
            let subPath = FilePath(exportPath).removingRoot()

            if FilePath(exportPath).root != nil {
                outputPath = FilePath(root: FilePath(exportPath).root)
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
                        var bytes = exportablebenchmark
                        try bytes.withUTF8 {
                            _ = try fd.write(UnsafeRawBufferPointer($0))
                        }
                    } catch {
                        print("Failed to write to file \(outputPath)")
                    }
                }
            } catch {
                print("Failed to close fd for \(outputPath) after write.")
            }
        } catch {
            if errno == EPERM {
                print("Lacking permissions to write to \(outputPath)")
                print("Give benchmark plugin permissions by running with e.g.:")
                print("")
                print("swift package --allow-writing-to-package-directory benchmark export")
                print("")
            } else {
                print("Failed to open file \(outputPath), errno = [\(errno)]")
            }
        }
    }

    func saveExportableResults(
        _ benchmarks: BenchmarkBaseline) -> ExportableBenchmark {
        let keys = benchmarks.results.keys.sorted(by: { $0.name < $1.name })
        var testList: [TestData] = []

        keys.forEach { test in
            if let value = benchmarks.results[test] {
                var allResults: [BenchmarkResult] = []
                value.forEach { result in
                    allResults.append(result)
                }

                allResults.sort(by: { $0.metric.description < $1.metric.description })

                var benchmarkResultData: [TestMetricData] = []
                var iterations = 0
                var warmupIterations = 0
                allResults.forEach { results in
                    benchmarkResultData.append(
                        processBenchmarkResult(test: results,
                                               testName: test.name)
                    )

                    iterations = results.measurements
                    warmupIterations = results.warmupIterations
                }

                testList.append(
                    TestData(test: test.name,
                             iterations: iterations,
                             warmupIterations: warmupIterations,
                             data: benchmarkResultData)
                )
            }
        }

        return ExportableBenchmark(benchmarkMachine: benchmarks.machine,
                                   target: target,
                                   benchmarks: testList)
    }

    func processBenchmarkResult(test: BenchmarkResult,
                                testName _: String) -> TestMetricData {
        var testData: [Int] = []
        test.percentiles.forEach { result in
            testData.append(result.value)
        }

        let totalValue = Double(testData.reduce(0, +))
        let totalCount = Double(testData.count)
        let averageValue = (totalValue / totalCount)

        return TestMetricData(metric: test.metric.description,
                              units: test.unitDescription,
                              average: averageValue,
                              metricsdata: testData,
                              percentiles: test.percentiles)
    }

    func convertToCSV(exportableBenchmark: ExportableBenchmark) -> String {
        let formatter = InfluxCSVFormatter(exportableBenchmark: exportableBenchmark)
        return formatter.influxCSVFormat()
    }
}

