#include <stdint.h>
#include <stddef.h>
#if defined(__linux__)
#include <stdatomic.h>
#include <stdbool.h>
#include <sys/mman.h>
#include <unistd.h>
#endif

#include "SwiftRuntimeHooks.h"

typedef struct HeapObject_s HeapObject;
typedef struct HeapMetadata_s HeapMetadata;

extern HeapObject * (*_swift_allocObject)(HeapMetadata const *metadata,
                                          size_t requiredSize,
                                          size_t requiredAlignmentMask);

extern HeapObject * (*_swift_retain)(HeapObject*);
extern HeapObject * (*_swift_release)(HeapObject*);

extern HeapObject * (*_swift_tryRetain)(HeapObject*);

// unclear if the following two needs hooking and they don't seem to be called on Apple Silicon
extern HeapObject * (*_swift_retain_n)(HeapObject *object, uint32_t n);
extern HeapObject * (*_swift_release_n)(HeapObject *object, uint32_t n);

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

struct hook_data_alloc_s {
    HeapObject * (*orig)(HeapMetadata const *, size_t, size_t);
    swift_runtime_hook_t hook;
    void * context;
};

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

#if defined(__linux__) && defined(__x86_64__)
static bool _swift_pointer_looks_mapped(const void *ptr) {
    if (ptr == NULL) {
        return false;
    }

    long pageSize = sysconf(_SC_PAGESIZE);
    if (pageSize <= 0) {
        return true;
    }

    uintptr_t raw = (uintptr_t)ptr;
    uintptr_t pageBase = raw & ~((uintptr_t)pageSize - 1);
    unsigned char vec = 0;
    return mincore((void *)pageBase, (size_t)pageSize, &vec) == 0;
}
#endif

static HeapObject * _swift_retain_hook(HeapObject * heapObject) {
#if defined(__linux__) && defined(__x86_64__)
    // Swift 6.3 Linux can route some non-native values through the native
    // swizzled retain path. Avoid forwarding obviously unmapped addresses into
    // __swift_retain_ while we diagnose the runtime behavior.
    if (!_swift_pointer_looks_mapped(heapObject)) {
        return heapObject;
    }
#endif

    HeapObject * ret = (*_swift_retain_hook_data.orig)(heapObject);
    (*_swift_retain_hook_data.hook)(heapObject, _swift_retain_hook_data.context);
    return ret;
}

// This doesn't seem to be called for Apple Silicon at least, but keeping it here
static HeapObject * _swift_tryRetain_hook(HeapObject * heapObject) {
#if defined(__linux__) && defined(__x86_64__)
    if (!_swift_pointer_looks_mapped(heapObject)) {
        return NULL;
    }
#endif

    HeapObject * ret = (*_swift_retain_hook_data.origTry)(heapObject);
    if (ret != NULL) {
        (*_swift_retain_hook_data.hook)(heapObject, _swift_retain_hook_data.context);
    }
    return ret;
}

// This doesn't seem to be called for Apple Silicon at least, but keeping it here
static HeapObject * _swift_retain_n_hook(HeapObject * heapObject, uint32_t n) {
    int i;
#if defined(__linux__) && defined(__x86_64__)
    if (!_swift_pointer_looks_mapped(heapObject)) {
        return heapObject;
    }
#endif

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

static struct hook_data_s _swift_release_hook_data = {NULL, NULL, NULL, NULL, NULL};

static HeapObject * _swift_release_hook(HeapObject * heapObject) {
#if defined(__linux__) && defined(__x86_64__)
    if (!_swift_pointer_looks_mapped(heapObject)) {
        return heapObject;
    }
#endif

    HeapObject * ret = (*_swift_release_hook_data.orig)(heapObject);
    (*_swift_release_hook_data.hook)(heapObject, _swift_release_hook_data.context);
    return ret;
}

// This doesn't seem to be called for Apple Silicon at least, but keeping it here
static HeapObject * _swift_release_n_hook(HeapObject * heapObject, uint32_t n) {
    int i;
#if defined(__linux__) && defined(__x86_64__)
    if (!_swift_pointer_looks_mapped(heapObject)) {
        return heapObject;
    }
#endif

    HeapObject * ret = (*_swift_release_hook_data.orig_n)(heapObject, n);
    for (i = 0; i < n; i++) {
        (*_swift_release_hook_data.hook)(heapObject, _swift_release_hook_data.context);
    }
    return ret;
}

void swift_runtime_set_release_hook(swift_runtime_hook_t hook, void * context) {
    if (hook == NULL) {
        _swift_release = _swift_release_hook_data.orig;
        _swift_release_n = _swift_release_hook_data.orig_n;
        struct hook_data_s hook_data = {NULL, NULL, NULL, NULL, NULL};
        _swift_release_hook_data = hook_data;
    } else {
        struct hook_data_s hook_data = {_swift_release, NULL, _swift_release_n, hook, context};
        _swift_release_hook_data = hook_data;
        _swift_release = _swift_release_hook;
        _swift_release_n = _swift_release_n_hook;
    }
}
