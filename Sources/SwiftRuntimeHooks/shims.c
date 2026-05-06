#include <stdint.h>
#include <stddef.h>
#if defined(__linux__)
#include <stdatomic.h>
#include <stdbool.h>
#endif

#include "SwiftRuntimeHooks.h"

typedef struct HeapObject_s HeapObject;
typedef struct HeapMetadata_s HeapMetadata;

extern HeapObject * (*_swift_allocObject)(HeapMetadata const *metadata,
                                          size_t requiredSize,
                                          size_t requiredAlignmentMask);

extern HeapObject * (*_swift_retain)(HeapObject*);
extern void (*_swift_release)(HeapObject*);

extern HeapObject * (*_swift_tryRetain)(HeapObject*);

// unclear if the following two needs hooking and they don't seem to be called on Apple Silicon
extern HeapObject * (*_swift_retain_n)(HeapObject *object, uint32_t n);
extern void (*_swift_release_n)(HeapObject *object, uint32_t n);

#if defined(__linux__)
extern _Atomic bool _swift_enableSwizzlingOfAllocationAndRefCountingFunctions_forInstrumentsOnly;
#endif

struct hook_data_s {
    HeapObject * (*orig)(HeapObject*);
    HeapObject * (*origTry)(HeapObject*);
    HeapObject * (*orig_n)(HeapObject*, uint32_t);
    swift_runtime_hook_t hook;
    void * context;
};

struct hook_data_release_s {
    void (*orig)(HeapObject*);
    void (*orig_n)(HeapObject*, uint32_t);
    swift_runtime_hook_t hook;
    void * context;
};

struct hook_data_alloc_s {
    HeapObject * (*orig)(HeapMetadata const *, size_t, size_t);
    swift_runtime_hook_t hook;
    void * context;
};

#if defined(__linux__)
static _Atomic long long _swift_alloc_count = 0;
static _Atomic long long _swift_retain_count = 0;
static _Atomic long long _swift_release_count = 0;

static void _swift_count_alloc_hook(const void *object, void *context) {
    (void)object;
    (void)context;
    atomic_fetch_add_explicit(&_swift_alloc_count, 1, memory_order_relaxed);
}

static void _swift_count_retain_hook(const void *object, void *context) {
    (void)object;
    (void)context;
    atomic_fetch_add_explicit(&_swift_retain_count, 1, memory_order_relaxed);
}

static void _swift_count_release_hook(const void *object, void *context) {
    (void)object;
    (void)context;
    atomic_fetch_add_explicit(&_swift_release_count, 1, memory_order_relaxed);
}
#endif

/*===========================================================================*/

static struct hook_data_alloc_s _swift_alloc_object_hook_data = {NULL, NULL, NULL};

void swift_runtime_set_swizzling_enabled(int enabled) {
#if defined(__linux__)
    atomic_store_explicit(
        &_swift_enableSwizzlingOfAllocationAndRefCountingFunctions_forInstrumentsOnly,
        enabled != 0,
        memory_order_relaxed
    );
#else
    (void)enabled;
#endif
}

static HeapObject * _swift_alloc_object_hook(HeapMetadata const *metadata,
                                             size_t requiredSize,
                                             size_t requiredAlignmentMask) {
    HeapObject * ret = (*_swift_alloc_object_hook_data.orig)(metadata, requiredSize, requiredAlignmentMask);
    (*_swift_alloc_object_hook_data.hook)(ret, _swift_alloc_object_hook_data.context);
    return ret;
}

void swift_runtime_set_alloc_object_hook(swift_runtime_hook_t hook, void * context) {
    if (hook == NULL) {
        _swift_allocObject = _swift_alloc_object_hook_data.orig;
        struct hook_data_alloc_s hook_data = {NULL, NULL, NULL};
        _swift_alloc_object_hook_data = hook_data;
    } else {
        struct hook_data_alloc_s hook_data = {_swift_allocObject, hook, context};
        _swift_alloc_object_hook_data = hook_data;
        _swift_allocObject = _swift_alloc_object_hook;
    }
}
/*===========================================================================*/

static struct hook_data_s _swift_retain_hook_data = {NULL, NULL, NULL, NULL, NULL};

static HeapObject * _swift_retain_hook(HeapObject * heapObject) {
    HeapObject * ret = (*_swift_retain_hook_data.orig)(heapObject);
    (*_swift_retain_hook_data.hook)(heapObject, _swift_retain_hook_data.context);
    return ret;
}

