#include <stdlib.h>
#include <stdio.h>

#include "SwiftRuntimeHooks.h"

typedef struct HeapObject_s HeapObject;

extern HeapObject * (*_swift_retain)(HeapObject*);
extern HeapObject * (*_swift_release)(HeapObject*);

// unclear if the following two needs hooking and they don't seem to be called on Apple Silicon
extern HeapObject * (*_swift_retain_n)(HeapObject *object, uint32_t n);
extern HeapObject * (*_swift_release_n)(HeapObject *object, uint32_t n);

struct hook_data_s {
    HeapObject * (*orig)(HeapObject*);
    HeapObject * (*orig_n)(HeapObject*, uint32_t);
    swift_runtime_hook_t hook;
    void * context;
};

/*===========================================================================*/

static struct hook_data_s _swift_retain_hook_data = {NULL, NULL, NULL, NULL};

static HeapObject * _swift_retain_hook(HeapObject * heapObject) {
    HeapObject * ret = (*_swift_retain_hook_data.orig)(heapObject);
    (*_swift_retain_hook_data.hook)(heapObject, _swift_retain_hook_data.context);
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
        _swift_retain_n = _swift_retain_hook_data.orig_n;
        struct hook_data_s hook_data = {NULL, NULL, NULL, NULL};
        _swift_retain_hook_data = hook_data;
    } else {
        struct hook_data_s hook_data = {_swift_retain, _swift_retain_n, hook, context};
        _swift_retain_hook_data = hook_data;
        _swift_retain = _swift_retain_hook;
        _swift_retain_n = _swift_retain_n_hook;
    }
}

/*===========================================================================*/

static struct hook_data_s _swift_release_hook_data = {NULL, NULL, NULL, NULL};

static HeapObject * _swift_release_hook(HeapObject * heapObject) {
    HeapObject * ret = (*_swift_release_hook_data.orig)(heapObject);
    (*_swift_release_hook_data.hook)(heapObject, _swift_release_hook_data.context);
    return ret;
}

// This doesn't seem to be called for Apple Silicon at least, but keeping it here
static HeapObject * _swift_release_n_hook(HeapObject * heapObject, uint32_t n) {
    int i;
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
        struct hook_data_s hook_data = {NULL, NULL, NULL, NULL};
        _swift_release_hook_data = hook_data;
    } else {
        struct hook_data_s hook_data = {_swift_release, _swift_release_n, hook, context};
        _swift_release_hook_data = hook_data;
        _swift_release = _swift_release_hook;
        _swift_release_n = _swift_release_n_hook;
    }
}
