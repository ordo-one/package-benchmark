//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

// This is a standin for the real Duration/Instant types coming in Swift 5.7
// We use these as placeholders to hopefully make it easier to migrate to the
// proper types in the future.

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
    import Darwin
#elseif os(Linux) || os(FreeBSD) || os(Android)
    import Glibc
#else
    #error("Unsupported Platform")
#endif

// Fake Instant for now

public typealias TimeInstant = UInt64 // should be changed to Instant when macOS 13 lands and is adopted

public extension TimeInstant {
    func advanced(by duration: TimeDuration) -> Self {
        self + duration
    }

    func duration(to other: Self) -> TimeDuration {
        self - other
    }

    static var now: TimeInstant {
        #if os(macOS)
            return clock_gettime_nsec_np(CLOCK_UPTIME_RAW) // to get ns resolution on macOS
        #elseif os(Linux)
            var timespec = timespec()
            let result = clock_gettime(CLOCK_REALTIME, &timespec)

            guard result == 0 else {
                fatalError("Failed to get current time in clock_gettime(), errno = \(errno)")
            }

            return UInt64(Int64(timespec.tv_sec) * 1_000_000_000 + Int64(timespec.tv_nsec))
        #else
            #error("Unsupported Platform")
        #endif
    }
}

// Look & feel of a Duration until it becomes available for real

public typealias TimeDuration = UInt64 // should be changed to Duration when macOS 13 lands and is adopted

public extension TimeDuration {
    static func hours(_ hours: Int) -> TimeDuration {
        UInt64(hours) * 1_000_000_000 * 60 * 60
    }

    static func minutes(_ minutes: Int) -> TimeDuration {
        UInt64(minutes) * 1_000_000_000 * 60
    }

    static func seconds(_ seconds: Int) -> TimeDuration {
        UInt64(seconds) * 1_000_000_000
    }

    static func microseconds(_ microseconds: Int) -> TimeDuration {
        UInt64(microseconds) * 1_000
    }

    static func milliseconds(_ milliseconds: Int) -> TimeDuration {
        UInt64(milliseconds) * 1_000_000
    }

    static func nanoseconds(_ value: Int) -> TimeDuration {
        UInt64(value)
    }

    static func nanoseconds(_ value: UInt64) -> TimeDuration {
        value
    }
}
