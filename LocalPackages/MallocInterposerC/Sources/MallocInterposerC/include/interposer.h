//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef INTERPOSER_H
#define INTERPOSER_H

#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#if __APPLE__
#  include <malloc/malloc.h>
#endif

// ---------------------------------------------------------------------------
// Header-prefix size tracking
//
// Each allocation we hand back to the caller is preceded by a 16-byte header
// that records the requested size and a magic word. On free/realloc we read
// the header instead of calling malloc_size/malloc_usable_size, eliminating
// a libc round-trip per call. Pointers that didn't go through the interposer
// (e.g., aligned-alloc slow path, allocations that pre-date hooking) are
// detected by a failing magic check and fall back to libc bookkeeping.
//
// The header is exactly 16 bytes so user_ptr inherits the 16-byte alignment
// of the underlying libc allocation.
// ---------------------------------------------------------------------------

#define MALLOC_INTERPOSER_MAGIC 0xC0FFEE5AU

typedef struct {
    size_t   requested_size; // offset 0
    uint32_t reserved;       // offset 8
    uint32_t magic;          // offset 12 — last 4 bytes for fast probe via *(user_ptr - 4)
} malloc_header_t;

_Static_assert(sizeof(malloc_header_t) == 16,
               "malloc_header_t must be 16 bytes to preserve 16-byte alignment");

static inline malloc_header_t *malloc_interposer_header_for(void *user_ptr) {
    return (malloc_header_t *)((char *)user_ptr - sizeof(malloc_header_t));
}

static inline void *malloc_interposer_user_for(void *raw) {
    return (char *)raw + sizeof(malloc_header_t);
}

static inline bool malloc_interposer_is_ours(const void *user_ptr) {
    if (!user_ptr) return false;
    // Probe the last 4 bytes of the would-be header. For our pointers this
    // reads our magic; for external pointers it reads into libc chunk
    // metadata (always present and readable for libc-malloc'd pointers).
    uint32_t magic;
    memcpy(&magic, (const char *)user_ptr - sizeof(uint32_t), sizeof(magic));
    return magic == MALLOC_INTERPOSER_MAGIC;
}

// ---------------------------------------------------------------------------

// Enable/disable counting and reset/read stats
void malloc_interposer_enable(void);
void malloc_interposer_disable(void);
void malloc_interposer_reset(void);
void malloc_interposer_get_stats(int64_t *malloc_count, int64_t *malloc_bytes,
                                 int64_t *malloc_small, int64_t *malloc_large,
                                 int64_t *free_count, int64_t *free_bytes);

// Replacement functions (used internally for DYLD_INTERPOSE and Linux overrides)
void *replacement_malloc(size_t size);
void replacement_free(void *ptr);
void *replacement_calloc(size_t nmemb, size_t size);
void *replacement_realloc(void *ptr, size_t size);
void *replacement_reallocf(void *ptr, size_t size);
void *replacement_valloc(size_t size);
int replacement_posix_memalign(void **memptr, size_t alignment, size_t size);
#if __APPLE__
size_t replacement_malloc_size(const void *ptr);
#else
size_t replacement_malloc_usable_size(void *ptr);
#endif

// On Linux we use LD_PRELOAD to interpose the standard malloc functions
// and we have to declare them ourselves
#if !__APPLE__
void free(void *ptr);
void *malloc(size_t size);
void *calloc(size_t nmemb, size_t size);
void *realloc(void *ptr, size_t size);
void *reallocf(void *ptr, size_t size);
void *valloc(size_t size);
int posix_memalign(void **memptr, size_t alignment, size_t size);
size_t malloc_usable_size(void *ptr);
#endif

#if __APPLE__
void *replacement_malloc_zone_malloc(malloc_zone_t *zone, size_t size);
void *replacement_malloc_zone_calloc(malloc_zone_t *zone, size_t num_items, size_t size);
void *replacement_malloc_zone_valloc(malloc_zone_t *zone, size_t size);
void *replacement_malloc_zone_realloc(malloc_zone_t *zone, void *ptr, size_t size);
void *replacement_malloc_zone_memalign(malloc_zone_t *zone, size_t alignment, size_t size);
void replacement_malloc_zone_free(malloc_zone_t *zone, void *ptr);
#endif

#endif
