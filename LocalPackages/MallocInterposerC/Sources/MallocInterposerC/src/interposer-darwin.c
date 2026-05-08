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

// Inline counting helpers ---------------------------------------------------

static __attribute__((always_inline)) void count_malloc(size_t size) {
    atomic_fetch_add_explicit(&g_malloc_count, 1, memory_order_relaxed);
    atomic_fetch_add_explicit(&g_malloc_bytes, (int64_t)size, memory_order_relaxed);
    if (size > (size_t)get_page_size()) {
        atomic_fetch_add_explicit(&g_malloc_large, 1, memory_order_relaxed);
    } else {
        atomic_fetch_add_explicit(&g_malloc_small, 1, memory_order_relaxed);
    }
}

static __attribute__((always_inline)) void count_free(size_t size) {
    atomic_fetch_add_explicit(&g_free_count, 1, memory_order_relaxed);
    atomic_fetch_add_explicit(&g_free_bytes, (int64_t)size, memory_order_relaxed);
}

// Header-write helpers ------------------------------------------------------

static __attribute__((always_inline)) void *write_header(void *raw, size_t size) {
    malloc_header_t *hdr = (malloc_header_t *)raw;
    hdr->requested_size = size;
    hdr->reserved = 0;
    hdr->magic = MALLOC_INTERPOSER_MAGIC;
    return malloc_interposer_user_for(raw);
}

// Replacement functions -----------------------------------------------------
//
// On Darwin, calls from inside this dylib resolve directly to libsystem
// (DYLD_INTERPOSE only rewrites calls in OTHER images), so plain `malloc`,
// `free` etc. below are libsystem's, not recursive into ourselves.

void *replacement_malloc(size_t size) {
    void *raw = malloc(size + sizeof(malloc_header_t));
    if (!raw) return NULL;
    if (atomic_load_explicit(&g_counting_enabled, memory_order_relaxed)) {
        count_malloc(size);
    }
    return write_header(raw, size);
}

void replacement_free(void *user_ptr) {
    if (!user_ptr) return;
    if (malloc_interposer_is_ours(user_ptr)) {
        malloc_header_t *hdr = malloc_interposer_header_for(user_ptr);
        if (atomic_load_explicit(&g_counting_enabled, memory_order_relaxed)) {
            count_free(hdr->requested_size);
        }
        free(hdr);
    } else {
        // External pointer (rare on Darwin once DYLD_INTERPOSE is active).
        // Fall back to libc bookkeeping for byte accounting.
        if (atomic_load_explicit(&g_counting_enabled, memory_order_relaxed)) {
            count_free(malloc_size(user_ptr));
        }
        free(user_ptr);
    }
}

void *replacement_calloc(size_t count, size_t size) {
    size_t total;
    if (__builtin_mul_overflow(count, size, &total)) {
        // Let libc surface the overflow exactly as the user would expect.
        return calloc(count, size);
    }
    // libc calloc zeros the entire allocation including where the header
    // sits; we then overwrite those 16 bytes. Slightly redundant but simple.
    void *raw = calloc(1, total + sizeof(malloc_header_t));
    if (!raw) return NULL;
    if (atomic_load_explicit(&g_counting_enabled, memory_order_relaxed)) {
        count_malloc(total);
    }
    return write_header(raw, total);
}

void *replacement_realloc(void *user_ptr, size_t new_size) {
    if (!user_ptr) return replacement_malloc(new_size);
    if (new_size == 0) {
        replacement_free(user_ptr);
        return NULL;
    }

    bool counting = atomic_load_explicit(&g_counting_enabled, memory_order_relaxed);

    if (malloc_interposer_is_ours(user_ptr)) {
        malloc_header_t *old_hdr = malloc_interposer_header_for(user_ptr);
        size_t old_size = old_hdr->requested_size;

        void *new_raw = realloc(old_hdr, new_size + sizeof(malloc_header_t));
        if (!new_raw) return NULL;

        if (counting) {
            count_free(old_size);
            count_malloc(new_size);
        }
        // realloc may have moved memory; rewrite the header unconditionally.
        return write_header(new_raw, new_size);
    }

    // External pointer; use libc bookkeeping.
    size_t old_size = malloc_size(user_ptr);
    void *new_ptr = realloc(user_ptr, new_size);
    if (!new_ptr) return NULL;
    if (counting) {
        count_free(old_size);
        count_malloc(malloc_size(new_ptr));
    }
    return new_ptr;
}

void *replacement_reallocf(void *user_ptr, size_t new_size) {
    void *new_ptr = replacement_realloc(user_ptr, new_size);
    // reallocf semantics: if reallocation fails, free the original pointer.
    // replacement_realloc handles size==0 (frees) and ptr==NULL (no original)
    // itself, so only free on the actual-failure case.
    if (!new_ptr && user_ptr && new_size != 0) {
        replacement_free(user_ptr);
    }
    return new_ptr;
}

// ---- Aligned/legacy paths: alignment requirements rule out the header ----
// We let libc place a properly-aligned chunk and use malloc_size on free
// (paid by the rare allocations that use these). Magic check on free will
// fail, falling through to the external path that reads malloc_size.

void *replacement_valloc(size_t size) {
    void *ptr = valloc(size);
    if (ptr && atomic_load_explicit(&g_counting_enabled, memory_order_relaxed)) {
        count_malloc(malloc_size(ptr));
    }
    return ptr;
}

