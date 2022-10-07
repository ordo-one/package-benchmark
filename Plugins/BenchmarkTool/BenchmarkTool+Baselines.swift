//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

// Reading / writing of benchmark baselines

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

struct BenchmarkMachine: Codable, Equatable {
    internal init(hostname: String, processors: Int, processorType: String, memory: Int, kernelVersion: String) {
        self.hostname = hostname
        self.processors = processors
        self.processorType = processorType
        self.memory = memory
        self.kernelVersion = kernelVersion
    }

    var hostname: String
    var processors: Int
    var processorType: String // e.g. arm64e
    var memory: Int // in GB
    var kernelVersion: String

    public static func == (lhs: BenchmarkMachine, rhs: BenchmarkMachine) -> Bool {
        lhs.processors == rhs.processors &&
            lhs.processorType == rhs.processorType &&
            lhs.memory == rhs.memory
    }
}

struct BenchmarkIdentifier: Codable, Hashable {
    internal init(target: String, name: String) {
        self.target = target
        self.name = name
    }

    var target: String // The name of the executable benchmark target id
    var name: String // The name of the benchmark

    public func hash(into hasher: inout Hasher) {
        hasher.combine(target)
        hasher.combine(name)
    }

    public static func == (lhs: BenchmarkIdentifier, rhs: BenchmarkIdentifier) -> Bool {
        lhs.name == rhs.name && lhs.target == rhs.target
    }
}

struct BenchmarkBaseline: Codable {
    internal init(machine: BenchmarkMachine, results: [BenchmarkIdentifier: [BenchmarkResult]]) {
        self.machine = machine
        self.results = results
    }

    var machine: BenchmarkMachine
    var results: [BenchmarkIdentifier: [BenchmarkResult]]
}

let baselinesDirectory: String = ".benchmarkBaselines"

extension BenchmarkTool {
    func write(_ baseline: BenchmarkBaseline,
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

         .benchmarkBaselines
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

        subPath.append(baselinesDirectory) // package/.benchmarkBaselines
        subPath.append(FilePath.Component(target)!) // package/.benchmarkBaselines/myTarget1

        if let baselineIdentifier = baselineName {
            subPath.append(baselineIdentifier) // package/.benchmarkBaselines/myTarget1/named1
        } else {
            subPath.append("default") // // package/.benchmarkBaselines/myTarget1/default
        }

        outputPath.createSubPath(subPath) // Create destination subpath if needed

        outputPath.append(subPath.components)

        if let hostIdentifier = hostIdentifier {
            outputPath.append("\(hostIdentifier).results.json")
        } else {
            outputPath.append("results.json")
        }

        // Write out benchmark baselines
        do {
            let fd = try FileDescriptor.open(
                outputPath, .writeOnly, options: [.truncate, .create], permissions: .ownerReadWrite
            )

            do {
                try fd.closeAfter {
                    do {
                        let bytesArray = try XJSONEncoder().encode(baseline)

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

    func read(hostIdentifier: String? = nil,
              baselineIdentifier: String? = nil) throws -> BenchmarkBaseline? {
        var path = FilePath(baselineStoragePath)
        path.append(baselinesDirectory) // package/.benchmarkBaselines
        path.append(FilePath.Component(target)!) // package/.benchmarkBaselines/myTarget1

        if let baselineIdentifier = baselineIdentifier {
            path.append(baselineIdentifier) // package/.benchmarkBaselines/myTarget1/named1
        } else {
            path.append("default") // // package/.benchmarkBaselines/myTarget1/default
        }

        if let hostIdentifier = hostIdentifier {
            path.append("\(hostIdentifier).results.json")
        } else {
            path.append("results.json")
        }

        var baseline: BenchmarkBaseline?

        // Read from the file
        do {
            let fd = try FileDescriptor.open(path, .readOnly, options: [], permissions: .ownerRead)

            do {
                try fd.closeAfter {
                    do {
                        let readBytes = try [UInt8](unsafeUninitializedCapacity: 64 * 1_024 * 1_024) { buf, count in
                            count = try fd.read(into: UnsafeMutableRawBufferPointer(buf))
                        }

                        baseline = try XJSONDecoder().decode(BenchmarkBaseline.self, from: readBytes)

                        //                        print("Read baseline: \(baseline!)")
                    } catch {
                        print("Failed to open file for reading \(path)")
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

        return baseline
    }
}

extension BenchmarkBaseline: Equatable {
    public func betterResultsOrEqual(than otherBaseline: BenchmarkBaseline,
                                     thresholds: BenchmarkResult.PercentileThresholds = .default,
                                     printOutput: Bool = false) -> Bool {
        let lhs = self
        let rhs = otherBaseline
        var warningPrintedForMetric: Set<BenchmarkMetric> = []
        var warningPrinted = false
        var betterOrEqualForAll = true
        var betterOrEqualForIdentifier = true

        for (lhsBenchmarkIdentifier, lhsBenchmarkResults) in lhs.results {
            /*            if printOutput {
                 print("Checking for threshold violations for `\(lhsBenchmarkIdentifier.target):\(lhsBenchmarkIdentifier.name)`.")
             }
             */
            for lhsBenchmarkResult in lhsBenchmarkResults {
                if let rhsResults = rhs.results.first(where: { $0.key == lhsBenchmarkIdentifier }) {
                    if let rhsBenchmarkResult = rhsResults.value.first(where: { $0.metric == lhsBenchmarkResult.metric }) {
                        if lhsBenchmarkResult.betterResultsOrEqual(than: rhsBenchmarkResult,
                                                                   thresholds: lhsBenchmarkResult.thresholds ?? thresholds,
                                                                   printOutput: printOutput) == false {
                            betterOrEqualForIdentifier = false
                        }
                    } else {
                        if warningPrintedForMetric.contains(lhsBenchmarkResult.metric) == false {
                            print("`\(lhsBenchmarkResult.metric)` not found in both baselines, skipping it.")
                            warningPrintedForMetric.insert(lhsBenchmarkResult.metric)
                        }
                    }
                } else {
                    if warningPrinted == false {
                        print("`\(lhsBenchmarkIdentifier.target):\(lhsBenchmarkIdentifier.name)` not found in second baseline, skipping it.")
                        warningPrinted = true
                    }
                }
            }
            if betterOrEqualForIdentifier == false && printOutput {
                print("`\(lhsBenchmarkIdentifier.target):\(lhsBenchmarkIdentifier.name)` had threshold violations.")
                print("")
            }

            betterOrEqualForAll = betterOrEqualForAll || betterOrEqualForIdentifier
            betterOrEqualForIdentifier = true
        }

        return betterOrEqualForAll
    }

    static func == (lhs: BenchmarkBaseline, rhs: BenchmarkBaseline) -> Bool {
        if lhs.machine.memory != rhs.machine.memory ||
            lhs.machine.processors != rhs.machine.processors ||
            lhs.machine.processorType != rhs.machine.processorType {
            return false
        }

        for (lhsBenchmarkIdentifier, lhsBenchmarkResults) in lhs.results {
            for lhsBenchmarkResult in lhsBenchmarkResults {
                if let rhsResults = rhs.results.first(where: { $0.key == lhsBenchmarkIdentifier }) {
                    if let rhsBenchmarkResult = rhsResults.value.first(where: { $0.metric == lhsBenchmarkResult.metric }) {
                        if lhsBenchmarkResult != rhsBenchmarkResult {
                            return false
                        }
                    } else { // We couldn't find the specific metric
                        return false
                    }
                } else { // We couldn't find a result for one of the tests
                    return false
                }
            }
        }
        return true
    }
}
