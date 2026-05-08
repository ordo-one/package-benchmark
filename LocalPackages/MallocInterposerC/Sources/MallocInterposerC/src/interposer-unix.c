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
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <malloc.h>
#include <pthread.h>

#include <interposer.h>

/* a big block of memory that we'll use for recursive mallocs */
static char g_recursive_malloc_mem[10 * 1024 * 1024] = {0};
/* the index of the first free byte */
static _Atomic ptrdiff_t g_recursive_malloc_next_free_ptr = ATOMIC_VAR_INIT(0);

#define LIBC_SYMBOL(_fun) "" # _fun

/* Some thread-local flags we use to check if we're recursively in a hooked function. */
static __thread bool g_in_malloc = false;
static __thread bool g_in_realloc = false;
static __thread bool g_in_free = false;
static __thread bool g_in_malloc_usable_size = false;
static __thread bool g_in_socket = false;
static __thread bool g_in_accept = false;
static __thread bool g_in_accept4 = false;
static __thread bool g_in_close = false;

/* The types of the variables holding the libc function pointers. */
typedef void   *(*type_libc_malloc)(size_t);
typedef void   *(*type_libc_realloc)(void *, size_t);
typedef void    (*type_libc_free)(void *);
typedef size_t  (*type_libc_malloc_usable_size)(void *);
typedef int     (*type_libc_socket)(int, int, int);
typedef int     (*type_libc_accept)(int, struct sockaddr*, socklen_t *);
typedef int     (*type_libc_accept4)(int, struct sockaddr *, socklen_t *, int);
typedef int     (*type_libc_close)(int);

/* The (atomic) globals holding the pointer to the original libc implementation. */
_Atomic type_libc_malloc g_libc_malloc;
_Atomic type_libc_realloc g_libc_realloc;
_Atomic type_libc_free g_libc_free;
_Atomic type_libc_malloc_usable_size g_libc_malloc_usable_size;
_Atomic type_libc_socket g_libc_socket;
_Atomic type_libc_accept g_libc_accept;
_Atomic type_libc_accept4 g_libc_accept4;
_Atomic type_libc_close g_libc_close;

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

// this is called if malloc is called whilst trying to resolve libc's realloc.
// we just vend out pointers to a large block in the BSS (which we never free).
// This block should be large enough because it's only used when malloc is
// called from dlsym which should only happen once per thread.
static void *recursive_malloc(size_t size_in) {
    size_t size = size_in;
    if ((size & 0xf) != 0) {
        // make size 16 byte aligned
        size = (size + 0xf) & (~(size_t)0xf);
    }

    ptrdiff_t next = atomic_fetch_add_explicit(&g_recursive_malloc_next_free_ptr,
                                               size,
                                               memory_order_relaxed);
    if ((size_t)next >= sizeof(g_recursive_malloc_mem)) {
        // we ran out of memory
        return NULL;
    }
    return (void *)((intptr_t)g_recursive_malloc_mem + next);
}

static bool is_recursive_malloc_block(void *ptr) {
    uintptr_t block_begin = (uintptr_t)g_recursive_malloc_mem;
    uintptr_t block_end = block_begin + sizeof(g_recursive_malloc_mem);
    uintptr_t user_ptr = (uintptr_t)ptr;

    return user_ptr >= block_begin && user_ptr < block_end;
}

// this is called if realloc is called whilst trying to resolve libc's realloc.
static void *recursive_realloc(void *ptr, size_t size) {
    (void)ptr; (void)size;
    abort();
}

// this is called if free is called whilst trying to resolve libc's free.
static void recursive_free(void *ptr) {
    (void)ptr;
    abort();
}

// If malloc_usable_size is queried during dlsym handshake, we have nothing
// useful to report — return 0. Reaching here is exceptional.
static size_t recursive_malloc_usable_size(void *ptr) {
    (void)ptr;
    return 0;
}

static int recursive_socket(int domain, int type, int protocol) {
    (void)domain; (void)type; (void)protocol;
    abort();
}
static int recursive_accept(int socket, struct sockaddr *restrict address, socklen_t *restrict address_len) {
    (void)socket; (void)address; (void)address_len;
    abort();
}
static int recursive_accept4(int sockfd, struct sockaddr *addr, socklen_t *addrlen, int flags) {
    (void)sockfd; (void)addr; (void)addrlen; (void)flags;
    abort();
}
static int recursive_close(int fildes) {
    (void)fildes;
    abort();
}

