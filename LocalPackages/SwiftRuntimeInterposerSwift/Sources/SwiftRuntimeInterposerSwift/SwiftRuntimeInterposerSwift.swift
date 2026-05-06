//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

import SwiftRuntimeInterposerC

public final class SwiftRuntimeInterposerSwift: @unchecked Sendable {
    private init() {}

    public static func initialize() {
        swift_runtime_interposer_reset()
    }

    public static func hook() {
        swift_runtime_interposer_reset()
        swift_runtime_interposer_enable()
    }

    public static func unhook() {
        swift_runtime_interposer_disable()
    }

    public static func reset() {
        swift_runtime_interposer_reset()
    }

    public static func getStatistics() -> Statistics {
        var allocCount: Int64 = 0
        var retainCount: Int64 = 0
        var releaseCount: Int64 = 0
        swift_runtime_interposer_get_stats(&allocCount, &retainCount, &releaseCount)
        return Statistics(
            objectAllocCount: Int(allocCount),
            retainCount: Int(retainCount),
            releaseCount: Int(releaseCount)
        )
    }
}

public extension SwiftRuntimeInterposerSwift {
    struct Statistics {
        public let objectAllocCount: Int
        public let retainCount: Int
        public let releaseCount: Int

        public init(
            objectAllocCount: Int = 0,
            retainCount: Int = 0,
            releaseCount: Int = 0
        ) {
            self.objectAllocCount = objectAllocCount
            self.retainCount = retainCount
            self.releaseCount = releaseCount
        }
    }
}
