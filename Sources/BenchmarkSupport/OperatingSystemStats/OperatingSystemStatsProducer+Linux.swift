//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

#if os(Linux)
    import CLinuxOperatingSystemStats
    import Dispatch
    import Glibc
    import SystemPackage

    public class OperatingSystemStatsProducer {
        var nsPerSchedulerTick: Int
        var pageSize: Int

        let lock = NIOLock()
        let semaphore = DispatchSemaphore(value: 0)
        var peakThreads: Int = 0
        var sampleRate: Int = 10_000
        var runState: RunState = .running

        enum RunState {
            case running
            case shuttingDown
            case done
        }

        public init() {
            let schedulerTicksPerSecond = sysconf(Int32(_SC_CLK_TCK))

            nsPerSchedulerTick = 1_000_000_000 / schedulerTicksPerSecond
            pageSize = sysconf(Int32(_SC_PAGESIZE))
        }

        deinit {}

        // We should cache the open file(s) and just read from file offset 0 to reduce overhead
        func read(path: FilePath) -> String {
            var string = ""

            do {
                let fileDescriptor = try FileDescriptor.open(path, .readOnly, options: [], permissions: .ownerRead)
                do {
                    try fileDescriptor.closeAfter {
                        do {
                            let fileData = try [UInt8](unsafeUninitializedCapacity: 1_024) { buf, count in
                                count = try fileDescriptor.read(into: UnsafeMutableRawBufferPointer(buf))
                            }

                            fileData.withUnsafeBufferPointer {
                                string = String(cString: $0.baseAddress!)
                            }
                        } catch {
                            print("Failed to open file for reading \(path)")
                        }
                    }
                } catch {
                    print("Failed to close fileDescriptor for \(path) after reading.")
                }
            } catch {
                if errno != ENOENT { // file not found is ok, e.g. when no baselines exist
                    print("Failed to open file \(path), errno = [\(errno)]")
                }
            }

            return string
        }

        func readIOStats() -> ioStats {
            let stats = read(path: FilePath("/proc/self/io"))
            var ioStats: ioStats = .init()
            CLinuxIOStats(stats, &ioStats)
            return ioStats
        }

        func readProcessStats() -> processStats {
            let statsRead = read(path: FilePath("/proc/self/stat"))

            var stats: processStats = .init()
            CLinuxProcessStats(statsRead, &stats)
            stats.cpuUser *= nsPerSchedulerTick
            stats.cpuSystem *= nsPerSchedulerTick
            stats.cpuTotal *= nsPerSchedulerTick
            stats.peakMemoryResident *= pageSize

            return stats
        }

        func makeOperatingSystemStats() -> OperatingSystemStats {
            let ioStats = readIOStats()
            let processStats = readProcessStats()

            return OperatingSystemStats(cpuUser: Int(processStats.cpuUser),
                                        cpuSystem: Int(processStats.cpuSystem),
                                        cpuTotal: Int(processStats.cpuTotal),
                                        peakMemoryResident: Int(processStats.peakMemoryResident),
                                        peakMemoryVirtual: Int(processStats.peakMemoryVirtual),
                                        syscalls: 0,
                                        contextSwitches: 0,
                                        threads: Int(processStats.threads),
                                        threadsRunning: 0, // we can go dig in /proc/self/task/ later if want this
                                        readSyscalls: Int(ioStats.readSyscalls),
                                        writeSyscalls: Int(ioStats.writeSyscalls),
                                        readBytesLogical: Int(ioStats.readBytesLogical),
                                        writeBytesLogical: Int(ioStats.writeBytesLogical),
                                        readBytesPhysical: Int(ioStats.readBytesPhysical),
                                        writeBytesPhysical: Int(ioStats.writeBytesPhysical))
        }

        func metricSupported(_ metric: BenchmarkMetric) -> Bool {
            switch metric {
            case .syscalls:
                return false
            case .contextSwitches:
                return false
            case .threadsRunning:
                return false
            default:
                return true
            }
        }

        func startSampling(_: Int = 10_000) { // sample rate in microseconds
            DispatchQueue.global(qos: .userInitiated).async {
                self.lock.lock()

                let rate = self.sampleRate
                self.peakThreads = 0
                self.runState = .running

                self.lock.unlock()

                while true {
                    let processStats = self.readProcessStats()

                    self.lock.lock()

                    if processStats.threads > self.peakThreads {
                        self.peakThreads = processStats.threads
                    }

                    if self.runState == .shuttingDown {
                        self.runState = .done
                        self.semaphore.signal()
                    }

                    let quit = self.runState

                    self.lock.unlock()

                    if quit == .done {
                        return
                    }

                    usleep(UInt32.random(in: UInt32(Double(rate) * 0.9) ... UInt32(Double(rate) * 1.1)))
                }
            }
            // We'll sleep just a little bit to let the sampler thread get going so we try to avoid 0 samples
            usleep(1_000)
        }

        func stopSampling() {
            lock.lock()
            runState = .shuttingDown
            lock.unlock()

            semaphore.wait()
        }
    }

#endif
