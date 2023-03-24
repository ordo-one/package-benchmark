#ifndef SwiftRuntimeHooks_hpp
#define SwiftRuntimeHooks_hpp

#include <stdio.h>

typedef void (*swift_runtime_hook_t)(const void *, void *);

void swift_runtime_set_retain_hook(swift_runtime_hook_t hook, void * context);
void swift_runtime_set_release_hook(swift_runtime_hook_t hook, void * context);

#endif
