// Benchmark boilerplate generated by Benchmark

import Benchmark
import Foundation

let benchmarks = {
    Benchmark("SomeBenchmark") { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(Date()) // replace this line with your own benchmark
        }
    }
    // Add additional benchmarks here
}