import Benchmark
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
    var percentiles: [BenchmarkResult.Percentile : Int]
}

let exportablesDirectory: String = ".exportableBenchmarks"

extension BenchmarkTool {
    func write(_ exportablebenchmark: ExportableBenchmark,
               hostIdentifier: String? = nil) throws {
        // Set up desired output path and create any intermediate directories for structure as required:

        /*
         We store the baselines in a .benchmarkBaselines directory, by default in the package root path
         unless otherwise specified.

         The 'default' folder is used when no specific named baseline have been specified with the
         command line. Specified 'named' baselines is useful for convenient A/B/C testing and comparisons.
         Unless a host identifier have been specified on the command line (or in an environment variable),
         we by default store results in 'results.json', otherwise we will use the environment variable
         or command line to optionally specify a 'hostIdentifier' that allow for separation between
         different hosts if checking in baselines in repos.

         .exportableBenchmarks
         ├── target1
         │   ├── default
         │   │   ├── results.json
         │   │   ├── hostIdentifier1.results.json
         │   │   ├── hostIdentifier2.results.json
         │   │   └── hostIdentifier3.results.json
         │   ├── named1
         │   │   ├── results.json
         │   │   ├── hostIdentifier1.results.json
         │   │   ├── hostIdentifier2.results.json
         │   │   └── hostIdentifier3.results.json
         │   ├── named2
         │   │   └── ...
         │   └── ...
         ├── target2
         │   └── default
         │       └── ...
         └── ...
         */

        var outputPath = FilePath(baselineStoragePath) // package
        var subPath = FilePath() // subpath rooted in package used for directory creation

        subPath.append(exportablesDirectory) // package/.exportableBenchmarks
        subPath.append(FilePath.Component(target)!) // package/.exportableBenchmarks/myTarget1

        if let baselineIdentifier = baselineName {
            subPath.append(baselineIdentifier) // package/.exportableBenchmarks/myTarget1/named1
        } else {
            subPath.append("exportable") // // package/.exportableBenchmarks/myTarget1/exportable
        }

        outputPath.createSubPath(subPath) // Create destination subpath if needed

        outputPath.append(subPath.components)

        if let hostIdentifier = hostIdentifier {
            outputPath.append("\(hostIdentifier).results.json")
        } else {
            outputPath.append("results.json")
        }

        // Write out exportable benchmarks
        do {
            let fd = try FileDescriptor.open(
                outputPath, .writeOnly, options: [.truncate, .create], permissions: .ownerReadWrite
            )

            do {
                try fd.closeAfter {
                    do {
                        let bytesArray = try XJSONEncoder().encode(exportablebenchmark)

                        try bytesArray.withUnsafeBufferPointer {
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
                print("swift package --allow-writing-to-package-directory benchmark update-baseline")
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
                                testName: String) -> TestMetricData {
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
}
