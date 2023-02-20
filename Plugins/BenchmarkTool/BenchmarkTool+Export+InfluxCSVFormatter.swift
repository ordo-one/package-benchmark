//
// Copyright (c) 2023 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

import Foundation

class InfluxCSVFormatter {
    let exportableBenchmark: ExportableBenchmark
    var finalFileFormat: String

    init(exportableBenchmark: ExportableBenchmark) {
        self.exportableBenchmark = exportableBenchmark
        finalFileFormat = ""
    }

    /// Takes in benchmark data and returns a csv formatted for influxDB
    /// - Returns: CSV string representation
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
