//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

import Atomics
import Foundation
import MallocInterposerC
#if canImport(Glibc)
import Glibc
#endif

/// Swift-friendly hook types
public typealias MallocHook = @convention(c) (Int) -> Void
public typealias FreeHook = @convention(c) (UnsafeMutableRawPointer?) -> Void
public typealias CallocHook = @convention(c) (Int, Int) -> Void
public typealias ReallocHook = @convention(c) (UnsafeMutableRawPointer?, Int) -> Void
public typealias PosixMemalignHook = @convention(c) (UnsafeMutablePointer<UnsafeMutableRawPointer?>?, Int, Int) -> Void

#if canImport(Darwin)
public typealias MallocZoneHook = @convention(c) (UnsafeMutablePointer<malloc_zone_t>?, Int) -> Void
public typealias MallocZoneFreeHook = @convention(c) (UnsafeMutablePointer<malloc_zone_t>?, UnsafeMutableRawPointer?) -> Void
public typealias MallocZoneCallocHook = @convention(c) (UnsafeMutablePointer<malloc_zone_t>?, Int, Int) -> Void
public typealias MallocZoneReallocHook = @convention(c) (UnsafeMutablePointer<malloc_zone_t>?, UnsafeMutableRawPointer?, Int) -> Void
public typealias MallocZoneVallocHook = @convention(c) (UnsafeMutablePointer<malloc_zone_t>?, Int) -> Void
public typealias MallocZoneMemalignHook = @convention(c) (UnsafeMutablePointer<malloc_zone_t>?, Int, Int) -> Void
#endif

/// Main class for managing malloc interposition
public class MallocInterposerSwift: @unchecked Sendable {
    /// We use `UnsafeAtomic` in order to avoid malloc calls during interposition
    nonisolated(unsafe) private static var mallocCount: ManagedAtomic<Int>!
    nonisolated(unsafe) private static var mallocBytesCount: ManagedAtomic<Int>!
    nonisolated(unsafe) private static var freeCount: ManagedAtomic<Int>!
    nonisolated(unsafe) private static var freeBytesCount: ManagedAtomic<Int>!
    nonisolated(unsafe) private static var mallocSmallCount: ManagedAtomic<Int>!
    nonisolated(unsafe) private static var mallocLargeCount: ManagedAtomic<Int>!
    static let pageSize = getpagesize()

    private init() {}
    

    // Initialize the atomic counters before hooking
    // because ManagedAtomic calls into malloc
    public static func initialize() {
        mallocCount = ManagedAtomic(0)
        mallocBytesCount = ManagedAtomic(0)
        freeCount = ManagedAtomic(0)
        freeBytesCount = ManagedAtomic(0)
        mallocSmallCount = ManagedAtomic(0)
        mallocLargeCount = ManagedAtomic(0)
    }

