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

#include <stdint.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <sys/types.h>
#if __APPLE__
#  include <malloc/malloc.h>
#endif

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
