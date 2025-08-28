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
#include <pthread.h>
#include <interposer.h>

// Global hooks
static malloc_hook_t g_malloc_hook = NULL;
static free_hook_t g_free_hook = NULL;
static calloc_hook_t g_calloc_hook = NULL;
static realloc_hook_t g_realloc_hook = NULL;
static valloc_hook_t g_valloc_hook = NULL;
static posix_memalign_hook_t g_posix_memalign_hook = NULL;
static malloc_zone_hook_t g_malloc_zone_hook = NULL;
static malloc_zone_realloc_hook_t g_malloc_zone_realloc_hook = NULL;
static malloc_zone_calloc_hook_t g_malloc_zone_calloc_hook = NULL;
static malloc_zone_valloc_hook_t g_malloc_zone_valloc_hook = NULL;
static malloc_zone_memalign_hook_t g_malloc_zone_memalign_hook = NULL;
static malloc_zone_free_hook_t g_malloc_zone_free_hook = NULL;

// Statistics
static pthread_mutex_t hook_mutex = PTHREAD_MUTEX_INITIALIZER;

#define DYLD_INTERPOSE(_replacement,_replacee) \
   __attribute__((used)) static struct { const void *replacement; const void *replacee; } _interpose_##_replacee \
            __attribute__ ((section("__DATA,__interpose"))) = { (const void *)(unsigned long)&_replacement, (const void *)(unsigned long)&_replacee };

/* on Darwin calling the original function is super easy, just call it, done. */
#define JUMP_INTO_LIBC_FUN(_fun, ...) /* \
*/ do { /* \
*/     return _fun(__VA_ARGS__); /* \
*/ } while(0)

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

void set_malloc_zone_hook(malloc_zone_hook_t hook) {
    pthread_mutex_lock(&hook_mutex);
    g_malloc_zone_hook = hook;
    pthread_mutex_unlock(&hook_mutex);
}

void set_malloc_zone_realloc_hook(malloc_zone_realloc_hook_t hook) {
    pthread_mutex_lock(&hook_mutex);
    g_malloc_zone_realloc_hook = hook;
    pthread_mutex_unlock(&hook_mutex);
}

void set_malloc_zone_calloc_hook(malloc_zone_calloc_hook_t hook) {
    pthread_mutex_lock(&hook_mutex);
    g_malloc_zone_calloc_hook = hook;
    pthread_mutex_unlock(&hook_mutex);
}

void set_malloc_zone_valloc_hook(malloc_zone_valloc_hook_t hook) {
    pthread_mutex_lock(&hook_mutex);
    g_malloc_zone_valloc_hook = hook;
    pthread_mutex_unlock(&hook_mutex);
}

void set_malloc_zone_memalign_hook(malloc_zone_memalign_hook_t hook) {
    pthread_mutex_lock(&hook_mutex);
    g_malloc_zone_memalign_hook = hook;
    pthread_mutex_unlock(&hook_mutex);
}

void set_malloc_zone_free_hook(malloc_zone_free_hook_t hook) {
    pthread_mutex_lock(&hook_mutex);
    g_malloc_zone_free_hook = hook;
    pthread_mutex_unlock(&hook_mutex);
}

// Clear hooks
void clear_malloc_hook(void) { set_malloc_hook(NULL); }
void clear_free_hook(void) { set_free_hook(NULL); }
void clear_calloc_hook(void) { set_calloc_hook(NULL); }
void clear_realloc_hook(void) { set_realloc_hook(NULL); }
void clear_valloc_hook(void) { set_valloc_hook(NULL); }
void clear_posix_memalign_hook(void) { set_posix_memalign_hook(NULL); }
void clear_malloc_zone_hook(void) { set_malloc_zone_hook(NULL); }
void clear_malloc_zone_realloc_hook(void) { set_malloc_zone_realloc_hook(NULL); }
void clear_malloc_zone_calloc_hook(void) { set_malloc_zone_calloc_hook(NULL); }
void clear_malloc_zone_valloc_hook(void) { set_malloc_zone_valloc_hook(NULL); }
void clear_malloc_zone_memalign_hook(void) { set_malloc_zone_memalign_hook(NULL); }
void clear_malloc_zone_free_hook(void) { set_malloc_zone_free_hook(NULL); }

// Replacement functions
void replacement_free(void *ptr) {

    // Call hook if set
    if (g_free_hook) {
        g_free_hook(ptr);
    }

    JUMP_INTO_LIBC_FUN(free, ptr);
}

void *replacement_malloc(size_t size) {

    // Call hook if set
    if (g_malloc_hook) {
        g_malloc_hook(size);
    }

   JUMP_INTO_LIBC_FUN(malloc, size);
}

void *replacement_realloc(void *ptr, size_t size) {
    if (g_realloc_hook) {
        g_realloc_hook(ptr, size);
    }

    JUMP_INTO_LIBC_FUN(realloc, ptr, size);
}

void *replacement_calloc(size_t count, size_t size) {
    if (g_calloc_hook) {
        g_calloc_hook(count, size);
    }

    JUMP_INTO_LIBC_FUN(calloc, count, size);
}

void *replacement_malloc_zone_malloc(malloc_zone_t *zone, size_t size) {
    if (g_malloc_zone_hook) {
        g_malloc_zone_hook(zone, size);
    }

    JUMP_INTO_LIBC_FUN(malloc_zone_malloc, zone, size);
}

void *replacement_malloc_zone_calloc(malloc_zone_t *zone, size_t num_items, size_t size) {
    if (g_malloc_zone_calloc_hook) {
        g_malloc_zone_calloc_hook(zone, num_items, size);
    }

    JUMP_INTO_LIBC_FUN(malloc_zone_calloc, zone, num_items, size);
}

void *replacement_malloc_zone_valloc(malloc_zone_t *zone, size_t size) {
    if (g_malloc_zone_valloc_hook) {
        g_malloc_zone_valloc_hook(zone, size);
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

    if (g_malloc_zone_realloc_hook) {
        g_malloc_zone_realloc_hook(zone, ptr, size);
    }

    JUMP_INTO_LIBC_FUN(realloc, ptr, size);
}

void *replacement_malloc_zone_memalign(malloc_zone_t *zone, size_t alignment, size_t size) {
    if (g_malloc_zone_memalign_hook) {
        g_malloc_zone_memalign_hook(zone, alignment, size);
    }

    JUMP_INTO_LIBC_FUN(malloc_zone_memalign, zone, alignment, size);
}

void replacement_malloc_zone_free(malloc_zone_t *zone, void *ptr) {
    if (g_malloc_zone_free_hook) {
        g_malloc_zone_free_hook(zone, ptr);
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
    if (g_valloc_hook) {
        g_valloc_hook(size);
    }

    JUMP_INTO_LIBC_FUN(valloc, size);
}

int replacement_posix_memalign(void **memptr, size_t alignment, size_t size) {
    if (g_posix_memalign_hook) {
        g_posix_memalign_hook(memptr, alignment, size);
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
