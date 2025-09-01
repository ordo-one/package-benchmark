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
static __thread bool g_in_socket = false;
static __thread bool g_in_accept = false;
static __thread bool g_in_accept4 = false;
static __thread bool g_in_close = false;

/* The types of the variables holding the libc function pointers. */
typedef void *(*type_libc_malloc)(size_t);
typedef void *(*type_libc_realloc)(void *, size_t);
typedef void  (*type_libc_free)(void *);
typedef int   (*type_libc_socket)(int, int, int);
typedef int   (*type_libc_accept)(int, struct sockaddr*, socklen_t *);
typedef int   (*type_libc_accept4)(int, struct sockaddr *, socklen_t *, int);
typedef int   (*type_libc_close)(int);

/* The (atomic) globals holding the pointer to the original libc implementation. */
_Atomic type_libc_malloc g_libc_malloc;
_Atomic type_libc_realloc g_libc_realloc;
_Atomic type_libc_free g_libc_free;
_Atomic type_libc_socket g_libc_socket;
_Atomic type_libc_accept g_libc_accept;
_Atomic type_libc_accept4 g_libc_accept4;
_Atomic type_libc_close g_libc_close;

// Global hooks
static malloc_hook_t g_malloc_hook = NULL;
static free_hook_t g_free_hook = NULL;
static calloc_hook_t g_calloc_hook = NULL;
static realloc_hook_t g_realloc_hook = NULL;
static valloc_hook_t g_valloc_hook = NULL;
static posix_memalign_hook_t g_posix_memalign_hook = NULL;

// Statistics
static pthread_mutex_t hook_mutex = PTHREAD_MUTEX_INITIALIZER;

// Hook management functions
void set_malloc_hook(malloc_hook_t hook) {
    pthread_mutex_lock(&hook_mutex);
    g_malloc_hook = hook;
    pthread_mutex_unlock(&hook_mutex);
}

void set_free_hook(free_hook_t hook) {
    pthread_mutex_lock(&hook_mutex);
    g_free_hook = hook;
    pthread_mutex_unlock(&hook_mutex);
}

void set_calloc_hook(calloc_hook_t hook) {
    pthread_mutex_lock(&hook_mutex);
    g_calloc_hook = hook;
    pthread_mutex_unlock(&hook_mutex);
}

void set_realloc_hook(realloc_hook_t hook) {
    pthread_mutex_lock(&hook_mutex);
    g_realloc_hook = hook;
    pthread_mutex_unlock(&hook_mutex);
}

void set_valloc_hook(valloc_hook_t hook) {
    pthread_mutex_lock(&hook_mutex);
    g_valloc_hook = hook;
    pthread_mutex_unlock(&hook_mutex);
}

void set_posix_memalign_hook(posix_memalign_hook_t hook) {
    pthread_mutex_lock(&hook_mutex);
    g_posix_memalign_hook = hook;
    pthread_mutex_unlock(&hook_mutex);
}

// Clear hooks
void clear_malloc_hook(void) { set_malloc_hook(NULL); }
void clear_free_hook(void) { set_free_hook(NULL); }
void clear_calloc_hook(void) { set_calloc_hook(NULL); }
void clear_realloc_hook(void) { set_realloc_hook(NULL); }
void clear_valloc_hook(void) { set_valloc_hook(NULL); }
void clear_posix_memalign_hook(void) { set_posix_memalign_hook(NULL); }

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
    // not implemented yet...
    abort();
}

// this is called if free is called whilst trying to resolve libc's free.
static void recursive_free(void *ptr) {
    // not implemented yet...
    abort();
}

// this is called if socket is called whilst trying to resolve libc's socket.
static int recursive_socket(int domain, int type, int protocol) {
    // not possible
    abort();
}

// this is called if accept is called whilst trying to resolve libc's accept.
static int recursive_accept(int socket, struct sockaddr *restrict address, socklen_t *restrict address_len) {
    // not possible
    abort();
}

// this is called if accept4 is called whilst trying to resolve libc's accept4.
static int recursive_accept4(int sockfd, struct sockaddr *addr, socklen_t *addrlen, int flags) {
    // not possible
    abort();
}

// this is called if close is called whilst trying to resolve libc's close.
static int recursive_close(int fildes) {
    // not possible
    abort();
}

