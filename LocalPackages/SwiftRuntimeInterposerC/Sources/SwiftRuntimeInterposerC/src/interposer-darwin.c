//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

#if __APPLE__

#include <stdatomic.h>
#include <stdbool.h>
#include <stddef.h>

#include <interposer.h>

static _Atomic bool g_counting_enabled = false;
static _Atomic int64_t g_alloc_count = 0;
static _Atomic int64_t g_retain_count = 0;
static _Atomic int64_t g_release_count = 0;

void swift_runtime_interposer_enable(void) {
    atomic_store_explicit(&g_counting_enabled, true, memory_order_release);
}

void swift_runtime_interposer_disable(void) {
    atomic_store_explicit(&g_counting_enabled, false, memory_order_release);
}

void swift_runtime_interposer_reset(void) {
    atomic_store_explicit(&g_alloc_count, 0, memory_order_relaxed);
    atomic_store_explicit(&g_retain_count, 0, memory_order_relaxed);
    atomic_store_explicit(&g_release_count, 0, memory_order_relaxed);
    atomic_thread_fence(memory_order_release);
}

void swift_runtime_interposer_get_stats(
    int64_t *alloc_count,
    int64_t *retain_count,
    int64_t *release_count
) {
    *alloc_count = atomic_load_explicit(&g_alloc_count, memory_order_relaxed);
    *retain_count = atomic_load_explicit(&g_retain_count, memory_order_relaxed);
    *release_count = atomic_load_explicit(&g_release_count, memory_order_relaxed);
}

#define DYLD_INTERPOSE(_replacement,_replacee) \
   __attribute__((used)) static struct { const void *replacement; const void *replacee; } _interpose_##_replacee \
            __attribute__ ((section("__DATA,__interpose"))) = { (const void *)(unsigned long)&_replacement, (const void *)(unsigned long)&_replacee };

void *replacement_swift_allocObject(const void *metadata, size_t requiredSize, size_t requiredAlignmentMask) {
    if (!swift_allocObject) {
        return NULL;
    }
    void *object = swift_allocObject(metadata, requiredSize, requiredAlignmentMask);
    if (object && atomic_load_explicit(&g_counting_enabled, memory_order_relaxed)) {
        atomic_fetch_add_explicit(&g_alloc_count, 1, memory_order_relaxed);
    }
    return object;
}

void *replacement_swift_retain(void *object) {
    if (!swift_retain) {
        return object;
    }
    void *result = swift_retain(object);
    if (object && atomic_load_explicit(&g_counting_enabled, memory_order_relaxed)) {
        atomic_fetch_add_explicit(&g_retain_count, 1, memory_order_relaxed);
    }
    return result;
}

void replacement_swift_release(void *object) {
    if (!swift_release) {
        return;
    }
    swift_release(object);
    if (object && atomic_load_explicit(&g_counting_enabled, memory_order_relaxed)) {
        atomic_fetch_add_explicit(&g_release_count, 1, memory_order_relaxed);
    }
}

DYLD_INTERPOSE(replacement_swift_allocObject, swift_allocObject)
DYLD_INTERPOSE(replacement_swift_retain, swift_retain)
DYLD_INTERPOSE(replacement_swift_release, swift_release)

#endif
