import Atomics
import Foundation
import MallocInterposerC

/// Swift-friendly hook types
public typealias MallocHook = @convention(c) (Int) -> Void
public typealias FreeHook = @convention(c) (UnsafeMutableRawPointer?) -> Void
public typealias CallocHook = @convention(c) (Int, Int) -> Void
public typealias ReallocHook = @convention(c) (UnsafeMutableRawPointer?, Int) -> Void

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
    nonisolated(unsafe) private static var mallocCountStorage = UnsafeAtomic<Int>.Storage.init(0)
    static let mallocCount = UnsafeAtomic<Int>.init(at: &mallocCountStorage)
    nonisolated(unsafe) private static var mallocBytesCountStorage = UnsafeAtomic<Int>.Storage.init(0)
    static let mallocBytesCount = UnsafeAtomic<Int>.init(at: &mallocBytesCountStorage)
    nonisolated(unsafe) private static var freeCountStorage = UnsafeAtomic<Int>.Storage(0)
    static let freeCount = UnsafeAtomic<Int>.init(at: &freeCountStorage)
    /// Clear all counters
    private static func clearAllCounters() {
        mallocCount.store(0, ordering: .relaxed)
        mallocBytesCount.store(0, ordering: .relaxed)
        freeCount.store(0, ordering: .relaxed)
    }

    private init() {}

    public static func hook() {
        clearAllCounters()

        let mallocHook: MallocHook = { size in
            MallocInterposerSwift.mallocCount.wrappingIncrement(ordering: .relaxed)
            MallocInterposerSwift.mallocBytesCount.wrappingIncrement(by: size, ordering: .relaxed)
        }

        let freeHook: FreeHook = { pointer in
            MallocInterposerSwift.freeCount.wrappingIncrement(ordering: .relaxed)
        }

        let callocHook: CallocHook = { num, size in
            MallocInterposerSwift.mallocCount.wrappingIncrement(ordering: .relaxed)
            MallocInterposerSwift.mallocBytesCount.wrappingIncrement(by: size, ordering: .relaxed)
        }

        let reallocHook: ReallocHook = { pointer, size in
            MallocInterposerSwift.freeCount.wrappingIncrement(ordering: .relaxed)
            MallocInterposerSwift.mallocCount.wrappingIncrement(ordering: .relaxed)
            MallocInterposerSwift.mallocBytesCount.wrappingIncrement(by: size, ordering: .relaxed)
        }

        #if canImport(Darwin)
        let mallocZoneHook: MallocZoneHook = { zone, size in
            MallocInterposerSwift.mallocCount.wrappingIncrement(ordering: .relaxed)
            MallocInterposerSwift.mallocBytesCount.wrappingIncrement(by: size, ordering: .relaxed)
        }
        let mallocZoneFreeHook: MallocZoneFreeHook = { zone, pointer in
            MallocInterposerSwift.freeCount.wrappingIncrement(ordering: .relaxed)
        }
        let mallocZoneCallocHook: MallocZoneCallocHook = { zone, num, size in
            MallocInterposerSwift.mallocCount.wrappingIncrement(ordering: .relaxed)
            MallocInterposerSwift.mallocBytesCount.wrappingIncrement(by: num * size, ordering: .relaxed)
        }
        let mallocZoneReallocHook: MallocZoneReallocHook = { zone, pointer, size in
            MallocInterposerSwift.freeCount.wrappingIncrement(ordering: .relaxed)
            MallocInterposerSwift.mallocCount.wrappingIncrement(ordering: .relaxed)
            MallocInterposerSwift.mallocBytesCount.wrappingIncrement(by: size, ordering: .relaxed)
        }
        let mallocZoneVallocHook: MallocZoneVallocHook = { zone, size in
            MallocInterposerSwift.mallocCount.wrappingIncrement(ordering: .relaxed)
            MallocInterposerSwift.mallocBytesCount.wrappingIncrement(by: size, ordering: .relaxed)
        }
        let mallocZoneMemalignHook: MallocZoneMemalignHook = { zone, alignment, size in
            MallocInterposerSwift.mallocCount.wrappingIncrement(ordering: .relaxed)
            MallocInterposerSwift.mallocBytesCount.wrappingIncrement(by: size, ordering: .relaxed)
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
    }

    public static func unhook() {
        set_malloc_hook(nil)
        set_free_hook(nil)
        set_calloc_hook(nil)
        set_realloc_hook(nil)

        #if canImport(Darwin)
        set_malloc_zone_hook(nil)
        set_malloc_zone_free_hook(nil)
        set_malloc_zone_calloc_hook(nil)
        set_malloc_zone_realloc_hook(nil)
        set_malloc_zone_valloc_hook(nil)
        set_malloc_zone_memalign_hook(nil)
        #endif
    }

    public static func getStatistics() -> Statistics {
        let stats = Statistics(
            mallocCount: mallocCount.load(ordering: .relaxed),
            mallocBytesCount: mallocBytesCount.load(ordering: .relaxed),
            freeCount: freeCount.load(ordering: .relaxed)
        )

        return stats
    }
}

public extension MallocInterposerSwift {
    struct Statistics {
        public let mallocCount: Int
        public let mallocBytesCount: Int
        public let freeCount: Int

        public init(mallocCount: Int, mallocBytesCount: Int, freeCount: Int) {
            self.mallocCount = mallocCount
            self.mallocBytesCount = mallocBytesCount
            self.freeCount = freeCount
        }
    }
}
