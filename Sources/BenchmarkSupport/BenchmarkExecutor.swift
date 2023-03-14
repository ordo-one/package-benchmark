//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

import DateTime
import Progress
import Statistics

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#else
    #error("Unsupported Platform")
#endif

internal final class BenchmarkExecutor {
    internal init(quiet: Bool = false) {
        self.quiet = quiet
    }

    var quiet: Bool
    let mallocStatsProducer = MallocStatsProducer()
    let operatingSystemStatsProducer = OperatingSystemStatsProducer()

    // swiftlint:disable cyclomatic_complexity function_body_length
    func run(_ benchmark: Benchmark, _ targetName: String) -> [BenchmarkResult] {
        var wallClockDuration: Duration = .zero
        var startMallocStats = MallocStats()
        var stopMallocStats = MallocStats()
        var startOperatingSystemStats = OperatingSystemStats()
        var stopOperatingSystemStats = OperatingSystemStats()
        var startTime = BenchmarkClock.now
        var stopTime = BenchmarkClock.now

        // optionally run a few warmup iterations by default to clean out outliers due to cacheing etc.

        for iterations in 0 ..< benchmark.configuration.warmupIterations {
            benchmark.currentIteration = iterations
            benchmark.run()
        }

        // Could make an array with raw value indexing on enum for
        // performance if needed instead of dictionary
        var statistics: [BenchmarkMetric: Statistics] = [:]
        var operatingSystemStatsRequested = false
        var mallocStatsRequested = false

        // Create metric statistics as needed
        benchmark.configuration.metrics.forEach { metric in
            switch metric {
            case .custom:
                statistics[metric] = Statistics(prefersLarger: metric.polarity == .prefersLarger)
            case .wallClock, .cpuUser, .cpuTotal, .cpuSystem:
                let units = Statistics.Units(benchmark.configuration.timeUnits)
                statistics[metric] = Statistics(units: units)
            default:
                if operatingSystemStatsProducer.metricSupported(metric) == true {
                    statistics[metric] = Statistics(prefersLarger: metric.polarity == .prefersLarger)
                }
            }

            if mallocStatsProducerNeeded(metric) {
                mallocStatsRequested = true
            }

            if operatingSystemsStatsProducerNeeded(metric) {
                operatingSystemStatsRequested = true
            }
        }

        var iterations = 0
        let initialStartTime = BenchmarkClock.now

        // Hook that is called before the actual benchmark closure run, so we can capture metrics here
        benchmark.measurementPreSynchronization = {
            if mallocStatsRequested {
                startMallocStats = self.mallocStatsProducer.makeMallocStats()
            }

            if operatingSystemStatsRequested {
                startOperatingSystemStats = self.operatingSystemStatsProducer.makeOperatingSystemStats()
            }

            startTime = BenchmarkClock.now // must be last in closure
        }

        // And corresponding hook for then the benchmark has finished and capture finishing metrics here
        benchmark.measurementPostSynchronization = {
            stopTime = BenchmarkClock.now // must be first in closure

            if operatingSystemStatsRequested {
                stopOperatingSystemStats = self.operatingSystemStatsProducer.makeOperatingSystemStats()
            }

            if mallocStatsRequested {
                stopMallocStats = self.mallocStatsProducer.makeMallocStats()
            }

            var delta = 0
            let runningTime: Duration = startTime.duration(to: stopTime)

            wallClockDuration = initialStartTime.duration(to: stopTime)

            if runningTime > .zero { // macOS sometimes gives us identical timestamps so let's skip those.
                statistics[.wallClock]?.add(Int(runningTime.nanoseconds()))

                var roundedThroughput =
                    Double(1_000_000_000)
                        / Double(runningTime.nanoseconds())
                roundedThroughput.round(.toNearestOrAwayFromZero)

                let throughput = Int(roundedThroughput)

                if throughput > 0 {
                    statistics[.throughput]?.add(throughput)
                }
            } else {
                //  fatalError("Zero running time \(self.startTime), \(self.stopTime), \(runningTime)")
            }

            if mallocStatsRequested {
                delta = stopMallocStats.mallocCountTotal - startMallocStats.mallocCountTotal
                statistics[.mallocCountTotal]?.add(Int(delta))

                delta = stopMallocStats.mallocCountSmall - startMallocStats.mallocCountSmall
                statistics[.mallocCountSmall]?.add(Int(delta))

                delta = stopMallocStats.mallocCountLarge - startMallocStats.mallocCountLarge
                statistics[.mallocCountLarge]?.add(Int(delta))

                delta = stopMallocStats.allocatedResidentMemory -
                    startMallocStats.allocatedResidentMemory
                statistics[.memoryLeaked]?.add(Int(delta))

                statistics[.allocatedResidentMemory]?.add(Int(stopMallocStats.allocatedResidentMemory))
            }

            if operatingSystemStatsRequested {
                delta = stopOperatingSystemStats.cpuUser - startOperatingSystemStats.cpuUser
                statistics[.cpuUser]?.add(Int(delta))

                delta = stopOperatingSystemStats.cpuSystem - startOperatingSystemStats.cpuSystem
                statistics[.cpuSystem]?.add(Int(delta))

                delta = stopOperatingSystemStats.cpuTotal -
                    startOperatingSystemStats.cpuTotal
                statistics[.cpuTotal]?.add(Int(delta))

                delta = stopOperatingSystemStats.peakMemoryResident
                statistics[.peakMemoryResident]?.add(Int(delta))

                delta = stopOperatingSystemStats.peakMemoryVirtual
                statistics[.peakMemoryVirtual]?.add(Int(delta))

                delta = stopOperatingSystemStats.syscalls -
                    startOperatingSystemStats.syscalls
                statistics[.syscalls]?.add(Int(delta))

                delta = stopOperatingSystemStats.contextSwitches -
                    startOperatingSystemStats.contextSwitches
                statistics[.contextSwitches]?.add(Int(delta))

                delta = stopOperatingSystemStats.threads
                statistics[.threads]?.add(Int(delta))

                delta = stopOperatingSystemStats.threadsRunning
                statistics[.threadsRunning]?.add(Int(delta))

                delta = stopOperatingSystemStats.readSyscalls -
                    startOperatingSystemStats.readSyscalls
                statistics[.readSyscalls]?.add(Int(delta))

                delta = stopOperatingSystemStats.writeSyscalls -
                    startOperatingSystemStats.writeSyscalls
                statistics[.writeSyscalls]?.add(Int(delta))

                delta = stopOperatingSystemStats.readBytesLogical -
                    startOperatingSystemStats.readBytesLogical
                statistics[.readBytesLogical]?.add(Int(delta))

                delta = stopOperatingSystemStats.writeBytesLogical -
                    startOperatingSystemStats.writeBytesLogical
                statistics[.writeBytesLogical]?.add(Int(delta))

                delta = stopOperatingSystemStats.readBytesPhysical -
                    startOperatingSystemStats.readBytesPhysical
                statistics[.readBytesPhysical]?.add(Int(delta))

                delta = stopOperatingSystemStats.writeBytesPhysical -
                    startOperatingSystemStats.writeBytesPhysical
                statistics[.writeBytesPhysical]?.add(Int(delta))
            }
        }

        benchmark.customMetricMeasurement = { metric, value in
            statistics[metric]?.add(value)
        }

        if benchmark.configuration.metrics.contains(.threads) ||
            benchmark.configuration.metrics.contains(.threadsRunning) {
            operatingSystemStatsProducer.startSampling(5_000) // ~5 ms
        }

        var progressBar: ProgressBar?

        if quiet == false {
            let progressString = "| \(targetName):\(benchmark.name)"

            progressBar = ProgressBar(count: 100,
                                      configuration: [ProgressPercent(),
                                                      ProgressBarLine(barLength: 60),
                                                      ProgressTimeEstimates(),
                                                      ProgressString(string: progressString)])
            if var progressBar {
                progressBar.setValue(0)
            }
            fflush(stdout)
        }

        var nextPercentageToUpdateProgressBar = 0

        // Run the benchmark at a minimum the desired iterations/runtime --

        while iterations <= benchmark.configuration.maxIterations ||
            wallClockDuration <= benchmark.configuration.maxDuration {
            // and at a maximum the same...
            guard wallClockDuration < benchmark.configuration.maxDuration,
                  iterations < benchmark.configuration.maxIterations
            else {
                break
            }

            if benchmark.failureReason != nil {
                return []
            }

            benchmark.currentIteration = iterations + benchmark.configuration.warmupIterations

            benchmark.run()

            iterations += 1

            if var progressBar {
                let iterationsPercentage = 100.0 * Double(iterations) /
                    Double(benchmark.configuration.maxIterations)

                let timePercentage = 100.0 * (wallClockDuration /
                    benchmark.configuration.maxDuration)

                let maxPercentage = max(iterationsPercentage, timePercentage)

                if Int(maxPercentage) > nextPercentageToUpdateProgressBar {
                    progressBar.setValue(Int(maxPercentage))
                    fflush(stdout)
                    nextPercentageToUpdateProgressBar = Int(maxPercentage) + Int.random(in: 3 ... 9)
                }
            }
        }

        if var progressBar {
            progressBar.setValue(100)
            fflush(stdout)
        }

        if benchmark.configuration.metrics.contains(.threads) ||
            benchmark.configuration.metrics.contains(.threadsRunning) {
            operatingSystemStatsProducer.stopSampling()
        }

        // construct metric result array
        var results: [BenchmarkResult] = []
        statistics.forEach { key, value in
            if value.measurementCount > 0 {
                let result = BenchmarkResult(metric: key,
                                             timeUnits: BenchmarkTimeUnits(value.timeUnits),
                                             scalingFactor: benchmark.configuration.scalingFactor,
                                             warmupIterations: benchmark.configuration.warmupIterations,
                                             thresholds: benchmark.configuration.thresholds?[key],
                                             statistics: value)
                results.append(result)
            }
        }

        // sort on metric descriptions for now to get predicatable output on screen
        results.sort(by: { $0.metric.description > $1.metric.description })

        return results
    }
}
