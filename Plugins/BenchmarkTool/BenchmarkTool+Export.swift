import Benchmark
import DateTime
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

let exportablesDirectory: String = ".exportableBenchmarks"

extension BenchmarkTool {
    func write(_ exportablebenchmark: String,
               hostIdentifier: String? = nil) throws {
        // Set up desired output path and create any intermediate directories for structure as required:

        /*
         We store the baselines in a .benchmarkBaselines directory, by default in the package root path
         unless otherwise specified.

         The 'default' folder is used when no specific named baseline have been specified with the
         command line. Specified 'named' baselines is useful for convenient A/B/C testing and comparisons.
         Unless a host identifier have been specified on the command line (or in an environment variable),
         we by default store results in 'influx_results.csv', otherwise we will use the environment variable
         or command line to optionally specify a 'hostIdentifier' that allow for separation between
         different hosts if checking in baselines in repos.

         .exportableBenchmarks
         ├── target1
         │   ├── default
         │   │   ├── results.json
         │   │   ├── hostIdentifier1.influx_results.csv
         │   │   ├── hostIdentifier2.influx_results.csv
         │   │   └── hostIdentifier3.influx_results.csv
         │   ├── named1
         │   │   ├── results.json
         │   │   ├── hostIdentifier1.influx_results.csv
         │   │   ├── hostIdentifier2.influx_results.csv
         │   │   └── hostIdentifier3.influx_results.csv
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

        var csvFile = FilePath()
        if let hostIdentifier {
            csvFile.append("\(hostIdentifier).influx_results.csv")
        } else {
            csvFile.append("influx_results.csv")
        }

        outputPath.append(csvFile.components)

        do {
            if FileManager.default.fileExists(atPath: outputPath.description) {
                try FileManager.default.removeItem(atPath: outputPath.description)
            }

            // Write out exportable benchmarks
            FileManager.default.createFile(atPath: outputPath.description, contents: exportablebenchmark.data(using: String.Encoding.utf8))
        } catch {
            if errno == EPERM {
                print("Lacking permissions to write to \(outputPath)")
                print("Give benchmark plugin permissions by running with e.g.:")
                print("")
                print("swift package --allow-writing-to-package-directory benchmark export influx")
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
        let formatter = influxCSVFormatter(exportableBenchmark: exportableBenchmark)
        return formatter.influxCSVFormat()
    }
}

class influxCSVFormatter {
    let exportableBenchmark: ExportableBenchmark
    var finalFileFormat: String

    init(exportableBenchmark: ExportableBenchmark) {
        self.exportableBenchmark = exportableBenchmark
        finalFileFormat = ""
    }

    func influxCSVFormat() -> String {
        let machine = exportableBenchmark.benchmarkMachine
        let hostName = machine.hostname
            .replacingOccurrences(of: " ", with: "-")
        let processorType = machine.processorType
            .replacingOccurrences(of: " ", with: "-")
        let kernelVersion = machine.kernelVersion
            .replacingOccurrences(of: " ", with: "-")
        let processors = machine.processors
        let memory = machine.memory

        let dataTypeHeader = "#datatype tag,tag,tag,tag,tag,tag,tag,tag,double,double,long,long,dateTime\n"
        finalFileFormat.append(dataTypeHeader)
        let headers = "measurement,hostName,processoryType,processors,memory,kernelVersion,metric,unit,test,value,test_average,iterations,warmup_iterations,time\n"
        finalFileFormat.append(headers)

        for testData in exportableBenchmark.benchmarks {
            let testName = testData.test
            let iterations = testData.iterations
            let warmup_iterations = testData.warmupIterations

            for granularData in testData.data {
                let metric = granularData.metric
                    .replacingOccurrences(of: " ", with: "")
                let units = granularData.units
                let average = granularData.average

                for dataTableValue in granularData.metricsdata {
                    let time = ISO8601DateFormatter().string(from: Date())
                    let dataLine = "\(exportableBenchmark.target),\(hostName),\(processorType),\(processors),\(memory),\(kernelVersion),\(metric),\(units),\(testName),\(dataTableValue),\(average),\(iterations),\(warmup_iterations),\(time)\n"
                    finalFileFormat.append(dataLine)
                }
            }
        }

        return finalFileFormat
    }

    func appendMachineInfo() {
        let machine = exportableBenchmark.benchmarkMachine

        let hostName = machine.hostname
            .replacingOccurrences(of: " ", with: "-")
        let processorType = machine.processorType
            .replacingOccurrences(of: " ", with: "-")
        let kernelVersion = machine.kernelVersion
            .replacingOccurrences(of: " ", with: "-")

        let hostNameConstant = "#constant tag,hostName,\(hostName)\n"
        let processorConstant = "#constant tag,processors,\(machine.processors)\n"
        let processorTypeConstant = "#constant tag,processorType,\(processorType)\n"
        let memoryConstant = "#constant tag,memory,\(machine.memory)\n"
        let kernelVersionConstant = "#constant tag,kernelVersion,\(kernelVersion)\n"

        finalFileFormat.append(hostNameConstant)
        finalFileFormat.append(processorConstant)
        finalFileFormat.append(processorTypeConstant)
        finalFileFormat.append(memoryConstant)
        finalFileFormat.append(kernelVersionConstant)
    }
}
