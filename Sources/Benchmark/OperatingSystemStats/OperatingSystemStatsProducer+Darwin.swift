//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)

    import CDarwinOperatingSystemStats
    import Darwin
    import Dispatch

    final class OperatingSystemStatsProducer {
        var nsPerMachTick: Double
        var nsPerSchedulerTick: Int

        let lock = NIOLock()
        let semaphore = DispatchSemaphore(value: 0)
        var peakThreads: Int = 0
        var peakThreadsRunning: Int = 0
        var peakMemoryResident: Int = 0
        var peakMemoryVirtual: Int = 0
        var runState: RunState = .running
        var sampleRate: Int = 10_000
        var metrics: Set<BenchmarkMetric>?
        var pid = getpid()

        enum RunState {
            case running
            case shuttingDown
            case done
        }

        internal
        final class CallbackDataCarrier<T> {
            init(_ data: T) {
                self.data = data
            }

            var data: T
        }

        init() {
            var info = mach_timebase_info_data_t()

            mach_timebase_info(&info)

            nsPerMachTick = Double(info.numer) / Double(info.denom)

            let schedulerTicksPerSecond = sysconf(_SC_CLK_TCK)

            nsPerSchedulerTick = 1_000_000_000 / schedulerTicksPerSecond
        }

        #if os(macOS)
            fileprivate
            func getProcInfo() -> proc_taskinfo {
                var procTaskInfo = proc_taskinfo()
                let procTaskInfoSize = MemoryLayout<proc_taskinfo>.size

                let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &procTaskInfo, Int32(procTaskInfoSize))

                if result != procTaskInfoSize {
                    fatalError("proc_pidinfo returned an error \(errno)")
                }
                return procTaskInfo
            }

            struct IOStats {
                var bytesRead: UInt64 = 0
                var bytesWritten: UInt64 = 0
            }

            private func getRusage() -> rusage_info_current {
                var usage = rusage_info_current()

                let result = withUnsafeMutablePointer(to: &usage) {
                    $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                        proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, $0)
                    }
                }

                if result != 0 {
                    print("proc_pid_rusage returned an error \(errno)")
                }

                return usage
            }
        #endif

        func startSampling(_: Int = 10_000) { // sample rate in microseconds
            #if os(macOS)
                let sampleSemaphore = DispatchSemaphore(value: 0)

                DispatchQueue.global(qos: .userInitiated).async {
                    self.lock.lock()
                    let rate = self.sampleRate
                    self.peakThreads = 0
                    self.peakThreadsRunning = 0
                    self.peakMemoryResident = 0
                    self.peakMemoryVirtual = 0

                    self.runState = .running
                    var firstEventSampled = false
                    self.lock.unlock()

                    while true {
                        let procTaskInfo = self.getProcInfo()

                        self.lock.lock()
                        if procTaskInfo.pti_threadnum > self.peakThreads {
                            self.peakThreads = Int(procTaskInfo.pti_threadnum)
                        }

                        if procTaskInfo.pti_numrunning > self.peakThreadsRunning {
                            self.peakThreadsRunning = Int(procTaskInfo.pti_numrunning)
                        }

                        if procTaskInfo.pti_resident_size > self.peakMemoryResident {
                            self.peakMemoryResident = Int(procTaskInfo.pti_resident_size)
                        }

                        if procTaskInfo.pti_virtual_size > self.peakMemoryVirtual {
                            self.peakMemoryVirtual = Int(procTaskInfo.pti_virtual_size)
                        }

                        if self.runState == .shuttingDown {
                            self.runState = .done
                            self.semaphore.signal()
                        }

                        let quit = self.runState
                        self.lock.unlock()

                        if firstEventSampled == false { // allow calling thread to continue when we have captured a sample
                            firstEventSampled = true
                            sampleSemaphore.signal()
                        }

                        if quit == .done {
                            return
                        }

                        usleep(UInt32.random(in: UInt32(Double(rate) * 0.9) ... UInt32(Double(rate) * 1.1)))
                    }
                }

                // We'll need to wait for a single sample from the so we don't get 0 samples
                sampleSemaphore.wait()
            #endif
        }

        func stopSampling() {
            #if os(macOS)
                lock.withLock {
                    runState = .shuttingDown
                }
                semaphore.wait()
            #endif
        }

        func configureMetrics(_ metrics: Set<BenchmarkMetric>) {
            self.metrics = metrics
        }

        func makeOperatingSystemStats() -> OperatingSystemStats {
            #if os(macOS)
                guard let metrics else {
                    return .init()
                }

                let procTaskInfo = getProcInfo()
                let userTime = Int(nsPerMachTick * Double(procTaskInfo.pti_total_user))
                let systemTime = Int(nsPerMachTick * Double(procTaskInfo.pti_total_system))
                let totalTime = userTime + systemTime
                var threads = 0
                var threadsRunning = 0
                var peakResident = 0
                var peakVirtual = 0

                if metrics.contains(.threads) ||
                    metrics.contains(.threadsRunning) ||
                    metrics.contains(.peakMemoryResident) ||
                    metrics.contains(.peakMemoryResidentDelta) ||
                    metrics.contains(.peakMemoryVirtual) {
                    lock.lock()
                    threads = peakThreads
                    threadsRunning = peakThreadsRunning
                    peakResident = peakMemoryResident
                    peakVirtual = peakMemoryVirtual
                    lock.unlock()
                }

                var usage = rusage_info_current()

                if metrics.contains(.writeBytesPhysical) || 
                    metrics.contains(.writeBytesPhysical) ||
                    metrics.contains(.writeSyscalls) ||
                    metrics.contains(.instructions) {
                    usage = getRusage()
                }

                let stats = OperatingSystemStats(cpuUser: userTime,
                                                 cpuSystem: systemTime,
                                                 cpuTotal: totalTime,
                                                 peakMemoryResident: peakResident,
                                                 peakMemoryVirtual: peakVirtual,
                                                 syscalls: Int(procTaskInfo.pti_syscalls_unix) +
                                                     Int(procTaskInfo.pti_syscalls_mach),
                                                 contextSwitches: Int(procTaskInfo.pti_csw),
                                                 threads: threads,
                                                 threadsRunning: threadsRunning,
                                                 readSyscalls: 0,
                                                 writeSyscalls: Int(usage.ri_logical_writes),
                                                 readBytesLogical: 0,
                                                 writeBytesLogical: 0,
                                                 readBytesPhysical: Int(usage.ri_diskio_bytesread),
                                                 writeBytesPhysical: Int(usage.ri_diskio_byteswritten),
                                                 instructions: Int(usage.ri_instructions))

                return stats
            #else
                return .init()
            #endif
        }

        func metricSupported(_ metric: BenchmarkMetric) -> Bool {
            #if os(macOS)
                switch metric {
                case .readSyscalls:
                    return false
                case .writeBytesLogical:
                    return false
                case .readBytesLogical:
                    return false
                default:
                    return true
                }
            #else
                // No metrics supported due to lack of libproc.h
                return false
            #endif
        }
    }

#endif
