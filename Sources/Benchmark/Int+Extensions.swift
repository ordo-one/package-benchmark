//
// Copyright (c) 2023 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

public extension Int {
    static func hours(_ hours: Int) -> Int {
        hours * 1_000_000_000 * 60 * 60
    }

    static func minutes(_ minutes: Int) -> Int {
        minutes * 1_000_000_000 * 60
    }

    static func seconds(_ seconds: Int) -> Int {
        seconds * 1_000_000_000
    }

    static func milliseconds(_ milliseconds: Int) -> Int {
        milliseconds * 1_000_000
    }

    static func microseconds(_ microseconds: Int) -> Int {
        microseconds * 1_000
    }

    static func nanoseconds(_ value: Int) -> Int {
        value
    }

    static func nanoseconds(_ value: UInt) -> Int {
        Int(value)
    }

    static func giga(_ value: Int) -> Int {
        value * 1_000_000_000
    }

    static func mega(_ value: Int) -> Int {
        value * 1_000_000
    }

    static func kilo(_ value: Int) -> Int {
        value * 1_000
    }

    static func count(_ value: Int) -> Int {
        value
    }

    static func count(_ value: UInt) -> Int {
        Int(value)
    }
}
