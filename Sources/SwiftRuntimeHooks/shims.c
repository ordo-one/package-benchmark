#include <stdlib.h>
#include <stdio.h>

#include "SwiftRuntimeHooks.h"

typedef struct HeapObject_s HeapObject;

extern HeapObject * (*_swift_retain)(HeapObject*);
extern HeapObject * (*_swift_release)(HeapObject*);

struct hook_data_s {
    HeapObject * (*orig)(HeapObject*);
    swift_runtime_hook_t hook;
    void * context;
};

/*===========================================================================*/

static struct hook_data_s _swift_retain_hook_data = {NULL, NULL, NULL};

static HeapObject * _swift_retain_hook(HeapObject * heapObject) {
    HeapObject * ret = (*_swift_retain_hook_data.orig)(heapObject);
    (*_swift_retain_hook_data.hook)(heapObject, _swift_retain_hook_data.context);
    return ret;
}

void swift_runtime_set_retain_hook(swift_runtime_hook_t hook, void * context) {
    if (hook == NULL) {
        _swift_retain = _swift_retain_hook_data.orig;
        struct hook_data_s hook_data = {NULL, NULL, NULL};
        _swift_retain_hook_data = hook_data;
    } else {
        struct hook_data_s hook_data = {_swift_retain, hook, context};
        _swift_retain_hook_data = hook_data;
        _swift_retain = _swift_retain_hook;
    }
}

/*===========================================================================*/

static struct hook_data_s _swift_release_hook_data = {NULL, NULL, NULL};

static HeapObject * _swift_release_hook(HeapObject * heapObject) {
    HeapObject * ret = (*_swift_release_hook_data.orig)(heapObject);
    (*_swift_release_hook_data.hook)(heapObject, _swift_release_hook_data.context);
    return ret;
}

void swift_runtime_set_release_hook(swift_runtime_hook_t hook, void * context) {
    if (hook == NULL) {
        _swift_release = _swift_release_hook_data.orig;
        struct hook_data_s hook_data = {NULL, NULL, NULL};
        _swift_release_hook_data = hook_data;
    } else {
        struct hook_data_s hook_data = {_swift_release, hook, context};
        _swift_release_hook_data = hook_data;
        _swift_release = _swift_release_hook;
    }
}
