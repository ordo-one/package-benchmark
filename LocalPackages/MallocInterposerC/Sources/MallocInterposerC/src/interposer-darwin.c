//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

#include <assert.h>
#if __APPLE__

#define _GNU_SOURCE
#include <dlfcn.h>
#include <fcntl.h>
#include <inttypes.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <malloc/malloc.h>
#include <stdio.h>
#include <interposer.h>

// Counting state — all updated on the malloc hot path, so use relaxed atomics.
static _Atomic bool     g_counting_enabled = false;
static _Atomic int64_t  g_malloc_count  = 0;
static _Atomic int64_t  g_malloc_bytes  = 0;
static _Atomic int64_t  g_malloc_small  = 0;
static _Atomic int64_t  g_malloc_large  = 0;
static _Atomic int64_t  g_free_count    = 0;
static _Atomic int64_t  g_free_bytes    = 0;

// Cached page size for small/large classification
static int g_page_size = 0;

static int get_page_size(void) {
    if (__builtin_expect(g_page_size == 0, 0)) {
        g_page_size = (int)getpagesize();
    }
    return g_page_size;
}

// Public API ----------------------------------------------------------------

void malloc_interposer_enable(void) {
    atomic_store_explicit(&g_counting_enabled, true, memory_order_release);
}

void malloc_interposer_disable(void) {
    atomic_store_explicit(&g_counting_enabled, false, memory_order_release);
}

void malloc_interposer_reset(void) {
    atomic_store_explicit(&g_malloc_count, 0, memory_order_relaxed);
    atomic_store_explicit(&g_malloc_bytes, 0, memory_order_relaxed);
    atomic_store_explicit(&g_malloc_small, 0, memory_order_relaxed);
    atomic_store_explicit(&g_malloc_large, 0, memory_order_relaxed);
    atomic_store_explicit(&g_free_count,   0, memory_order_relaxed);
    atomic_store_explicit(&g_free_bytes,   0, memory_order_relaxed);
    atomic_thread_fence(memory_order_release);
}

void malloc_interposer_get_stats(int64_t *malloc_count, int64_t *malloc_bytes,
                                 int64_t *malloc_small, int64_t *malloc_large,
                                 int64_t *free_count, int64_t *free_bytes) {
    *malloc_count = atomic_load_explicit(&g_malloc_count, memory_order_relaxed);
    *malloc_bytes = atomic_load_explicit(&g_malloc_bytes, memory_order_relaxed);
    *malloc_small = atomic_load_explicit(&g_malloc_small, memory_order_relaxed);
    *malloc_large = atomic_load_explicit(&g_malloc_large, memory_order_relaxed);
    *free_count   = atomic_load_explicit(&g_free_count,   memory_order_relaxed);
    *free_bytes   = atomic_load_explicit(&g_free_bytes,   memory_order_relaxed);
}

// ---------------------------------------------------------------------------

#define DYLD_INTERPOSE(_replacement,_replacee) \
   __attribute__((used)) static struct { const void *replacement; const void *replacee; } _interpose_##_replacee \
            __attribute__ ((section("__DATA,__interpose"))) = { (const void *)(unsigned long)&_replacement, (const void *)(unsigned long)&_replacee };

/* on Darwin calling the original function is super easy, just call it, done. */
#define JUMP_INTO_LIBC_FUN(_fun, ...) /* \
*/ do { /* \
*/     return _fun(__VA_ARGS__); /* \
*/ } while(0)

// Inline counting helpers ---------------------------------------------------

static __attribute__((always_inline)) void count_malloc(size_t size) {
    atomic_fetch_add_explicit(&g_malloc_count, 1, memory_order_relaxed);
    atomic_fetch_add_explicit(&g_malloc_bytes, (int64_t)size, memory_order_relaxed);
    if ((int)size > get_page_size()) {
        atomic_fetch_add_explicit(&g_malloc_large, 1, memory_order_relaxed);
    } else {
        atomic_fetch_add_explicit(&g_malloc_small, 1, memory_order_relaxed);
    }
}

static __attribute__((always_inline)) void count_free(void *ptr) {
    size_t size = malloc_size(ptr);
    atomic_fetch_add_explicit(&g_free_count, 1, memory_order_relaxed);
    atomic_fetch_add_explicit(&g_free_bytes, (int64_t)size, memory_order_relaxed);
}

// Replacement functions -----------------------------------------------------

void replacement_free(void *ptr) {
    if (atomic_load_explicit(&g_counting_enabled, memory_order_relaxed)) {
        count_free(ptr);
    }
    JUMP_INTO_LIBC_FUN(free, ptr);
}

