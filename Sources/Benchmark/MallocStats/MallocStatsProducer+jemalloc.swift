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
#if swift(>=5.8)
    @_documentation(visibility: internal)
#endif
class MallocStatsProducer {
    var threadCacheMIB: [size_t]
    var epochMIB: [size_t]
//    var smallNMallocMIB: [size_t]
//    var largeNMallocMIB: [size_t]
//    var smallNDallocMIB: [size_t]
//    var largeNDallocMIB: [size_t]
//    var smallAlloctedMIB: [size_t]
//    var largeAllocatedMIB: [size_t]
    var totalAllocatedMIB: [size_t]
    var smallNRequestsMIB: [size_t]
    var largeNRequestsMIB: [size_t]
//    var smallNFillsMIB: [size_t]
//    var largeNFillsMIB: [size_t]

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
    init() {
        func setupMIB(name: String) -> [size_t] {
            precondition(!name.split(separator: ".").isEmpty, "setupMIB with 0 count")
            var mib = [size_t](repeating: 0, count: name.split(separator: ".").count)
            var mibSize = mib.count
            mib.withUnsafeMutableBufferPointer { pointer in
                let result = mallctlnametomib(name, pointer.baseAddress, &mibSize)
                if result != 0 {
                    print("mallctlnametomib \(name) returned \(result)")
                }
            }
            return mib
        }

        epochMIB = setupMIB(name: "epoch")
        threadCacheMIB = setupMIB(name: "thread.tcache.flush")
        smallNRequestsMIB = setupMIB(name: "stats.arenas.\(MALLCTL_ARENAS_ALL).small.nrequests")
        largeNRequestsMIB = setupMIB(name: "stats.arenas.\(MALLCTL_ARENAS_ALL).large.nrequests")
        totalAllocatedMIB = setupMIB(name: "stats.resident")
//        smallNMallocMIB = setupMIB(name: "stats.arenas.\(MALLCTL_ARENAS_ALL).small.nmalloc")
//        largeNMallocMIB = setupMIB(name: "stats.arenas.\(MALLCTL_ARENAS_ALL).large.nmalloc")
//        smallNDallocMIB = setupMIB(name: "stats.arenas.\(MALLCTL_ARENAS_ALL).small.ndalloc")
//        largeNDallocMIB = setupMIB(name: "stats.arenas.\(MALLCTL_ARENAS_ALL).large.ndalloc")
//        smallAlloctedMIB = setupMIB(name: "stats.arenas.\(MALLCTL_ARENAS_ALL).small.allocated")
//        largeAllocatedMIB = setupMIB(name: "stats.arenas.\(MALLCTL_ARENAS_ALL).large.allocated")
//        smallNFillsMIB = setupMIB(name: "stats.arenas.\(MALLCTL_ARENAS_ALL).small.nfills")
//        largeNFillsMIB = setupMIB(name: "stats.arenas.\(MALLCTL_ARENAS_ALL).large.nfills")
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
        let allocationsCountSmall = readStats(smallNRequestsMIB)
        let allocationsCountLarge = readStats(largeNRequestsMIB)
        let allocatedResidentMemory = readStats(totalAllocatedMIB)
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
