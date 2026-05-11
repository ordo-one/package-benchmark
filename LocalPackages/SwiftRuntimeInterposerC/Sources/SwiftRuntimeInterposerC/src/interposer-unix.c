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

typedef void *(*swift_allocObject_t)(const void *, size_t, size_t);
typedef void *(*swift_retain_t)(void *);
typedef void *(*swift_retain_n_t)(void *, uint32_t);
typedef void (*swift_release_t)(void *);
typedef void (*swift_release_n_t)(void *, uint32_t);

static _Atomic swift_allocObject_t s_swift_allocObject;
static _Atomic swift_retain_t s_swift_retain;
static _Atomic swift_retain_t s_swift_nonatomic_retain;
static _Atomic swift_retain_t s_swift_bridgeObjectRetain;
static _Atomic swift_retain_n_t s_swift_retain_n;
static _Atomic swift_retain_n_t s_swift_nonatomic_retain_n;
static _Atomic swift_retain_n_t s_swift_bridgeObjectRetain_n;
static _Atomic swift_release_t s_swift_release;
static _Atomic swift_release_t s_swift_nonatomic_release;
static _Atomic swift_release_t s_swift_bridgeObjectRelease;
static _Atomic swift_release_n_t s_swift_release_n;
static _Atomic swift_release_n_t s_swift_nonatomic_release_n;
static _Atomic swift_release_n_t s_swift_bridgeObjectRelease_n;

static _Atomic bool s_counting_enabled = false;
static _Atomic int64_t s_alloc_count = 0;
static _Atomic int64_t s_retain_count = 0;
static _Atomic int64_t s_release_count = 0;

static void swift_runtime_interposer_initialize(void) __attribute__((constructor));

static void *resolve_symbol(const char *symbol_name) {
    return dlsym(RTLD_NEXT, symbol_name);
}

static void swift_runtime_interposer_initialize(void) {
    atomic_store_explicit(
        &s_swift_allocObject,
        (swift_allocObject_t)resolve_symbol("swift_allocObject"),
        memory_order_relaxed
    );
    atomic_store_explicit(
        &s_swift_retain,
        (swift_retain_t)resolve_symbol("swift_retain"),
        memory_order_relaxed
    );
    atomic_store_explicit(
        &s_swift_nonatomic_retain,
        (swift_retain_t)resolve_symbol("swift_nonatomic_retain"),
        memory_order_relaxed
    );
    atomic_store_explicit(
        &s_swift_bridgeObjectRetain,
        (swift_retain_t)resolve_symbol("swift_bridgeObjectRetain"),
        memory_order_relaxed
    );
    atomic_store_explicit(
        &s_swift_retain_n,
        (swift_retain_n_t)resolve_symbol("swift_retain_n"),
        memory_order_relaxed
    );
    atomic_store_explicit(
        &s_swift_nonatomic_retain_n,
        (swift_retain_n_t)resolve_symbol("swift_nonatomic_retain_n"),
        memory_order_relaxed
    );
    atomic_store_explicit(
        &s_swift_bridgeObjectRetain_n,
        (swift_retain_n_t)resolve_symbol("swift_bridgeObjectRetain_n"),
        memory_order_relaxed
    );
    atomic_store_explicit(
        &s_swift_release,
        (swift_release_t)resolve_symbol("swift_release"),
        memory_order_relaxed
    );
    atomic_store_explicit(
        &s_swift_nonatomic_release,
        (swift_release_t)resolve_symbol("swift_nonatomic_release"),
        memory_order_relaxed
    );
    atomic_store_explicit(
        &s_swift_bridgeObjectRelease,
        (swift_release_t)resolve_symbol("swift_bridgeObjectRelease"),
        memory_order_relaxed
    );
    atomic_store_explicit(
        &s_swift_release_n,
        (swift_release_n_t)resolve_symbol("swift_release_n"),
        memory_order_relaxed
    );
    atomic_store_explicit(
        &s_swift_nonatomic_release_n,
        (swift_release_n_t)resolve_symbol("swift_nonatomic_release_n"),
        memory_order_relaxed
    );
    atomic_store_explicit(
        &s_swift_bridgeObjectRelease_n,
        (swift_release_n_t)resolve_symbol("swift_bridgeObjectRelease_n"),
        memory_order_relaxed
    );
}

