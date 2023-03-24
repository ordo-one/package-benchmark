//
// Copyright (c) 2023 Ordo One AB
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

import SwiftRuntimeHooks
import Atomics

class ARCStatsProducer {
    typealias SwiftRuntimeHook = @convention(c) (UnsafeRawPointer?, UnsafeMutableRawPointer?) -> Void

    static var retainCount: UnsafeAtomic<Int> = .create(0)
    static var releaseCount: UnsafeAtomic<Int> = .create(0)

    // TODO: Review orderings used
    func hook() {
        let retainHook: SwiftRuntimeHook = { ptr, context in
            ARCStatsProducer.retainCount.wrappingIncrement(ordering: .relaxed)
        }

        let releaseHook: SwiftRuntimeHook = { ptr, context in
            ARCStatsProducer.releaseCount.wrappingIncrement(ordering: .relaxed)
        }

        swift_runtime_set_retain_hook(retainHook, nil)
        swift_runtime_set_release_hook(releaseHook, nil)

        ARCStatsProducer.retainCount.store(0, ordering: .relaxed)
        ARCStatsProducer.releaseCount.store(0, ordering: .relaxed)
    }

    func unhook() {
        swift_runtime_set_release_hook(nil, nil)
        swift_runtime_set_retain_hook(nil, nil)
    }

    func makeARCStats() -> ARCStats {
         ARCStats(retainCount: ARCStatsProducer.retainCount.load(ordering: .relaxed),
                  releaseCount: ARCStatsProducer.releaseCount.load(ordering: .relaxed))
    }
}