// This doesn't seem to be called for Apple Silicon at least, but keeping it here
static HeapObject * _swift_tryRetain_hook(HeapObject * heapObject) {
    HeapObject * ret = (*_swift_retain_hook_data.origTry)(heapObject);
    if (ret != NULL) {
        (*_swift_retain_hook_data.hook)(heapObject, _swift_retain_hook_data.context);
    }
    return ret;
}

// This doesn't seem to be called for Apple Silicon at least, but keeping it here
static HeapObject * _swift_retain_n_hook(HeapObject * heapObject, uint32_t n) {
    int i;
    HeapObject * ret = (*_swift_retain_hook_data.orig_n)(heapObject, n);
    for (i = 0; i < n; i++) {
        (*_swift_retain_hook_data.hook)(heapObject, _swift_retain_hook_data.context);
    }
    return ret;
}

void swift_runtime_set_retain_hook(swift_runtime_hook_t hook, void * context) {
    if (hook == NULL) {
        _swift_retain = _swift_retain_hook_data.orig;
        _swift_tryRetain = _swift_retain_hook_data.origTry;
        _swift_retain_n = _swift_retain_hook_data.orig_n;
        struct hook_data_s hook_data = {NULL, NULL, NULL, NULL, NULL};
        _swift_retain_hook_data = hook_data;
    } else {
        struct hook_data_s hook_data = {_swift_retain, _swift_tryRetain, _swift_retain_n, hook, context};
        _swift_retain_hook_data = hook_data;
        _swift_retain = _swift_retain_hook;
        _swift_tryRetain = _swift_tryRetain_hook;
        _swift_retain_n = _swift_retain_n_hook;
    }
}

/*===========================================================================*/

static struct hook_data_release_s _swift_release_hook_data = {NULL, NULL, NULL, NULL};

static void _swift_release_hook(HeapObject * heapObject) {
    (*_swift_release_hook_data.orig)(heapObject);
    (*_swift_release_hook_data.hook)(heapObject, _swift_release_hook_data.context);
}

// This doesn't seem to be called for Apple Silicon at least, but keeping it here
static void _swift_release_n_hook(HeapObject * heapObject, uint32_t n) {
    int i;
    (*_swift_release_hook_data.orig_n)(heapObject, n);
    for (i = 0; i < n; i++) {
        (*_swift_release_hook_data.hook)(heapObject, _swift_release_hook_data.context);
    }
}

void swift_runtime_set_release_hook(swift_runtime_hook_t hook, void * context) {
    if (hook == NULL) {
        _swift_release = _swift_release_hook_data.orig;
        _swift_release_n = _swift_release_hook_data.orig_n;
        struct hook_data_release_s hook_data = {NULL, NULL, NULL, NULL};
        _swift_release_hook_data = hook_data;
    } else {
        struct hook_data_release_s hook_data = {_swift_release, _swift_release_n, hook, context};
        _swift_release_hook_data = hook_data;
        _swift_release = _swift_release_hook;
        _swift_release_n = _swift_release_n_hook;
    }
}

void swift_runtime_install_counting_hooks(void) {
#if defined(__linux__)
    swift_runtime_set_alloc_object_hook(_swift_count_alloc_hook, NULL);
    swift_runtime_set_retain_hook(_swift_count_retain_hook, NULL);
    swift_runtime_set_release_hook(_swift_count_release_hook, NULL);
#endif
}

void swift_runtime_remove_counting_hooks(void) {
#if defined(__linux__)
    swift_runtime_set_alloc_object_hook(NULL, NULL);
    swift_runtime_set_retain_hook(NULL, NULL);
    swift_runtime_set_release_hook(NULL, NULL);
#endif
}

void swift_runtime_reset_counts(void) {
#if defined(__linux__)
    atomic_store_explicit(&_swift_alloc_count, 0, memory_order_relaxed);
    atomic_store_explicit(&_swift_retain_count, 0, memory_order_relaxed);
    atomic_store_explicit(&_swift_release_count, 0, memory_order_relaxed);
#endif
}

long long swift_runtime_get_alloc_count(void) {
#if defined(__linux__)
    return atomic_load_explicit(&_swift_alloc_count, memory_order_relaxed);
#else
    return 0;
#endif
}

long long swift_runtime_get_retain_count(void) {
#if defined(__linux__)
    return atomic_load_explicit(&_swift_retain_count, memory_order_relaxed);
#else
    return 0;
#endif
}

long long swift_runtime_get_release_count(void) {
#if defined(__linux__)
    return atomic_load_explicit(&_swift_release_count, memory_order_relaxed);
#else
    return 0;
#endif
}
