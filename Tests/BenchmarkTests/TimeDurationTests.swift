//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
///

import BenchmarkSupport
import XCTest

final class TimeDurationTests: XCTestCase {
    func testTimeInstantNow() throws {
        let start = TimeInstant.now
        usleep(100_000) // ~0.1s
        let stop = TimeInstant.now
        XCTAssert(stop - start > 90_000)
    }

    func testTimeInstantDuration() throws {
        let start = TimeInstant.now
        let stop = start + 1_234
        let duration = stop.duration(to: start)
        XCTAssert(duration == 1_234)
    }

    func testTimeInstantAdvance() throws {
        let start = TimeInstant.now
        let duration = start.advanced(by: 1_234)
        XCTAssert(duration == start + 1_234)
    }
}
