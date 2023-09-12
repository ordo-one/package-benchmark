//
// Copyright (c) 2023 Ordo One AB
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

import Atomics
import SwiftRuntimeHooks

// swiftlint:disable prefer_self_in_static_references

final class ARCStatsProducer {
    typealias SwiftRuntimeHook = @convention(c) (UnsafeRawPointer?, UnsafeMutableRawPointer?) -> Void

    static var allocCount: UnsafeAtomic<Int> = .create(0)
    static var retainCount: UnsafeAtomic<Int> = .create(0)
    static var releaseCount: UnsafeAtomic<Int> = .create(0)

    static func hook() {
        let allocObjectHook: SwiftRuntimeHook = { _, _ in
            ARCStatsProducer.allocCount.wrappingIncrement(ordering: .relaxed)
        }

        let retainHook: SwiftRuntimeHook = { _, _ in
            ARCStatsProducer.retainCount.wrappingIncrement(ordering: .relaxed)
        }

        let releaseHook: SwiftRuntimeHook = { _, _ in
            ARCStatsProducer.releaseCount.wrappingIncrement(ordering: .relaxed)
        }

        swift_runtime_set_alloc_object_hook(allocObjectHook, nil)
        swift_runtime_set_retain_hook(retainHook, nil)
        swift_runtime_set_release_hook(releaseHook, nil)
    }

    static func unhook() {
        swift_runtime_set_release_hook(nil, nil)
        swift_runtime_set_retain_hook(nil, nil)
        swift_runtime_set_alloc_object_hook(nil, nil)
    }

    static func reset() {
        allocCount.store(0, ordering: .relaxed)
        retainCount.store(0, ordering: .relaxed)
        releaseCount.store(0, ordering: .relaxed)
    }

    static func makeARCStats() -> ARCStats {
        ARCStats(objectAllocCount: allocCount.load(ordering: .relaxed),
                 retainCount: retainCount.load(ordering: .relaxed),
                 releaseCount: releaseCount.load(ordering: .relaxed))
    }
}

// swiftlint:enable prefer_self_in_static_references