/* On Apple platforms getting to the original libc function from a hooked
 * function is easy.  On other UNIX systems this is slightly harder because we
 * have to look up the function with the dynamic linker.  Because that isn't
 * super performant we cache the lookup result in an (atomic) global.
 *
 * Calling into the libc function if we have already cached it is easy, we
 * (atomically) load it and call into it.  If have not yet cached it, we need to
 * resolve it which we do by using dlsym and then write it into the (atomic)
 * global.  There's only one slight problem: dlsym might call back into the
 * function we're just trying to resolve (dlsym does call malloc). In that case
 * we need to emulate that function (named recursive_*). But that's all then.
 */
#define JUMP_INTO_LIBC_FUN(_fun, ...) /* \
*/ do { /* \
*/     /* Let's see if somebody else already resolved that function for us */ /* \
*/     type_libc_ ## _fun local_fun = atomic_load(&g_libc_ ## _fun); /* \
*/     if (!local_fun) { /* \
*/         /* No, we're the first ones to use this function. */ /* \
*/         if (!g_in_ ## _fun) { /* \
*/             g_in_ ## _fun = true; /* \
*/             /* If we're here, we're at least not recursively in ourselves. */ /* \
*/             /* That means we can use dlsym to resolve the libc function. */ /* \
*/             type_libc_ ## _fun desired = dlsym(RTLD_NEXT, LIBC_SYMBOL(_fun)); /* \
*/             if (atomic_compare_exchange_strong(&g_libc_ ## _fun, &local_fun, desired)) { /* \
*/                 /* If we're here, we won the race, so let's use our resolved function.  */ /* \
*/                 local_fun = desired; /* \
*/             } else { /* \
*/                 /* Lost the race, let's load the global again */ /* \
*/                 local_fun = atomic_load(&g_libc_ ## _fun); /* \
*/              } /* \
*/         } else { /* \
*/             /* Okay, we can't jump into libc here and need to use our own version. */ /* \
*/             return recursive_ ## _fun (__VA_ARGS__); /* \
*/         } /* \
*/     } /* \
*/     return local_fun(__VA_ARGS__); /* \
*/ } while(0)

void replacement_free(void *ptr) {
    if (ptr) {

        if (g_free_hook) {
            g_free_hook(ptr);
        }

        if (!is_recursive_malloc_block(ptr)) {
            JUMP_INTO_LIBC_FUN(free, ptr);
        }
    }
}

void *replacement_malloc(size_t size) {
    if (g_malloc_hook) {
        g_malloc_hook(size);
    }

    JUMP_INTO_LIBC_FUN(malloc, size);
}

void *replacement_realloc(void *ptr, size_t size) {
    if (0 == size) {
        replacement_free(ptr);
        return NULL;
    }
    if (!ptr) {
        return replacement_malloc(size);
    }

    if (g_realloc_hook) {
        g_realloc_hook(ptr, size);
    }

    JUMP_INTO_LIBC_FUN(realloc, ptr, size);
}

void *replacement_calloc(size_t count, size_t size) {
    void *ptr = replacement_malloc(count * size);
    memset(ptr, 0, count * size);

    if (g_calloc_hook) {
        g_calloc_hook(count, size);
    }

    return ptr;
}

void *replacement_reallocf(void *ptr, size_t size) {
    void *new_ptr = replacement_realloc(ptr, size);
    if (!new_ptr) {
        replacement_free(new_ptr);
    }
    return new_ptr;
}

void *replacement_valloc(size_t size) {
    if (g_valloc_hook) {
        g_valloc_hook(size);
    }
    // not aligning correctly (should be PAGE_SIZE) but good enough
    return replacement_malloc(size);
}

int replacement_posix_memalign(void **memptr, size_t alignment, size_t size) {
    if (g_posix_memalign_hook) {
        g_posix_memalign_hook(memptr, alignment, size);
    }

    // not aligning correctly (should be `alignment`) but good enough
    void *ptr = replacement_malloc(size);
    if (ptr && memptr) {
        *memptr = ptr;
        return 0;
    } else {
        return 1;
    }
}

void free(void *ptr) {
    replacement_free(ptr);
}
void *malloc(size_t size) {
    return replacement_malloc(size);
}
void *calloc(size_t nmemb, size_t size) {
    return replacement_calloc(nmemb, size);
}
void *realloc(void *ptr, size_t size) {
    return replacement_realloc(ptr, size);
}
void *reallocf(void *ptr, size_t size) {
    return replacement_reallocf(ptr, size);
}
void *valloc(size_t size) {
    return replacement_valloc(size);
}
int posix_memalign(void **memptr, size_t alignment, size_t size) {
    return replacement_posix_memalign(memptr, alignment, size);
}
#endif