int replacement_posix_memalign(void **memptr, size_t alignment, size_t size) {
    int result = posix_memalign(memptr, alignment, size);
    if (result == 0
        && memptr
        && atomic_load_explicit(&g_counting_enabled, memory_order_relaxed)) {
        count_malloc(malloc_size(*memptr));
    }
    return result;
}

// ---- Zone-level wrappers (rarely hit by user code) ------------------------

void *replacement_malloc_zone_malloc(malloc_zone_t *zone, size_t size) {
    void *raw = malloc_zone_malloc(zone, size + sizeof(malloc_header_t));
    if (!raw) return NULL;
    if (atomic_load_explicit(&g_counting_enabled, memory_order_relaxed)) {
        count_malloc(size);
    }
    return write_header(raw, size);
}

void *replacement_malloc_zone_calloc(malloc_zone_t *zone, size_t num_items, size_t size) {
    size_t total;
    if (__builtin_mul_overflow(num_items, size, &total)) {
        return malloc_zone_calloc(zone, num_items, size);
    }
    void *raw = malloc_zone_calloc(zone, 1, total + sizeof(malloc_header_t));
    if (!raw) return NULL;
    if (atomic_load_explicit(&g_counting_enabled, memory_order_relaxed)) {
        count_malloc(total);
    }
    return write_header(raw, total);
}

void *replacement_malloc_zone_valloc(malloc_zone_t *zone, size_t size) {
    void *ptr = malloc_zone_valloc(zone, size);
    if (ptr && atomic_load_explicit(&g_counting_enabled, memory_order_relaxed)) {
        count_malloc(malloc_size(ptr));
    }
    return ptr;
}

void *replacement_malloc_zone_realloc(malloc_zone_t *zone, void *user_ptr, size_t new_size) {
    if (!user_ptr) return replacement_malloc_zone_malloc(zone, new_size);
    if (new_size == 0) {
        replacement_malloc_zone_free(zone, user_ptr);
        return NULL;
    }

    bool counting = atomic_load_explicit(&g_counting_enabled, memory_order_relaxed);

    if (malloc_interposer_is_ours(user_ptr)) {
        malloc_header_t *old_hdr = malloc_interposer_header_for(user_ptr);
        size_t old_size = old_hdr->requested_size;
        void *new_raw = malloc_zone_realloc(zone, old_hdr, new_size + sizeof(malloc_header_t));
        if (!new_raw) return NULL;
        if (counting) {
            count_free(old_size);
            count_malloc(new_size);
        }
        return write_header(new_raw, new_size);
    }

    size_t old_size = malloc_size(user_ptr);
    void *new_ptr = malloc_zone_realloc(zone, user_ptr, new_size);
    if (!new_ptr) return NULL;
    if (counting) {
        count_free(old_size);
        count_malloc(malloc_size(new_ptr));
    }
    return new_ptr;
}

void *replacement_malloc_zone_memalign(malloc_zone_t *zone, size_t alignment, size_t size) {
    void *ptr = malloc_zone_memalign(zone, alignment, size);
    if (ptr && atomic_load_explicit(&g_counting_enabled, memory_order_relaxed)) {
        count_malloc(malloc_size(ptr));
    }
    return ptr;
}

void replacement_malloc_zone_free(malloc_zone_t *zone, void *user_ptr) {
    if (!user_ptr) return;
    if (malloc_interposer_is_ours(user_ptr)) {
        malloc_header_t *hdr = malloc_interposer_header_for(user_ptr);
        if (atomic_load_explicit(&g_counting_enabled, memory_order_relaxed)) {
            count_free(hdr->requested_size);
        }
        malloc_zone_free(zone, hdr);
    } else {
        if (atomic_load_explicit(&g_counting_enabled, memory_order_relaxed)) {
            count_free(malloc_size(user_ptr));
        }
        malloc_zone_free(zone, user_ptr);
    }
}

// ---- Size queries ---------------------------------------------------------
// External code that calls malloc_size on one of our pointers would see the
// offset address (not the libc chunk start), so libsystem can't find it in
// any zone. Interpose to return the requested size from the header.

size_t replacement_malloc_size(const void *user_ptr) {
    if (!user_ptr) return 0;
    if (malloc_interposer_is_ours(user_ptr)) {
        return malloc_interposer_header_for((void *)user_ptr)->requested_size;
    }
    return malloc_size(user_ptr);
}

DYLD_INTERPOSE(replacement_free, free)
DYLD_INTERPOSE(replacement_malloc, malloc)
DYLD_INTERPOSE(replacement_realloc, realloc)
DYLD_INTERPOSE(replacement_calloc, calloc)
DYLD_INTERPOSE(replacement_reallocf, reallocf)
DYLD_INTERPOSE(replacement_valloc, valloc)
DYLD_INTERPOSE(replacement_posix_memalign, posix_memalign)
DYLD_INTERPOSE(replacement_malloc_size, malloc_size)
DYLD_INTERPOSE(replacement_malloc_zone_malloc, malloc_zone_malloc)
DYLD_INTERPOSE(replacement_malloc_zone_calloc, malloc_zone_calloc)
DYLD_INTERPOSE(replacement_malloc_zone_valloc, malloc_zone_valloc)
DYLD_INTERPOSE(replacement_malloc_zone_realloc, malloc_zone_realloc)
DYLD_INTERPOSE(replacement_malloc_zone_memalign, malloc_zone_memalign)
DYLD_INTERPOSE(replacement_malloc_zone_free, malloc_zone_free)
#endif
