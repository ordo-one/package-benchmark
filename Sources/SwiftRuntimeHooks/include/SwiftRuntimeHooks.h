#ifndef PACKAGE_BENCHMARK_SWIFT_RUNTIME_HOOKS_H
#define PACKAGE_BENCHMARK_SWIFT_RUNTIME_HOOKS_H

typedef void (*swift_runtime_hook_t)(const void *, void *);

void swift_runtime_set_retain_hook(swift_runtime_hook_t hook, void * context);
void swift_runtime_set_release_hook(swift_runtime_hook_t hook, void * context);

#endif
