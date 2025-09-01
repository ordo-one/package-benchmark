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
    static func main() {
        print("=== MallocInterposerSwift Test ===")
        // Reset statistics to start clean
        MallocInterposerSwift.hook()

        let ptr = malloc(1000)
        let ptr2 = malloc(500)

        free(ptr)
        free(ptr2)

        MallocInterposerSwift.unhook()

        // Print final statistics
        let stats = MallocInterposerSwift.getStatistics()

        print("Total malloc count: \(stats.mallocCount)")
        print("Total allocated memory: \(stats.mallocBytesCount) bytes")
        print("Total free count: \(stats.freeCount)")

        print("\n--- Test complete ---")
    }
}
