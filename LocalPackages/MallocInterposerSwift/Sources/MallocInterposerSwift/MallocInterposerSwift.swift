//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

import MallocInterposerC

/// Main class for managing malloc interposition.
/// Counting is performed entirely in C using _Atomic int64_t globals,
/// so there is no Swift dispatch overhead on the malloc hot path.
public class MallocInterposerSwift: @unchecked Sendable {
    private init() {}

    /// Call once at startup (before hook()) to initialize C-side state.
    public static func initialize() {
        malloc_interposer_reset()
    }

    /// Start counting allocations.
    public static func hook() {
        malloc_interposer_reset()
        malloc_interposer_enable()
    }

    /// Stop counting allocations.
    public static func unhook() {
        malloc_interposer_disable()
    }

    /// Reset all counters to zero (counting state unchanged).
    public static func reset() {
        malloc_interposer_reset()
    }

    /// Read the current counter snapshot.
    public static func getStatistics() -> Statistics {
        var mallocCount: Int64 = 0
        var mallocBytes: Int64 = 0
        var mallocSmall: Int64 = 0
        var mallocLarge: Int64 = 0
        var freeCount: Int64 = 0
        var freeBytes: Int64 = 0
        malloc_interposer_get_stats(&mallocCount, &mallocBytes, &mallocSmall, &mallocLarge, &freeCount, &freeBytes)
        return Statistics(
            mallocCount: Int(mallocCount),
            mallocBytesCount: Int(mallocBytes),
            mallocSmallCount: Int(mallocSmall),
            mallocLargeCount: Int(mallocLarge),
            freeCount: Int(freeCount),
            freeBytesCount: Int(freeBytes)
        )
    }
}

public extension MallocInterposerSwift {
    struct Statistics {
        public let mallocCount: Int
        public let mallocBytesCount: Int
        public let mallocSmallCount: Int
        public let mallocLargeCount: Int
        public let freeCount: Int
        public let freeBytesCount: Int

        public init(
            mallocCount: Int = 0,
            mallocBytesCount: Int = 0,
            mallocSmallCount: Int = 0,
            mallocLargeCount: Int = 0,
            freeCount: Int = 0,
            freeBytesCount: Int = 0
        ) {
            self.mallocCount = mallocCount
            self.mallocBytesCount = mallocBytesCount
            self.mallocSmallCount = mallocSmallCount
            self.mallocLargeCount = mallocLargeCount
            self.freeCount = freeCount
            self.freeBytesCount = freeBytesCount
        }
    }
}
