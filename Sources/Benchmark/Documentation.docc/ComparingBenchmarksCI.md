# Comparing Benchmarks using Continuous Integration

Benchmark was written with continuous integration in mind, and allows you to set up comparisons to validate builds. 

## Overview

It may be useful to compare code performance against a baseline in an automated fashion.
Benchmark was developed to be invoked through command line options to support automation.
Additionally, the `swift package benchmark baseline check` command exits with a non-zero error if there are performance degradations found during the comparison.

It's possible to do both checks for a PR vs the main baseline, or for simply checking a baseline / benchmark run vs a fixed reference point using `--check-absolute`.

### Comparing two baselines (e.g. PR vs main)

The following will check two previously stored baselines for deviations vs the defined thresholds
```bash
swift package benchmark baseline check main pull_request
```

### Comparing a test run against hardcoded thresholds

The following will run all benchmarks and compare them against a fixed absolute threshold (as defined by the benchmark setup code)
```bash
swift package benchmark baseline check --check-absolute
```
This is typically used in conjunction with the built in support for exporting absolute p90 baselines using the `metricP90AbsoluteThresholds` export format.
```bash
swift package --allow-writing-to-package-directory benchmark --filter "P90.*" --format metricP90AbsoluteThresholds --path Thresholds/
```

These baselines are easily read using ``BenchmarkThresholds/makeBenchmarkThresholds(path:moduleName:benchmarkName:)``.

Sample usage:
```swift
import Benchmark
import DateTime
import Foundation

func makeConfigurationFor(_ name: String) -> Benchmark.Configuration {
  let moduleName = String("\(#fileID)".prefix(while: { $0 != "/" }))

  var configuration: Benchmark.Configuration = .init(metrics: [.mallocCountTotal, .syscalls] + .arc,
                                            warmupIterations: 1,
                                               scalingFactor: .kilo,
                                                 maxDuration: .seconds(2),
                                               maxIterations: .kilo(100))

  configuration.thresholds = BenchmarkThresholds.makeBenchmarkThresholds(path: FileManager.default.currentDirectoryPath,
                                                                   moduleName: moduleName,
                                                                benchmarkName: name)
  // if thresholds are nil here, we failed to read anything from the file and might want to warn or set up other thresholds
  return configuration
}

let benchmarks = {
  var testName: String!

  testName = "P90Date"
  Benchmark(testName, configuration: makeConfigurationFor(testName)) { benchmark in
    for _ in benchmark.scaledIterations {
      blackHole(Foundation.Date())
    }
  }

  testName = "P90Malloc"
  Benchmark(testName, configuration: makeConfigurationFor(testName)) { benchmark in
    for _ in benchmark.scaledIterations {
      var array: [Int] = []
      array.append(contentsOf: 0 ... 1_000)
      blackHole(array)
    }
  }
}
```

### Example GitHub CI workflow comparing against a baseline

The following GitHub workflow provides an example of comparing any pull request against the `main` branch of your repository, failing on a comparison regression.
If the comparison is equal or favorable, it comments the pull request with the comparison. 

```yaml
name: Benchmark PR vs main

on:
  workflow_dispatch:
  pull_request:
    branches: [ main ]
  
jobs:
  benchmark-delta:

    runs-on: ${{ matrix.os }}
    continue-on-error: true
    permissions:
        issues: write
        pull-requests: write

    strategy:
      matrix:
        #os: [[Linux, benchmark-swift-latest, self-hosted]]
        os: [ubuntu-latest]

    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0

      - name: Homebrew Mac
        if: ${{ runner.os == 'Macos' }}
        run: |
          echo "/opt/homebrew/bin:/usr/local/bin" >> $GITHUB_PATH
          brew install jemalloc

      - name: Ubuntu deps
        if: ${{ runner.os == 'Linux' }}
        run: |
          sudo apt-get install -y libjemalloc-dev

      - name: Git URL token override and misc
        run: |
          #git config --global url."https://ordo-ci:${{ secrets.CI_MACHINE_PAT }}@github.com".insteadOf "https://github.com"
          #/usr/bin/ordo-performance
          [ -d Benchmarks ] && echo "hasBenchmark=1" >> $GITHUB_ENV
          echo "/opt/homebrew/bin:/usr/local/bin" >> $GITHUB_PATH
      - name: Run benchmarks for PR branch
        if: ${{ env.hasBenchmark == '1' }}
        run: |
          swift package --allow-writing-to-directory .benchmarkBaselines/ benchmark baseline update pull_request --no-progress --quiet
      - name: Switch to branch 'main'
        if: ${{ env.hasBenchmark == '1' }}
        run: |
          git stash
          git checkout main
      - name: Run benchmarks for branch 'main'
        if: ${{ env.hasBenchmark == '1' }}
        run: |
          swift package --allow-writing-to-directory .benchmarkBaselines/ benchmark baseline update main --no-progress --quiet
      - name: Compare PR and main
        if: ${{ env.hasBenchmark == '1' }}
        id: benchmark
        run: |
          echo '## Summary' >> $GITHUB_STEP_SUMMARY
          echo $(date) >> $GITHUB_STEP_SUMMARY
          echo "exitStatus=1" >> $GITHUB_ENV
          swift package benchmark baseline check main pull_request --format markdown >> $GITHUB_STEP_SUMMARY
          echo '---' >> $GITHUB_STEP_SUMMARY
          swift package benchmark baseline compare main pull_request --no-progress --quiet --format markdown >> $GITHUB_STEP_SUMMARY
          echo "exitStatus=0" >> $GITHUB_ENV
        continue-on-error: true
      - if: ${{ env.exitStatus == '0' }}
        name: Pull request comment text success
        id: prtestsuccess
        run: |
          echo 'PRTEST<<EOF' >> $GITHUB_ENV
          echo "[Pull request benchmark comparison [${{ matrix.os }}] with 'main' run at $(date -Iseconds)](https://github.com/ordo-one/${{ github.event.repository.name }}/actions/runs/${{ github.run_id }})" >> $GITHUB_ENV
          echo 'EOF' >> $GITHUB_ENV
      - if: ${{ env.exitStatus == '1' }}
        name: Pull request comment text failure
        id: prtestfailure
        run: |
          echo 'PRTEST<<EOF' >> $GITHUB_ENV
          echo "[Pull request benchmark comparison [${{ matrix.os }}] with 'main' run at $(date -Iseconds)](https://github.com/ordo-one/${{ github.event.repository.name }}/actions/runs/${{ github.run_id }})" >> $GITHUB_ENV
          echo "_Pull request had performance regressions_" >> $GITHUB_ENV
          echo 'EOF' >> $GITHUB_ENV
      - name: Comment PR
        if: ${{ env.hasBenchmark == '1' }}
        uses: thollander/actions-comment-pull-request@v2
        with:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          message: ${{ env.PRTEST }}
          comment_includes: "Pull request benchmark comparison [${{ matrix.os }}] with"
      - name: Exit with correct status
        run: |
          exit ${{ env.exitStatus }}
```

> Important: For reproducible and good comparable results, it is *highly* recommended to set up a private GitHub runner on a machine dedicated to performance benchmark runs.
