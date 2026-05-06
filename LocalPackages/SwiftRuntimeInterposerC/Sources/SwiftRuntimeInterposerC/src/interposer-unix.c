//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef __APPLE__

#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stddef.h>

#include <interposer.h>

typedef void *(*type_swift_allocObject)(const void *, size_t, size_t);
typedef void *(*type_swift_retain)(void *);
typedef void (*type_swift_release)(void *);

static _Atomic type_swift_allocObject g_swift_allocObject;
static _Atomic type_swift_retain g_swift_retain;
static _Atomic type_swift_release g_swift_release;

static _Atomic bool g_counting_enabled = false;
static _Atomic int64_t g_alloc_count = 0;
static _Atomic int64_t g_retain_count = 0;
static _Atomic int64_t g_release_count = 0;

static __thread bool g_in_swift_allocObject = false;
static __thread bool g_in_swift_retain = false;
static __thread bool g_in_swift_release = false;

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

static type_swift_allocObject resolve_swift_allocObject(void) {
    type_swift_allocObject local_fun = atomic_load(&g_swift_allocObject);
    if (!local_fun && !g_in_swift_allocObject) {
        g_in_swift_allocObject = true;
        type_swift_allocObject desired = dlsym(RTLD_NEXT, "swift_allocObject");
        g_in_swift_allocObject = false;
        if (atomic_compare_exchange_strong(&g_swift_allocObject, &local_fun, desired)) {
            local_fun = desired;
        } else {
            local_fun = atomic_load(&g_swift_allocObject);
        }
    }
    return local_fun;
}

static type_swift_retain resolve_swift_retain(void) {
    type_swift_retain local_fun = atomic_load(&g_swift_retain);
    if (!local_fun && !g_in_swift_retain) {
        g_in_swift_retain = true;
        type_swift_retain desired = dlsym(RTLD_NEXT, "swift_retain");
        g_in_swift_retain = false;
        if (atomic_compare_exchange_strong(&g_swift_retain, &local_fun, desired)) {
            local_fun = desired;
        } else {
            local_fun = atomic_load(&g_swift_retain);
        }
    }
    return local_fun;
}

static type_swift_release resolve_swift_release(void) {
    type_swift_release local_fun = atomic_load(&g_swift_release);
    if (!local_fun && !g_in_swift_release) {
        g_in_swift_release = true;
        type_swift_release desired = dlsym(RTLD_NEXT, "swift_release");
        g_in_swift_release = false;
        if (atomic_compare_exchange_strong(&g_swift_release, &local_fun, desired)) {
            local_fun = desired;
        } else {
            local_fun = atomic_load(&g_swift_release);
        }
    }
    return local_fun;
}

void *swift_allocObject(const void *metadata, size_t requiredSize, size_t requiredAlignmentMask) {
    type_swift_allocObject original = resolve_swift_allocObject();
    if (!original) {
        return NULL;
    }

    void *object = original(metadata, requiredSize, requiredAlignmentMask);
    if (object && atomic_load_explicit(&g_counting_enabled, memory_order_relaxed)) {
        atomic_fetch_add_explicit(&g_alloc_count, 1, memory_order_relaxed);
    }
    return object;
}

void *swift_retain(void *object) {
    type_swift_retain original = resolve_swift_retain();
    if (!original) {
        return object;
    }

    void *result = original(object);
    if (object && atomic_load_explicit(&g_counting_enabled, memory_order_relaxed)) {
        atomic_fetch_add_explicit(&g_retain_count, 1, memory_order_relaxed);
    }
    return result;
}

void swift_release(void *object) {
    type_swift_release original = resolve_swift_release();
    if (!original) {
        return;
    }

    original(object);
    if (object && atomic_load_explicit(&g_counting_enabled, memory_order_relaxed)) {
        atomic_fetch_add_explicit(&g_release_count, 1, memory_order_relaxed);
    }
}

#endif
