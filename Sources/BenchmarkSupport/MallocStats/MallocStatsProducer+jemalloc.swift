//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

import ExtrasJSON
import jemalloc

// We currently register a number of MIB:s that aren't in use that
// was used during development to figure out most relevant stats,
// Keeping them around as we may want to expand malloc statistics
// to become more detailed.
public class MallocStatsProducer {
    var threadCacheMIB: [Int]
    var epochMIB: [Int]
//    var smallNMallocMIB: [Int]
//    var largeNMallocMIB: [Int]
//    var smallNDallocMIB: [Int]
//    var largeNDallocMIB: [Int]
//    var smallAlloctedMIB: [Int]
//    var largeAllocatedMIB: [Int]
    var totalAllocatedMIB: [Int]
    var smallTMallocMIB: [Int]
    var largeTMallocMIB: [Int]

    // Update jemalloc internal statistics, this is the magic incantation to do it
    @discardableResult
    func updateEpoch() -> Int {
        var allocated = 0
        var size = MemoryLayout<Int>.size
        var epoch = 0
        let epochSize = MemoryLayout<Int>.size
        var result: Int32 = 0

        // Must flush thread cache stats first
        result = mallctlbymib(threadCacheMIB, threadCacheMIB.count, nil, nil, nil, 0)
        if result != 0 {
            print("mallctlbymib threadCacheMIB returned \(result)")
        }

        // Then update epoch
        result = mallctlbymib(epochMIB, epochMIB.count, &allocated, &size, &epoch, epochSize)
        if result != 0 {
            print("mallctlbymib epochMIB returned \(result)")
        }

        return epoch
    }

    // Basically just set up a number of cached MIB structures for
    // more efficient queries later of malloc statistics.
    public init() {
        epochMIB = [size_t](repeating: 0, count: 1)
        totalAllocatedMIB = [size_t](repeating: 0, count: 2)
        threadCacheMIB = [size_t](repeating: 0, count: 3)
//        smallNMallocMIB = [size_t](repeating: 0, count: 5)
//        largeNMallocMIB = [size_t](repeating: 0, count: 5)
//        smallNDallocMIB = [size_t](repeating: 0, count: 5)
//        largeNDallocMIB = [size_t](repeating: 0, count: 5)
//        smallAlloctedMIB = [size_t](repeating: 0, count: 5)
//        largeAllocatedMIB = [size_t](repeating: 0, count: 5)
        smallTMallocMIB = [size_t](repeating: 0, count: 5)
        largeTMallocMIB = [size_t](repeating: 0, count: 5)

        var mibSize = threadCacheMIB.count
        threadCacheMIB.withUnsafeMutableBufferPointer { pointer in
            let result = mallctlnametomib("thread.tcache.flush", pointer.baseAddress, &mibSize)
            if result != 0 {
                print("mallctlnametomib threadCacheMIB returned \(result)")
            }
        }

        mibSize = epochMIB.count
        epochMIB.withUnsafeMutableBufferPointer { pointer in
            let result = mallctlnametomib("epoch", pointer.baseAddress, &mibSize)
            if result != 0 {
                print("mallctlnametomib epochMIB returned \(result)")
            }
        }
        /*
         mibSize = smallNMallocMIB.count
         smallNMallocMIB.withUnsafeMutableBufferPointer { pointer in
             let result = mallctlnametomib("stats.arenas.\(MALLCTL_ARENAS_ALL).small.nmalloc",
                                           pointer.baseAddress,
                                           &mibSize)
             if result != 0 {
                 print("mallctlnametomib smallNMallocMIB returned \(result)")
             }
         }

         mibSize = largeNMallocMIB.count
         largeNMallocMIB.withUnsafeMutableBufferPointer { pointer in
             let result = mallctlnametomib("stats.arenas.\(MALLCTL_ARENAS_ALL).large.nmalloc",
                                           pointer.baseAddress,
                                           &mibSize)
             if result != 0 {
                 print("mallctlnametomib largeNMallocMIB returned \(result)")
             }
         }
         */
        // tcaches
        mibSize = smallTMallocMIB.count
        smallTMallocMIB.withUnsafeMutableBufferPointer { pointer in
            let result = mallctlnametomib("stats.arenas.\(MALLCTL_ARENAS_ALL).small.nrequests",
                                          pointer.baseAddress,
                                          &mibSize)
            if result != 0 {
                print("mallctlnametomib smallTMallocMIB returned \(result)")
            }
        }

        mibSize = largeTMallocMIB.count
        largeTMallocMIB.withUnsafeMutableBufferPointer { pointer in
            let result = mallctlnametomib("stats.arenas.\(MALLCTL_ARENAS_ALL).large.nrequests",
                                          pointer.baseAddress,
                                          &mibSize)
            if result != 0 {
                print("mallctlnametomib largeTMallocMIB returned \(result)")
            }
        }
        /*
                mibSize = smallNDallocMIB.count
                smallNDallocMIB.withUnsafeMutableBufferPointer { pointer in
                    let result = mallctlnametomib("stats.arenas.\(MALLCTL_ARENAS_ALL).small.ndalloc",
                                                  pointer.baseAddress,
                                                  &mibSize)
                    if result != 0 {
                        print("mallctlnametomib smallNDallocMIB returned \(result)")
                    }
                }

                mibSize = largeNDallocMIB.count
                largeNDallocMIB.withUnsafeMutableBufferPointer { pointer in
                    let result = mallctlnametomib("stats.arenas.\(MALLCTL_ARENAS_ALL).large.ndalloc",
                                                  pointer.baseAddress,
                                                  &mibSize)
                    if result != 0 {
                        print("mallctlnametomib largeNDallocMIB returned \(result)")
                    }
                }

                mibSize = smallAlloctedMIB.count
                smallAlloctedMIB.withUnsafeMutableBufferPointer { pointer in
                    let result = mallctlnametomib("stats.arenas.\(MALLCTL_ARENAS_ALL).small.allocated",
                                                  pointer.baseAddress,
                                                  &mibSize)
                    if result != 0 {
                        print("mallctlnametomib rsmallAlloctedMIB eturned \(result)")
                    }
                }

                mibSize = largeAllocatedMIB.count
                largeAllocatedMIB.withUnsafeMutableBufferPointer { pointer in
                    let result = mallctlnametomib("stats.arenas.\(MALLCTL_ARENAS_ALL).large.allocated",
                                                  pointer.baseAddress,
                                                  &mibSize)
                    if result != 0 {
                        print("mallctlnametomib largeAllocatedMIB returned \(result)")
                    }
                }
         */
        mibSize = totalAllocatedMIB.count
        totalAllocatedMIB.withUnsafeMutableBufferPointer { pointer in
            let result = mallctlnametomib("stats.resident", pointer.baseAddress, &mibSize)
            if result != 0 {
                print("mallctlnametomib totalAllocatedMIB returned \(result)")
            }
        }
    }

