# Metrics and thresholds

A fairly wide range of metrics can be captured by the benchmarks - most metrics are avilable on both macOS and Linux, but a few are not easily obtained and will thus not yield results on that platform, even if specified. 

## Metrics
Currently supported metrics are:

* `cpuUser` - CPU user space time spent for running the test
* `cpuSystem` - CPU system time spent for running the test
* `cpuTotal` - CPU total time spent for running the test (system + user)
* `wallClock` - Wall clock time for running the test
* `throughput` - The throughput in operations / second
* `peakMemoryResident` - The resident memory usage - sampled during runtime
* `peakMemoryVirtual` -  The virtual memory usage - sampled during runtime
* `mallocCountSmall` - The number of small malloc calls according to jemalloc
* `mallocCountLarge` - The number of large malloc calls according to jemalloc
* `mallocCountTotal` - The total number of mallocs according to jemalloc
* `allocatedResidentMemory` - The amount of allocated resident memory by the application (not including allocator metadata overhead etc) according to jemalloc
* `memoryLeaked` -The number of small+large mallocs - small+large frees in resident memory (just a possible leak)
* `syscalls` - The number of syscalls made during the test -- macOS only
* `contextSwitches` - The number of context switches made during the test -- macOS only
* `threads` - The maximum number of threads in the process under the test (not exact, sampled)
* `threadsRunning` - The maximum number of threads actually running under the test (not exact, sampled) -- macOS only
* `readSyscalls` - The number of I/O read syscalls performed e.g. read(2) / pread(2) -- Linux only
* `writeSyscalls` - The number of I/O write syscalls performed e.g. write(2) / pwrite(2) -- Linux only
* `readBytesLogical` - The number of bytes read from storage (but may be satisfied by pagecache!) -- Linux only
* `writeBytesLogical` - The number bytes written to storage (but may be cached) -- Linux only
* `readBytesPhysical` - The number of bytes physically read from a block device (i.e. disk) -- Linux only
* `writeBytesPhysical` - The number of bytes physicall written to a block device (i.e. disk) -- Linux only
    
Additionally, _custom metrics_ are supported `custom(_ name: String, polarity: Polarity = .prefersSmaller)` as outlined in the writing benchmarks documentation.

## Thresholds

For comparison (`swift package benchmark compare`) operations, there's a set of default thresholds that are used which are fairly strict. It is also possible to define both absolute and relative thresholds, _per metric_, that will be used for such comparisons (or that a given metric should be skipped completely).

See the "writing benchmarks" documentation or look at the sample code to see how custom thresholds can be set up.
