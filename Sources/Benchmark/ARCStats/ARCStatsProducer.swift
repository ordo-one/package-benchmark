//
// Copyright (c) 2023 Ordo One AB
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

import SwiftRuntimeInterposerSwift

// swiftlint:disable prefer_self_in_static_references

final class ARCStatsProducer {
    static func hook() {
        SwiftRuntimeInterposerSwift.hook()
    }

    static func unhook() {
        SwiftRuntimeInterposerSwift.unhook()
    }

    static func reset() {
        SwiftRuntimeInterposerSwift.reset()
    }

    static func makeARCStats() -> ARCStats {
        let statistics = SwiftRuntimeInterposerSwift.getStatistics()
        return ARCStats(
            objectAllocCount: statistics.objectAllocCount,
            retainCount: statistics.retainCount,
            releaseCount: statistics.releaseCount
        )
    }
}

// swiftlint:enable prefer_self_in_static_references