void swift_runtime_interposer_enable(void) {
    atomic_store_explicit(&s_counting_enabled, true, memory_order_release);
}

void swift_runtime_interposer_disable(void) {
    atomic_store_explicit(&s_counting_enabled, false, memory_order_release);
}

void swift_runtime_interposer_reset(void) {
    atomic_store_explicit(&s_alloc_count, 0, memory_order_relaxed);
    atomic_store_explicit(&s_retain_count, 0, memory_order_relaxed);
    atomic_store_explicit(&s_release_count, 0, memory_order_relaxed);
    atomic_thread_fence(memory_order_release);
}

void swift_runtime_interposer_get_stats(
    int64_t *alloc_count,
    int64_t *retain_count,
    int64_t *release_count
) {
    *alloc_count = atomic_load_explicit(&s_alloc_count, memory_order_relaxed);
    *retain_count = atomic_load_explicit(&s_retain_count, memory_order_relaxed);
    *release_count = atomic_load_explicit(&s_release_count, memory_order_relaxed);
}

static swift_allocObject_t resolve_swift_allocObject(void) {
    return atomic_load_explicit(&s_swift_allocObject, memory_order_relaxed);
}

static swift_retain_t resolve_swift_retain(void) {
    return atomic_load_explicit(&s_swift_retain, memory_order_relaxed);
}

static swift_retain_t resolve_swift_nonatomic_retain(void) {
    return atomic_load_explicit(&s_swift_nonatomic_retain, memory_order_relaxed);
}

static swift_retain_t resolve_swift_bridgeObjectRetain(void) {
    return atomic_load_explicit(&s_swift_bridgeObjectRetain, memory_order_relaxed);
}

static swift_retain_n_t resolve_swift_retain_n(void) {
    return atomic_load_explicit(&s_swift_retain_n, memory_order_relaxed);
}

static swift_retain_n_t resolve_swift_nonatomic_retain_n(void) {
    return atomic_load_explicit(&s_swift_nonatomic_retain_n, memory_order_relaxed);
}

static swift_retain_n_t resolve_swift_bridgeObjectRetain_n(void) {
    return atomic_load_explicit(&s_swift_bridgeObjectRetain_n, memory_order_relaxed);
}

static swift_release_t resolve_swift_release(void) {
    return atomic_load_explicit(&s_swift_release, memory_order_relaxed);
}

static swift_release_t resolve_swift_nonatomic_release(void) {
    return atomic_load_explicit(&s_swift_nonatomic_release, memory_order_relaxed);
}

static swift_release_t resolve_swift_bridgeObjectRelease(void) {
    return atomic_load_explicit(&s_swift_bridgeObjectRelease, memory_order_relaxed);
}

static swift_release_n_t resolve_swift_release_n(void) {
    return atomic_load_explicit(&s_swift_release_n, memory_order_relaxed);
}

static swift_release_n_t resolve_swift_nonatomic_release_n(void) {
    return atomic_load_explicit(&s_swift_nonatomic_release_n, memory_order_relaxed);
}

static swift_release_n_t resolve_swift_bridgeObjectRelease_n(void) {
    return atomic_load_explicit(&s_swift_bridgeObjectRelease_n, memory_order_relaxed);
}

void *swift_allocObject(const void *metadata, size_t requiredSize, size_t requiredAlignmentMask) {
    swift_allocObject_t original = resolve_swift_allocObject();
    if (!original) {
        return NULL;
    }

    void *object = original(metadata, requiredSize, requiredAlignmentMask);
    if (object && atomic_load_explicit(&s_counting_enabled, memory_order_relaxed)) {
        atomic_fetch_add_explicit(&s_alloc_count, 1, memory_order_relaxed);
    }
    return object;
}

void *swift_retain(void *object) {
    swift_retain_t original = resolve_swift_retain();
    if (!original) {
        return object;
    }

    void *result = original(object);
    if (object && atomic_load_explicit(&s_counting_enabled, memory_order_relaxed)) {
        atomic_fetch_add_explicit(&s_retain_count, 1, memory_order_relaxed);
    }
    return result;
}

