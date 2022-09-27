// ===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2017-2018 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
// ===----------------------------------------------------------------------===//

// Adopted from SwiftNIO:s Lock, thanks!
// Changed to use os_unfair_lock on macOS and removed Windows lock support.

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#else
    #error("Unsupported Platform")
#endif

public final class Lock {
    #if os(macOS)
        fileprivate let mutex = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
    #else
        fileprivate let mutex: UnsafeMutablePointer<pthread_mutex_t> =
            UnsafeMutablePointer.allocate(capacity: 1)
    #endif

    /// Create a new lock.
    public init() {
        #if os(macOS)
            mutex.initialize(to: os_unfair_lock())
        #else
            var attr = pthread_mutexattr_t()
            pthread_mutexattr_init(&attr)

            let err = pthread_mutex_init(mutex, &attr)
            precondition(err == 0, "\(#function) failed in pthread_mutex with error \(err)")
        #endif
    }

    deinit {
        #if os(macOS)
            mutex.deinitialize(count: 1)
        #else
            let err = pthread_mutex_destroy(self.mutex)
            precondition(err == 0, "\(#function) failed in pthread_mutex with error \(err)")
        #endif
        mutex.deallocate()
    }

    /// Acquire the lock.
    ///
    /// Whenever possible, consider using `withLock` instead of this method and
    /// `unlock`, to simplify lock handling.
    public func lock() {
        #if os(macOS)
            os_unfair_lock_lock(mutex)
        #else
            let err = pthread_mutex_lock(mutex)
            precondition(err == 0, "\(#function) failed in pthread_mutex with error \(err)")
        #endif
    }

    /// Release the lock.
    ///
    /// Whenever possible, consider using `withLock` instead of this method and
    /// `lock`, to simplify lock handling.
    public func unlock() {
        #if os(macOS)
            os_unfair_lock_unlock(mutex)
        #else
            let err = pthread_mutex_unlock(mutex)
            precondition(err == 0, "\(#function) failed in pthread_mutex with error \(err)")
        #endif
    }
}

public extension Lock {
    /// Acquire the lock for the duration of the given block.
    ///
    /// This convenience method should be preferred to `lock` and `unlock` in
    /// most situations, as it ensures that the lock will be released regardless
    /// of how `body` exits.
    ///
    /// - Parameter body: The block to execute while holding the lock.
    /// - Returns: The value returned by the block.
    @inlinable
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer {
            self.unlock()
        }
        return try body()
    }

    // specialise Void return (for performance)
    @inlinable
    func withLockVoid(_ body: () throws -> Void) rethrows {
        try withLock(body)
    }
}

#if compiler(>=5.5) && canImport(_Concurrency)
    extension Lock: Sendable {}
#endif
