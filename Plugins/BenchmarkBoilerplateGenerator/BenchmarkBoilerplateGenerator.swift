//
// Copyright (c) 2023 Ordo One AB
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

import ArgumentParser
import SystemPackage

@main
struct Benchmark: AsyncParsableCommand {
    @Option(name: .long, help: "Name of the target")
    var target: String

    @Option(name: .long, help: "Output file path")
    var output: String

    mutating func run() async throws {
        let outputPath = FilePath(output) // package
        var boilerplate = """
        import Benchmark

        @main
        struct \(target)BenchmarkRunner: BenchmarkRunnerHooks {
          static func registerBenchmarks() {
            benchmarks()
          }
        }
        """
        do {
            let fd = try FileDescriptor.open(outputPath, .writeOnly, options: [.truncate, .create], permissions: .ownerReadWrite)
            do {
                try fd.closeAfter {
                    do {
                        try boilerplate.withUTF8 {
                            _ = try fd.write(UnsafeRawBufferPointer($0))
                        }
                    } catch {
                        print("Failed to write to file \(outputPath)")
                    }
                }
            } catch {
                print("Failed to close fd for \(outputPath) after write.")
            }
        }
    }
}