void *swift_nonatomic_retain(void *object) {
    swift_retain_t original = resolve_swift_nonatomic_retain();
    if (!original) {
        return object;
    }

    void *result = original(object);
    if (object && atomic_load_explicit(&s_counting_enabled, memory_order_relaxed)) {
        atomic_fetch_add_explicit(&s_retain_count, 1, memory_order_relaxed);
    }
    return result;
}

void *swift_bridgeObjectRetain(void *object) {
    swift_retain_t original = resolve_swift_bridgeObjectRetain();
    if (!original) {
        return object;
    }

    void *result = original(object);
    if (object && atomic_load_explicit(&s_counting_enabled, memory_order_relaxed)) {
        atomic_fetch_add_explicit(&s_retain_count, 1, memory_order_relaxed);
    }
    return result;
}

void *swift_retain_n(void *object, uint32_t n) {
    swift_retain_n_t original = resolve_swift_retain_n();
    if (!original) {
        return object;
    }

    void *result = original(object, n);
    if (object && atomic_load_explicit(&s_counting_enabled, memory_order_relaxed)) {
        atomic_fetch_add_explicit(&s_retain_count, n, memory_order_relaxed);
    }
    return result;
}

void *swift_nonatomic_retain_n(void *object, uint32_t n) {
    swift_retain_n_t original = resolve_swift_nonatomic_retain_n();
    if (!original) {
        return object;
    }

    void *result = original(object, n);
    if (object && atomic_load_explicit(&s_counting_enabled, memory_order_relaxed)) {
        atomic_fetch_add_explicit(&s_retain_count, n, memory_order_relaxed);
    }
    return result;
}

void *swift_bridgeObjectRetain_n(void *object, uint32_t n) {
    swift_retain_n_t original = resolve_swift_bridgeObjectRetain_n();
    if (!original) {
        return object;
    }

    void *result = original(object, n);
    if (object && atomic_load_explicit(&s_counting_enabled, memory_order_relaxed)) {
        atomic_fetch_add_explicit(&s_retain_count, n, memory_order_relaxed);
    }
    return result;
}

void swift_release(void *object) {
    swift_release_t original = resolve_swift_release();
    if (!original) {
        return;
    }

    original(object);
    if (object && atomic_load_explicit(&s_counting_enabled, memory_order_relaxed)) {
        atomic_fetch_add_explicit(&s_release_count, 1, memory_order_relaxed);
    }
}

void swift_nonatomic_release(void *object) {
    swift_release_t original = resolve_swift_nonatomic_release();
    if (!original) {
        return;
    }

    original(object);
    if (object && atomic_load_explicit(&s_counting_enabled, memory_order_relaxed)) {
        atomic_fetch_add_explicit(&s_release_count, 1, memory_order_relaxed);
    }
}

void swift_bridgeObjectRelease(void *object) {
    swift_release_t original = resolve_swift_bridgeObjectRelease();
    if (!original) {
        return;
    }

    original(object);
    if (object && atomic_load_explicit(&s_counting_enabled, memory_order_relaxed)) {
        atomic_fetch_add_explicit(&s_release_count, 1, memory_order_relaxed);
    }
}

void swift_release_n(void *object, uint32_t n) {
    swift_release_n_t original = resolve_swift_release_n();
    if (!original) {
        return;
    }

    original(object, n);
    if (object && atomic_load_explicit(&s_counting_enabled, memory_order_relaxed)) {
        atomic_fetch_add_explicit(&s_release_count, n, memory_order_relaxed);
    }
}

void swift_nonatomic_release_n(void *object, uint32_t n) {
    swift_release_n_t original = resolve_swift_nonatomic_release_n();
    if (!original) {
        return;
    }

    original(object, n);
    if (object && atomic_load_explicit(&s_counting_enabled, memory_order_relaxed)) {
        atomic_fetch_add_explicit(&s_release_count, n, memory_order_relaxed);
    }
}

void swift_bridgeObjectRelease_n(void *object, uint32_t n) {
    swift_release_n_t original = resolve_swift_bridgeObjectRelease_n();
    if (!original) {
        return;
    }

    original(object, n);
    if (object && atomic_load_explicit(&s_counting_enabled, memory_order_relaxed)) {
        atomic_fetch_add_explicit(&s_release_count, n, memory_order_relaxed);
    }
}

#endif
