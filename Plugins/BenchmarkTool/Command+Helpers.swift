//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

// This file need to be manually copied between the Benchmark plugin and
// the BenchmarkTool when updated, as no external dependencies are allowed
// for SwiftPM command tools. The source file is in Benchmark and should be
// edited there, then manually copied to BenchmarkTool AND BenchmarkHelpGenerator.

enum Command: String, CaseIterable {
    case run
    case list
    case baseline
    case help
}

/// The benchmark data output format.
enum OutputFormat: String, CaseIterable {
    /// Text output formatted into a visual table suitable for console output
    case text
    /// The text output format, formatted in markdown, suitable for GitHub workflows
    case markdown
    /// Influx data format
    case influx
    /// JMH format consumable by http://jmh.morethan.io
    case jmh
    /// The encoded representation of the underlying histograms capturing the benchmark data, for programmatic use (Codable).
    case histogramEncoded
    /// The histogram percentiles, average, deviation, sample count etc in standard HDR Histogram text format consumable by http://hdrhistogram.github.io/HdrHistogram/plotFiles.html
    case histogram
    /// The raw histogram samples in TSV format for processing by external tools (e.g. Youplot)
    case histogramSamples
    /// The percentiles values betwen (0-100) in TSV format for processing by external tools (e.g. Youplot)
    case histogramPercentiles
}

enum Grouping: String, CaseIterable {
    case metric
    case benchmark
}

enum BaselineOperation: String, CaseIterable {
    case read
    case update
    case list
    case delete
    case compare
    case check
}

enum ExitCode: Int32 {
    case success = 0
    case genericFailure = 1
    case thresholdViolation = 2
}