void *replacement_malloc(size_t size) {
    if (atomic_load_explicit(&g_counting_enabled, memory_order_relaxed)) {
        count_malloc(size);
    }
    JUMP_INTO_LIBC_FUN(malloc, size);
}

void *replacement_realloc(void *ptr, size_t size) {
    if (atomic_load_explicit(&g_counting_enabled, memory_order_relaxed)) {
        count_free(ptr);
        count_malloc(size);
    }
    JUMP_INTO_LIBC_FUN(realloc, ptr, size);
}

void *replacement_calloc(size_t count, size_t size) {
    if (atomic_load_explicit(&g_counting_enabled, memory_order_relaxed)) {
        count_malloc(count * size);
    }
    JUMP_INTO_LIBC_FUN(calloc, count, size);
}

void *replacement_malloc_zone_malloc(malloc_zone_t *zone, size_t size) {
    if (atomic_load_explicit(&g_counting_enabled, memory_order_relaxed)) {
        count_malloc(size);
    }
    JUMP_INTO_LIBC_FUN(malloc_zone_malloc, zone, size);
}

void *replacement_malloc_zone_calloc(malloc_zone_t *zone, size_t num_items, size_t size) {
    if (atomic_load_explicit(&g_counting_enabled, memory_order_relaxed)) {
        count_malloc(num_items * size);
    }
    JUMP_INTO_LIBC_FUN(malloc_zone_calloc, zone, num_items, size);
}

void *replacement_malloc_zone_valloc(malloc_zone_t *zone, size_t size) {
    if (atomic_load_explicit(&g_counting_enabled, memory_order_relaxed)) {
        count_malloc(size);
    }
    JUMP_INTO_LIBC_FUN(malloc_zone_valloc, zone, size);
}

void *replacement_malloc_zone_realloc(malloc_zone_t *zone, void *ptr, size_t size) {
    if (0 == size) {
        replacement_free(ptr);
        return NULL;
    }
    if (!ptr) {
        return replacement_malloc(size);
    }
    if (atomic_load_explicit(&g_counting_enabled, memory_order_relaxed)) {
        count_free(ptr);
        count_malloc(size);
    }
    JUMP_INTO_LIBC_FUN(realloc, ptr, size);
}

void *replacement_malloc_zone_memalign(malloc_zone_t *zone, size_t alignment, size_t size) {
    if (atomic_load_explicit(&g_counting_enabled, memory_order_relaxed)) {
        count_malloc(size);
    }
    JUMP_INTO_LIBC_FUN(malloc_zone_memalign, zone, alignment, size);
}

void replacement_malloc_zone_free(malloc_zone_t *zone, void *ptr) {
    if (atomic_load_explicit(&g_counting_enabled, memory_order_relaxed)) {
        atomic_fetch_add_explicit(&g_free_count, 1, memory_order_relaxed);
    }
    JUMP_INTO_LIBC_FUN(malloc_zone_free, zone, ptr);
}

void *replacement_reallocf(void *ptr, size_t size) {
    void *new_ptr = replacement_realloc(ptr, size);
    if (!new_ptr) {
        replacement_free(new_ptr);
    }
    return new_ptr;
}

void *replacement_valloc(size_t size) {
    if (atomic_load_explicit(&g_counting_enabled, memory_order_relaxed)) {
        count_malloc(size);
    }
    JUMP_INTO_LIBC_FUN(valloc, size);
}

int replacement_posix_memalign(void **memptr, size_t alignment, size_t size) {
    if (atomic_load_explicit(&g_counting_enabled, memory_order_relaxed)) {
        count_malloc(size);
    }
    JUMP_INTO_LIBC_FUN(posix_memalign, memptr, alignment, size);
}

DYLD_INTERPOSE(replacement_free, free)
DYLD_INTERPOSE(replacement_malloc, malloc)
DYLD_INTERPOSE(replacement_realloc, realloc)
DYLD_INTERPOSE(replacement_calloc, calloc)
DYLD_INTERPOSE(replacement_reallocf, reallocf)
DYLD_INTERPOSE(replacement_valloc, valloc)
DYLD_INTERPOSE(replacement_posix_memalign, posix_memalign)
DYLD_INTERPOSE(replacement_malloc_zone_malloc, malloc_zone_malloc)
DYLD_INTERPOSE(replacement_malloc_zone_calloc, malloc_zone_calloc)
DYLD_INTERPOSE(replacement_malloc_zone_valloc, malloc_zone_valloc)
DYLD_INTERPOSE(replacement_malloc_zone_realloc, malloc_zone_realloc)
DYLD_INTERPOSE(replacement_malloc_zone_memalign, malloc_zone_memalign)
DYLD_INTERPOSE(replacement_malloc_zone_free, malloc_zone_free)
#endif
