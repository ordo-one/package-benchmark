//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

import ArgumentParser
@_exported import Benchmark
import ExtrasJSON
@_exported import Statistics
import SystemPackage

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#else
    #error("Unsupported Platform")
#endif

// swiftlint:disable type_body_length
// @main must be done in actual benchmark to avoid linker errors unfortunately
public struct BenchmarkRunner: AsyncParsableCommand {
    public init() {}

    @Option(name: .shortAndLong, help: "The input pipe filedescriptor used for communication with host process.")
    var inputFD: Int32?

    @Option(name: .shortAndLong, help: "The output pipe filedescriptor used for communication with host process.")
    var outputFD: Int32?

    var debug = false

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
            _ = try output.write(UnsafeRawBufferPointer($0))
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
        let readBytes = try [UInt8](unsafeUninitializedCapacity: bufferLength) { buf, count in
            count = try input.read(into: UnsafeMutableRawBufferPointer(buf))
        }

        let request = try XJSONDecoder().decode(BenchmarkCommandRequest.self, from: readBytes)

        return request
    }

    // swiftlint:disable cyclomatic_complexity function_body_length
    public mutating func run() async throws {
        // We just run everything in debug mode to simplify workflow with debuggers/profilers
        if inputFD == nil, outputFD == nil {
            debug = true
        }

        registerBenchmarks()
        var debugIterator = Benchmark.benchmarks.makeIterator()
        var benchmarkCommand: BenchmarkCommandRequest
        let mallocStatsProducer = MallocStatsProducer()
        let operatingSystemStatsProducer = OperatingSystemStatsProducer()

        while true {
            if debug { // in debug mode we just run all benchmarks
                if let benchmark = debugIterator.next() {
                    benchmarkCommand = BenchmarkCommandRequest.run(benchmark: benchmark)
                } else {
                    return
                }
            } else {
                benchmarkCommand = try read()
            }

            switch benchmarkCommand {
            case .list:
                try Benchmark.benchmarks.forEach { benchmark in
                    try write(.list(benchmark: benchmark))
                }

                try write(.end)
            case let .run(benchmarkToRun):
                let benchmark = Benchmark.benchmarks.first { $0.name == benchmarkToRun.name }

                if let benchmark = benchmark {
                    // run a few warmup iterations by default to clean out outliers due to cacheing etc.
                    var warmupIterations = 0

                    if benchmark.warmup {
                        warmupIterations = 3

                        for iterations in 0 ..< warmupIterations {
                            benchmark.currentIteration = iterations
                            benchmark.run()
                        }
                    }

                    // Could make an array with raw value indexing on enum for
                    // performance if needed instead of dictionary
                    var statistics: [BenchmarkMetric: Statistics] = [:]

                    // Create metric statistics as needed
                    benchmark.metrics.forEach { metric in
                        switch metric {
                        case .wallClock:
                            statistics[.wallClock] = Statistics(timeUnits: StatisticsUnits(benchmark.timeUnits))
                        default:
                            if operatingSystemStatsProducer.metricSupported(metric) == true {
                                statistics[metric] = Statistics(timeUnits: .automatic)
                            }
                        }
                    }

                    var iterations = 0
                    var accummulatedRuntime: TimeDuration = 0
                    // accummulatedWallclock may be less than total runtime as it skips 0 measurements
                    var accummulatedWallclock: TimeDuration = 0
                    var accummulatedWallclockMeasurements = 0
                    var startMallocStats = MallocStats()
                    var stopMallocStats = MallocStats()
                    var startOperatingSystemStats = OperatingSystemStats()
                    var stopOperatingSystemStats = OperatingSystemStats()
                    var startTime: TimeInstant = 0
                    var stopTime: TimeInstant = 0

                    // Hook that is called before the actual benchmark closure run, so we can capture metrics here
                    benchmark.measurementPreSynchronization = {
                        startMallocStats = mallocStatsProducer.makeMallocStats()
                        startOperatingSystemStats = operatingSystemStatsProducer.makeOperatingSystemStats()
                        startTime = TimeInstant.now // must be last in closure
                    }

                    // And corresponding hook for then the benchmark has finished and capture finishing metrics here
                    benchmark.measurementPostSynchronization = {
                        stopTime = TimeInstant.now // must be first in closure

                        stopOperatingSystemStats = operatingSystemStatsProducer.makeOperatingSystemStats()

                        stopMallocStats = mallocStatsProducer.makeMallocStats()

                        var delta = 0

                        let runningTime: TimeDuration = stopTime - startTime

                        if runningTime > 0 { // macOS sometimes gives us identical timestamps in ns so let's skip those.
                            statistics[.wallClock]?.add(Int(runningTime))
                            accummulatedWallclock += runningTime
                            accummulatedWallclockMeasurements += 1

                            let throughput = Int(benchmark.throughputScalingFactor.rawValue * 1_000_000_000
                                / Int(runningTime))
                            if throughput > 0 {
                                statistics[.throughput]?.add(throughput)
                            }
                        }

                        delta = stopMallocStats.mallocCountTotal - startMallocStats.mallocCountTotal
                        statistics[.mallocCountTotal]?.add(Int(delta))

                        delta = stopMallocStats.mallocCountSmall - startMallocStats.mallocCountSmall
                        statistics[.mallocCountSmall]?.add(Int(delta))

                        delta = stopMallocStats.mallocCountLarge - startMallocStats.mallocCountLarge
                        statistics[.mallocCountLarge]?.add(Int(delta))

                        delta = stopMallocStats.allocatedResidentMemory - startMallocStats.allocatedResidentMemory
                        statistics[.memoryLeaked]?.add(Int(delta))

                        delta = stopOperatingSystemStats.cpuUser - startOperatingSystemStats.cpuUser
                        statistics[.cpuUser]?.add(Int(delta))

                        delta = stopOperatingSystemStats.cpuSystem - startOperatingSystemStats.cpuSystem
                        statistics[.cpuSystem]?.add(Int(delta))

                        delta = stopOperatingSystemStats.cpuTotal - startOperatingSystemStats.cpuTotal
                        statistics[.cpuTotal]?.add(Int(delta))

                        delta = stopOperatingSystemStats.peakMemoryResident
                        statistics[.peakMemoryResident]?.add(Int(delta))

                        delta = stopOperatingSystemStats.peakMemoryVirtual
                        statistics[.peakMemoryVirtual]?.add(Int(delta))

                        delta = stopOperatingSystemStats.syscalls - startOperatingSystemStats.syscalls
                        statistics[.syscalls]?.add(Int(delta))

                        delta = stopOperatingSystemStats.contextSwitches - startOperatingSystemStats.contextSwitches
                        statistics[.contextSwitches]?.add(Int(delta))

                        delta = stopOperatingSystemStats.threads
                        statistics[.threads]?.add(Int(delta))

                        delta = stopOperatingSystemStats.threadsRunning
                        statistics[.threadsRunning]?.add(Int(delta))

                        delta = stopOperatingSystemStats.readSyscalls - startOperatingSystemStats.readSyscalls
                        statistics[.readSyscalls]?.add(Int(delta))

                        delta = stopOperatingSystemStats.writeSyscalls - startOperatingSystemStats.writeSyscalls
                        statistics[.writeSyscalls]?.add(Int(delta))

                        delta = stopOperatingSystemStats.readBytesLogical - startOperatingSystemStats.readBytesLogical
                        statistics[.readBytesLogical]?.add(Int(delta))

                        delta = stopOperatingSystemStats.writeBytesLogical - startOperatingSystemStats.writeBytesLogical
                        statistics[.writeBytesLogical]?.add(Int(delta))

                        delta = stopOperatingSystemStats.readBytesPhysical - startOperatingSystemStats.readBytesPhysical
                        statistics[.readBytesPhysical]?.add(Int(delta))

                        delta =
                            stopOperatingSystemStats.writeBytesPhysical - startOperatingSystemStats.writeBytesPhysical
                        statistics[.writeBytesPhysical]?.add(Int(delta))

                        statistics[.allocatedResidentMemory]?.add(Int(stopMallocStats.allocatedResidentMemory))

                        accummulatedRuntime += runningTime
                    }

                    benchmark.customMetricMeasurement = { metric, value in
                        statistics[metric]?.add(value)
                    }

                    if benchmark.metrics.contains(.threads) ||
                        benchmark.metrics.contains(.threadsRunning) {
                        operatingSystemStatsProducer.startSampling(5_000) // ~5 ms
                    }

                    // Default values if none specified
                    var desiredIterations = 100_000
                    var desiredDuration: TimeDuration = .seconds(1)

                    if let iterations = benchmark.desiredIterations {
                        desiredIterations = iterations
                    }

                    if let duration = benchmark.desiredDuration {
                        desiredDuration = duration
                    }

                    // Run the benchmark at a minimum the desired iterations/runtime --
                    while iterations <= desiredIterations ||
                        accummulatedRuntime <= desiredDuration {
                        // and at a maximum the same...
                        if benchmark.desiredIterations != nil, iterations >= desiredIterations {
                            break
                        }

                        if benchmark.desiredDuration != nil, accummulatedRuntime >= desiredDuration {
                            break
                        }

                        if benchmark.desiredDuration == nil,
                           benchmark.desiredIterations == nil {
                            guard accummulatedRuntime < desiredDuration,
                                  iterations < desiredIterations
                            else {
                                break
                            }
                        }
                        guard benchmark.failureReason == nil else {
                            try write(.error(benchmark.failureReason!))
                            return
                        }

                        benchmark.currentIteration = iterations + warmupIterations

                        benchmark.run()

                        iterations += 1
                    }

                    if benchmark.metrics.contains(.threads) ||
                        benchmark.metrics.contains(.threadsRunning) {
                        operatingSystemStatsProducer.stopSampling()
                    }

                    // calculate percentiles
                    statistics.keys.forEach { metric in
                        statistics[metric]?.calculateStatistics()
                    }

                    // construct metric result array
                    var results: [BenchmarkResult] = []
                    statistics.forEach { key, value in
                        if value.measurementCount > 0 {
                            var percentiles: [BenchmarkResult.Percentile: Int] = [:]

                            if key.polarity() == .prefersLarger {
                                percentiles = [.p0: value.percentileResults[6]!,
                                               .p25: value.percentileResults[3]!,
                                               .p50: value.percentileResults[2]!,
                                               .p75: value.percentileResults[1]!,
                                               .p100: value.percentileResults[0]!]
                            } else {
                                percentiles = [.p0: value.percentileResults[0]!,
                                               .p25: value.percentileResults[1]!,
                                               .p50: value.percentileResults[2]!,
                                               .p75: value.percentileResults[3]!,
                                               .p90: value.percentileResults[4]!,
                                               .p99: value.percentileResults[5]!,
                                               .p100: value.percentileResults[6]!]
                            }
                            let result = BenchmarkResult(metric: key,
                                                         timeUnits: BenchmarkTimeUnits(value.timeUnits),
                                                         measurements: value.measurementCount,
                                                         warmupIterations: warmupIterations,
                                                         thresholds: benchmark.thresholds?[key],
                                                         percentiles: percentiles)
                            results.append(result)
                        }
                    }

                    // sort on metric descriptions for now to get predicatable output on screen
                    results.sort(by: { $0.metric.description > $1.metric.description })

                    // If we didn't capture any results for the desired metrics (e.g. an empty metric list), skip
                    // reporting results back
                    if results.isEmpty == false {
                        try write(.result(benchmark: benchmark, results: results))
                    }

                    // Minimal output for debugging
                    if debug {
                        print("Debug result: \(results)")
                    }
                } else {
                    print("Internal error: Couldn't find specified benchmark '\(benchmarkToRun.name)' to run.")
                }
                try write(.end)
            case .end:
                return
            }
        }
    }
}
