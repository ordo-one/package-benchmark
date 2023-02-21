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
import Numerics
import ExtrasJSON

extension JMHPrimaryMetric {
    init(_ result: BenchmarkResult) {
        let histogram = result.statistics!.histogram

        // TODO: Must validate the calculation of scoreError
        // according to https://stackoverflow.com/a/24725075
        // and https://www.calculator.net/confidence-interval-calculator.html
        let z999 = 3.291
        let error = z999 * histogram.stdDeviation / .sqrt(Double(histogram.totalCount))

        // TODO: should truncate to reasonable number of decimals for error here
        let score = histogram.mean

        let percentiles = [0.0, 50.0, 90.0, 95.0, 99.0, 99.9, 99.99, 99.999, 99.9999, 100.0]
        var percentileValues : [String : Double] = [:]
        var recordedValues: [Double] = []

        for p in percentiles {
            percentileValues[String(p)] = Double(histogram.valueAtPercentile(p))
        }

        for value in histogram.recordedValues() {
            for _ in 0 ..< value.count {
                recordedValues.append(Double(value.value))
            }
        }

        self.score = score
        self.scoreError = error
        self.scoreConfidence = [score - error, score + error]
        self.scorePercentiles = percentileValues
        self.scoreUnit = result.metric.description
        self.rawData = [recordedValues]
    }
}

extension BenchmarkTool {
    func convertToJMH(_ baseline: BenchmarkBaseline) throws -> String {
        var resultString = ""
        var jmhElements: [JMHElement] = []
        var secondaryMetrics: [String : JMHPrimaryMetric] = [:]


        baseline.targets.forEach { benchmarkTarget in

            let results = baseline.resultsByTarget(benchmarkTarget)

            results.forEach { key, result in

                guard let primaryResult = result.first(where: { $0.metric == .throughput }) else {
                    print("Throughput metric must be present for JMH export [\(key)]")
                    return
                }

                let primaryMetrics = JMHPrimaryMetric(primaryResult)

                for secondaryResult in result {
                    if secondaryResult.metric != .throughput {
                        let secondaryMetric = JMHPrimaryMetric(secondaryResult)
                        secondaryMetrics[secondaryResult.metric.description] = secondaryMetric
                    }
                }

                let benchmarkKey = key.replacingOccurrences(of: " ", with: "_")
                let jmh = JMHElement(benchmark: "package.benchmark.\(benchmarkKey)",
                                     mode: "thrpt",
                                     threads: 1,
                                     forks: 1,
                                     warmupIterations: primaryResult.warmupIterations,
                                     warmupTime: "1 s",
                                     warmupBatchSize: 10,
                                     measurementIterations: primaryResult.measurements,
                                     measurementTime: "1 s",
                                     measurementBatchSize: primaryResult.measurements,
                                     primaryMetric: primaryMetrics,
                                     secondaryMetrics: secondaryMetrics)

                jmhElements.append(jmh)
            }
        }

        let bytesArray = try XJSONEncoder().encode(jmhElements)
        resultString = (String(bytes: bytesArray, encoding: .utf8)!)

        return resultString
    }
}
