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

#include <stdlib.h>
#include <sys/socket.h>
#include <sys/types.h>
#if __APPLE__
#  include <malloc/malloc.h>
#endif

// Hook function types
typedef void (*malloc_hook_t)(size_t size);
typedef void (*free_hook_t)(void* ptr);
typedef void (*calloc_hook_t)(size_t nmemb, size_t size);
typedef void (*realloc_hook_t)(void* ptr, size_t size);
typedef void (*valloc_hook_t)(size_t size);
typedef void (*posix_memalign_hook_t)(void **memptr, size_t alignment, size_t size);

#if __APPLE__
typedef void (*malloc_zone_hook_t)(malloc_zone_t *zone, size_t size);
typedef void (*malloc_zone_calloc_hook_t)(malloc_zone_t *zone, size_t num_items, size_t size);
typedef void (*malloc_zone_realloc_hook_t)(malloc_zone_t *zone, void *ptr, size_t size);
typedef void (*malloc_zone_memalign_hook_t)(malloc_zone_t *zone, size_t alignment, size_t size);
typedef void (*malloc_zone_valloc_hook_t)(malloc_zone_t *zone, size_t size);
typedef void (*malloc_zone_free_hook_t)(malloc_zone_t *zone, void *ptr);
#endif

// Hook management functions
void set_malloc_hook(malloc_hook_t hook);
void set_free_hook(free_hook_t hook);
void set_calloc_hook(calloc_hook_t hook);
void set_realloc_hook(realloc_hook_t hook);

#if __APPLE__
void set_malloc_zone_hook(malloc_zone_hook_t hook);
void set_malloc_zone_calloc_hook(malloc_zone_calloc_hook_t hook);
void set_malloc_zone_realloc_hook(malloc_zone_realloc_hook_t hook);
void set_malloc_zone_memalign_hook(malloc_zone_memalign_hook_t hook);
void set_malloc_zone_valloc_hook(malloc_zone_valloc_hook_t hook);
void set_malloc_zone_free_hook(malloc_zone_free_hook_t hook);
#endif

void clear_malloc_hook(void);
void clear_free_hook(void);
void clear_calloc_hook(void);
void clear_realloc_hook(void);

#if __APPLE__
void clear_malloc_zone_hook(void);
void clear_malloc_zone_calloc_hook(void);
void clear_malloc_zone_realloc_hook(void);
void clear_malloc_zone_memalign_hook(void);
void clear_malloc_zone_valloc_hook(void);
void clear_malloc_zone_free_hook(void);
#endif

// Replacement functions
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