#define JUMP_INTO_LIBC_FUN(_fun, ...) /* \
*/ do { /* \
*/     type_libc_ ## _fun local_fun = atomic_load(&g_libc_ ## _fun); /* \
*/     if (!local_fun) { /* \
*/         if (!g_in_ ## _fun) { /* \
*/             g_in_ ## _fun = true; /* \
*/             type_libc_ ## _fun desired = dlsym(RTLD_NEXT, LIBC_SYMBOL(_fun)); /* \
*/             if (atomic_compare_exchange_strong(&g_libc_ ## _fun, &local_fun, desired)) { /* \
*/                 local_fun = desired; /* \
*/             } else { /* \
*/                 local_fun = atomic_load(&g_libc_ ## _fun); /* \
*/              } /* \
*/         } else { /* \
*/             return recursive_ ## _fun (__VA_ARGS__); /* \
*/         } /* \
*/     } /* \
*/     return local_fun(__VA_ARGS__); /* \
*/ } while(0)

/* Companion to JUMP_INTO_LIBC_FUN that captures the libc result into _outvar
 * instead of returning. Used when we need to inspect the result before
 * returning (e.g. to write the size header). */
#define CALL_LIBC_FUN_CAPTURE(_outvar, _fun, ...) \
    do { \
        type_libc_ ## _fun local_fun = atomic_load(&g_libc_ ## _fun); \
        if (!local_fun) { \
            if (!g_in_ ## _fun) { \
                g_in_ ## _fun = true; \
                type_libc_ ## _fun desired = dlsym(RTLD_NEXT, LIBC_SYMBOL(_fun)); \
                if (atomic_compare_exchange_strong(&g_libc_ ## _fun, &local_fun, desired)) { \
                    local_fun = desired; \
                } else { \
                    local_fun = atomic_load(&g_libc_ ## _fun); \
                } \
            } else { \
                (_outvar) = recursive_ ## _fun (__VA_ARGS__); \
                break; \
            } \
        } \
        (_outvar) = local_fun(__VA_ARGS__); \
    } while (0)

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

// Header-write helper -------------------------------------------------------

static __attribute__((always_inline)) void *write_header(void *raw, size_t size) {
    malloc_header_t *hdr = (malloc_header_t *)raw;
    hdr->requested_size = size;
    hdr->reserved = 0;
    hdr->magic = MALLOC_INTERPOSER_MAGIC;
    return malloc_interposer_user_for(raw);
}

// Replacement functions -----------------------------------------------------

void *replacement_malloc(size_t size) {
    void *raw;
    CALL_LIBC_FUN_CAPTURE(raw, malloc, size + sizeof(malloc_header_t));
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
        // Recursive-malloc blocks live in our static buffer; never call libc free on them.
        if (!is_recursive_malloc_block(hdr)) {
            JUMP_INTO_LIBC_FUN(free, hdr);
        }
        return;
    }
    // Externally-allocated pointer (no header).
    if (is_recursive_malloc_block(user_ptr)) return;
    if (atomic_load_explicit(&g_counting_enabled, memory_order_relaxed)) {
        size_t size;
        CALL_LIBC_FUN_CAPTURE(size, malloc_usable_size, user_ptr);
        count_free(size);
    }
    JUMP_INTO_LIBC_FUN(free, user_ptr);
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

        void *new_raw;
        CALL_LIBC_FUN_CAPTURE(new_raw, realloc, old_hdr, new_size + sizeof(malloc_header_t));
        if (!new_raw) return NULL;

        if (counting) {
            count_free(old_size);
            count_malloc(new_size);
        }
        return write_header(new_raw, new_size);
    }

    // External pointer; use libc bookkeeping. Route every malloc_usable_size
    // call through CALL_LIBC_FUN_CAPTURE so we hit libc, not our override.
    size_t old_size;
    CALL_LIBC_FUN_CAPTURE(old_size, malloc_usable_size, user_ptr);
    void *new_ptr;
    CALL_LIBC_FUN_CAPTURE(new_ptr, realloc, user_ptr, new_size);
    if (!new_ptr) return NULL;
    if (counting) {
        count_free(old_size);
        size_t new_usable;
        CALL_LIBC_FUN_CAPTURE(new_usable, malloc_usable_size, new_ptr);
        count_malloc(new_usable);
    }
    return new_ptr;
}

void *replacement_calloc(size_t count, size_t size) {
    size_t total;
    if (__builtin_mul_overflow(count, size, &total)) {
        errno = ENOMEM;
        return NULL;
    }
    void *user_ptr = replacement_malloc(total);
    if (user_ptr) {
        memset(user_ptr, 0, total);
    }
    return user_ptr;
}

void *replacement_reallocf(void *user_ptr, size_t new_size) {
    void *new_ptr = replacement_realloc(user_ptr, new_size);
    if (!new_ptr && user_ptr && new_size != 0) {
        replacement_free(user_ptr);
    }
    return new_ptr;
}

// Aligned/legacy paths skip the header (alignment requirements rule it out)
// and rely on malloc_usable_size for byte accounting.

void *replacement_valloc(size_t size) {
    // Note: not aligning correctly (should be PAGE_SIZE) but good enough.
    return replacement_malloc(size);
}

int replacement_posix_memalign(void **memptr, size_t alignment, size_t size) {
    (void)alignment;
    // Note: not aligning correctly (should be `alignment`) but good enough.
    void *ptr = replacement_malloc(size);
    if (ptr && memptr) {
        *memptr = ptr;
        return 0;
    }
    return ENOMEM;
}

// Size queries --------------------------------------------------------------
//
// External callers may pass our pointers to malloc_usable_size; libc would
// see an offset address and return garbage from its chunk-header probe.
// Override and route ours through the header. Internal calls go via
// CALL_LIBC_FUN_CAPTURE (dlsym-cached), bypassing our override.

size_t replacement_malloc_usable_size(void *user_ptr) {
    if (!user_ptr) return 0;
    if (malloc_interposer_is_ours(user_ptr)) {
        return malloc_interposer_header_for(user_ptr)->requested_size;
    }
    size_t size;
    CALL_LIBC_FUN_CAPTURE(size, malloc_usable_size, user_ptr);
    return size;
}

// Public symbol overrides ---------------------------------------------------

void free(void *ptr) { replacement_free(ptr); }
void *malloc(size_t size) { return replacement_malloc(size); }
void *calloc(size_t nmemb, size_t size) { return replacement_calloc(nmemb, size); }
void *realloc(void *ptr, size_t size) { return replacement_realloc(ptr, size); }
void *reallocf(void *ptr, size_t size) { return replacement_reallocf(ptr, size); }
void *valloc(size_t size) { return replacement_valloc(size); }
int posix_memalign(void **memptr, size_t alignment, size_t size) {
    return replacement_posix_memalign(memptr, alignment, size);
}
size_t malloc_usable_size(void *ptr) { return replacement_malloc_usable_size(ptr); }

#endif
