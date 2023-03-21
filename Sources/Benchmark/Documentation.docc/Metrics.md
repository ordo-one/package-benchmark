# Metrics and Thresholds

Benchmarks supports a wide range of benchmark metrics and also allows you to create custom benchmark metrics.

## Overview

A fairly wide range of metrics can be captured by the benchmarks - most metrics are avilable on both macOS and Linux, but a few are not easily obtained and will thus not yield results on that platform, even if specified.

### Metrics

Currently supported metrics are:

- term `cpuUser`: CPU user space time spent for running the test
- term `cpuSystem`: CPU system time spent for running the test
- term `cpuTotal`: CPU total time spent for running the test (system + user)
- term `wallClock`: Wall clock time for running the test
- term `throughput`: The throughput in operations / second
- term `peakMemoryResident`: The resident memory usage - sampled during runtime
- term `peakMemoryVirtual`:  The virtual memory usage - sampled during runtime
- term `mallocCountSmall`: The number of small malloc calls according to jemalloc
- term `mallocCountLarge`: The number of large malloc calls according to jemalloc
- term `mallocCountTotal`: The total number of mallocs according to jemalloc
- term `allocatedResidentMemory`: The amount of allocated resident memory by the application (not including allocator metadata overhead etc) according to jemalloc
- term `memoryLeaked`: The number of small+large mallocs - small+large frees in resident memory (just a possible leak)
- term `syscalls`: The number of syscalls made during the test -- macOS only
- term `contextSwitches`: The number of context switches made during the test -- macOS only
- term `threads`: The maximum number of threads in the process under the test (not exact, sampled)
- term `threadsRunning`: The maximum number of threads actually running under the test (not exact, sampled) -- macOS only
- term `readSyscalls`: The number of I/O read syscalls performed e.g. read(2) / pread(2) -- Linux only
- term `writeSyscalls`: The number of I/O write syscalls performed e.g. write(2) / pwrite(2) -- Linux only
- term `readBytesLogical`: The number of bytes read from storage (but may be satisfied by pagecache!) -- Linux only
- term `writeBytesLogical`: The number bytes written to storage (but may be cached) -- Linux only
- term `readBytesPhysical`: The number of bytes physically read from a block device (i.e. disk) -- Linux only
- term `writeBytesPhysical`: The number of bytes physicall written to a block device (i.e. disk) -- Linux only

Additionally, _custom metrics_ are supported `custom(_ name: String, polarity: Polarity = .prefersSmaller, useScalingFactor: Bool = true)` as outlined in the writing benchmarks documentation.

### Thresholds

For comparison (`swift package benchmark baseline compare`) operations, there's a set of default thresholds that are used which are strict. It is also possible to define both absolute and relative thresholds, _per metric_, that will be used for such comparisons (or that a given metric should be skipped completely).

In addition to comparing the delta between e.g. a `PR` and `main`, there's also an option to compare against an absolute threshold which is useful for more complex projects that may want to reduce the size of the build matrix required to validate all thresholds. 

See <doc:WritingBenchmarks> or look at the sample code to see how custom thresholds can be set up.