    // Read the actual stats using a cached MIB as the key
    func readStats(_ mib: [Int]) -> Int {
        var allocated = 0
        var size = MemoryLayout<Int>.size

        if mallctlbymib(mib, mib.count, &allocated, &size, nil, 0) == 0 {
            return allocated
        }

        return 0
    }

    func makeMallocStats() -> MallocStats {
        updateEpoch()
        let allocationsCountSmall = readStats(smallTMallocMIB) // smallNMallocMIB + smallTMallocMIB ?
        let allocationsCountLarge = readStats(largeTMallocMIB) // largeNMallocMIB + largeTMallocMIB ?
        let allocatedResidentMemory = readStats(totalAllocatedMIB) // smallAlloctedMIB + largeAllocatedMIB ?
        return MallocStats(mallocCountTotal: allocationsCountSmall + allocationsCountLarge,
                           mallocCountSmall: allocationsCountSmall,
                           mallocCountLarge: allocationsCountLarge,
                           allocatedResidentMemory: allocatedResidentMemory)
    }

    // Finally we have some features to get to *all* jemalloc data, either as a json or
    // as a parsed struct tree using the definitons from `MallocStats+jemalloc-support.swift`
    // This is exhaustive complete information, but quite slow to extract - we may want to
    // provide an option for the user to dump this in the future if useful.

    class CallbackDataCarrier<T> {
        init(_ data: T) {
            self.data = data
        }

        var data: T
    }

    // Parsed stats for convenience, this is a heavy and slow operation not suitable for
    // being called within benchmark iterations
    func jemallocStatistics() -> Jemalloc? {
        // C style callback needs to use a class instance as a data carrier as we can't
        // capture state in a c-style closure, thus the dance with from/to Opaque.
        typealias CallbackType = @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?) -> Void
        let callback: CallbackType = { callbackCarrier, output in
            let carrier = Unmanaged<CallbackDataCarrier<[UInt8]>>.fromOpaque(callbackCarrier!).takeUnretainedValue()
            carrier.data.append(contentsOf: Array(String(cString: output!).utf8))
        }

        let carrier = CallbackDataCarrier<[UInt8]>([])

        malloc_stats_print(callback, UnsafeMutableRawPointer(Unmanaged.passUnretained(carrier.self).toOpaque()), "J")

        do {
            let mallocStats = try XJSONDecoder().decode(Pokedex.self, from: carrier.data)
            return mallocStats.jemalloc
        } catch {}

        return nil
    }

    // Full JSON with stats, this is a heavy and slow operation not suitable for
    // being called within benchmark iterations
    func jsonStatistics() -> String {
        // C style callback needs to use a class instance as a data carrier as we can't
        // capture state in a c-style closure, thus the dance with from/to Opaque.
        typealias CallbackType = @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?) -> Void
        let callback: CallbackType = { callbackCarrier, output in
            let carrier = Unmanaged<CallbackDataCarrier<String>>.fromOpaque(callbackCarrier!).takeUnretainedValue()
            carrier.data += String(cString: output!)
        }

        let carrier = CallbackDataCarrier<String>("")

        malloc_stats_print(callback, UnsafeMutableRawPointer(Unmanaged.passUnretained(carrier.self).toOpaque()), "J")

        return carrier.data
    }
}
