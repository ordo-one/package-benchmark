//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

import Foundation
import MallocInterposerC
import MallocInterposerSwift

@main
enum TestClient {

    @_optimize(none)
    static func blackHole(_ value: Any) {

    }

    static func performAllocations(count: Int, size: Int, shouldFree: Bool = true) {
        var index = 0
        repeat {
            let x = malloc(size)
            if shouldFree {
                free(x)
            }
            index += 1
        } while index < count
    }


    @_optimize(none)
    static func main() {
        print("=== MallocInterposerSwift Test ===")
        // Reset statistics to start clean
        MallocInterposerSwift.initialize()
        MallocInterposerSwift.hook()

//        let ptr = malloc(1000)
//        let ptr2 = malloc(500)
//
//        free(ptr)
//        free(ptr2)

      //  let x: UnsafeMutablePointer<Int> = UnsafeMutablePointer.allocate(capacity: 5000)

        performAllocations(count: 1, size: 11 * 1024 * 1024)
        //performAllocations(count: 1, size: 32 * 1024 * 1024, shouldFree: false)


        MallocInterposerSwift.unhook()

        // Print final statistics
        let stats = MallocInterposerSwift.getStatistics()

        print("Total malloc count: \(stats.mallocCount)")
        print("Malloc small count: \(stats.mallocSmallCount)")
        print("Malloc large count: \(stats.mallocLargeCount)")
        print("Total allocated memory: \(stats.mallocBytesCount) bytes")
        print("Total free count: \(stats.freeCount)")
        print("Total freed memory: \(stats.freeBytesCount) bytes")

        print("\n--- Test complete ---")
    }
}