    public static func hook() {

        let mallocHook: MallocHook = { size in
            MallocInterposerSwift.mallocCount.wrappingIncrement(ordering: .relaxed)
            MallocInterposerSwift.mallocBytesCount.wrappingIncrement(by: size, ordering: .relaxed)

            if size > MallocInterposerSwift.pageSize {
                MallocInterposerSwift.mallocLargeCount.wrappingIncrement(ordering: .relaxed)
            } else {
                MallocInterposerSwift.mallocSmallCount.wrappingIncrement(ordering: .relaxed)
            }
        }

        let freeHook: FreeHook = { pointer in
            MallocInterposerSwift.freeCount.wrappingIncrement(ordering: .relaxed)
            #if canImport(Darwin)
            let size = malloc_size(pointer)
            #else
            let size = malloc_usable_size(pointer)
            #endif
            MallocInterposerSwift.freeBytesCount.wrappingIncrement(by: size, ordering: .relaxed)
        }

        let callocHook: CallocHook = { num, size in
            MallocInterposerSwift.mallocCount.wrappingIncrement(ordering: .relaxed)
            let total = num * size
            MallocInterposerSwift.mallocBytesCount.wrappingIncrement(by: total, ordering: .relaxed)

            if total > MallocInterposerSwift.pageSize {
                MallocInterposerSwift.mallocLargeCount.wrappingIncrement(ordering: .relaxed)
            } else {
                MallocInterposerSwift.mallocSmallCount.wrappingIncrement(ordering: .relaxed)
            }
        }

        let reallocHook: ReallocHook = { pointer, size in
            MallocInterposerSwift.freeCount.wrappingIncrement(ordering: .relaxed)
            MallocInterposerSwift.mallocCount.wrappingIncrement(ordering: .relaxed)
            MallocInterposerSwift.mallocBytesCount.wrappingIncrement(by: size, ordering: .relaxed)

            if size > MallocInterposerSwift.pageSize {
                MallocInterposerSwift.mallocLargeCount.wrappingIncrement(ordering: .relaxed)
            } else {
                MallocInterposerSwift.mallocSmallCount.wrappingIncrement(ordering: .relaxed)
            }
        }

        let posixMemalignHook: PosixMemalignHook = { pointer, alignment, size in
            MallocInterposerSwift.mallocCount.wrappingIncrement(ordering: .relaxed)
            MallocInterposerSwift.mallocBytesCount.wrappingIncrement(by: size, ordering: .relaxed)

            if size > MallocInterposerSwift.pageSize {
                MallocInterposerSwift.mallocLargeCount.wrappingIncrement(ordering: .relaxed)
            } else {
                MallocInterposerSwift.mallocSmallCount.wrappingIncrement(ordering: .relaxed)
            }
        }

        #if canImport(Darwin)
        let mallocZoneHook: MallocZoneHook = { zone, size in
            MallocInterposerSwift.mallocCount.wrappingIncrement(ordering: .relaxed)
            MallocInterposerSwift.mallocBytesCount.wrappingIncrement(by: size, ordering: .relaxed)

            if size > MallocInterposerSwift.pageSize {
                MallocInterposerSwift.mallocLargeCount.wrappingIncrement(ordering: .relaxed)
            } else {
                MallocInterposerSwift.mallocSmallCount.wrappingIncrement(ordering: .relaxed)
            }
        }
        let mallocZoneFreeHook: MallocZoneFreeHook = { zone, pointer in
            MallocInterposerSwift.freeCount.wrappingIncrement(ordering: .relaxed)
        }
        let mallocZoneCallocHook: MallocZoneCallocHook = { zone, num, size in
            MallocInterposerSwift.mallocCount.wrappingIncrement(ordering: .relaxed)
            let total = num * size
            MallocInterposerSwift.mallocBytesCount.wrappingIncrement(by: total, ordering: .relaxed)

            if total > MallocInterposerSwift.pageSize {
                MallocInterposerSwift.mallocLargeCount.wrappingIncrement(ordering: .relaxed)
            } else {
                MallocInterposerSwift.mallocSmallCount.wrappingIncrement(ordering: .relaxed)
            }
        }
        let mallocZoneReallocHook: MallocZoneReallocHook = { zone, pointer, size in
            MallocInterposerSwift.freeCount.wrappingIncrement(ordering: .relaxed)
            MallocInterposerSwift.mallocCount.wrappingIncrement(ordering: .relaxed)
            MallocInterposerSwift.mallocBytesCount.wrappingIncrement(by: size, ordering: .relaxed)

            if size > MallocInterposerSwift.pageSize {
                MallocInterposerSwift.mallocLargeCount.wrappingIncrement(ordering: .relaxed)
            } else {
                MallocInterposerSwift.mallocSmallCount.wrappingIncrement(ordering: .relaxed)
            }
        }
        let mallocZoneVallocHook: MallocZoneVallocHook = { zone, size in
            MallocInterposerSwift.mallocCount.wrappingIncrement(ordering: .relaxed)
            MallocInterposerSwift.mallocBytesCount.wrappingIncrement(by: size, ordering: .relaxed)

            if size > MallocInterposerSwift.pageSize {
                MallocInterposerSwift.mallocLargeCount.wrappingIncrement(ordering: .relaxed)
            } else {
                MallocInterposerSwift.mallocSmallCount.wrappingIncrement(ordering: .relaxed)
            }
        }
        let mallocZoneMemalignHook: MallocZoneMemalignHook = { zone, alignment, size in
            MallocInterposerSwift.mallocCount.wrappingIncrement(ordering: .relaxed)
            MallocInterposerSwift.mallocBytesCount.wrappingIncrement(by: size, ordering: .relaxed)

            if size > MallocInterposerSwift.pageSize {
                MallocInterposerSwift.mallocLargeCount.wrappingIncrement(ordering: .relaxed)
            } else {
                MallocInterposerSwift.mallocSmallCount.wrappingIncrement(ordering: .relaxed)
            }
        }

        set_malloc_zone_hook(mallocZoneHook)
        set_malloc_zone_free_hook(mallocZoneFreeHook)
        set_malloc_zone_calloc_hook(mallocZoneCallocHook)
        set_malloc_zone_realloc_hook(mallocZoneReallocHook)
        set_malloc_zone_valloc_hook(mallocZoneVallocHook)
        set_malloc_zone_memalign_hook(mallocZoneMemalignHook)
        #endif

        set_malloc_hook(mallocHook)
        set_free_hook(freeHook)
        set_calloc_hook(callocHook)
        set_realloc_hook(reallocHook)
        set_posix_memalign_hook(posixMemalignHook)
    }

    public static func unhook() {
        set_malloc_hook(nil)
        set_free_hook(nil)
        set_calloc_hook(nil)
        set_realloc_hook(nil)
        set_posix_memalign_hook(nil)

        #if canImport(Darwin)
        set_malloc_zone_hook(nil)
        set_malloc_zone_free_hook(nil)
        set_malloc_zone_calloc_hook(nil)
        set_malloc_zone_realloc_hook(nil)
        set_malloc_zone_valloc_hook(nil)
        set_malloc_zone_memalign_hook(nil)
        #endif
    }

    public static func reset() {
        mallocCount.store(0, ordering: .relaxed)
        mallocBytesCount.store(0, ordering: .relaxed)
        freeCount.store(0, ordering: .relaxed)
        freeBytesCount.store(0, ordering: .relaxed)
        mallocSmallCount.store(0, ordering: .relaxed)
        mallocLargeCount.store(0, ordering: .relaxed)
    }

    public static func getStatistics() -> Statistics {
        let stats = Statistics(
            mallocCount: mallocCount.load(ordering: .relaxed),
            mallocBytesCount: mallocBytesCount.load(ordering: .relaxed),
            mallocSmallCount: mallocSmallCount.load(ordering: .relaxed),
            mallocLargeCount: mallocLargeCount.load(ordering: .relaxed),
            freeCount: freeCount.load(ordering: .relaxed),
            freeBytesCount: freeBytesCount.load(ordering: .relaxed)
        )

        return stats
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
