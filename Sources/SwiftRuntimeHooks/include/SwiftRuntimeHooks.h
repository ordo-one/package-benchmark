#ifndef PACKAGE_BENCHMARK_SWIFT_RUNTIME_HOOKS_H
#define PACKAGE_BENCHMARK_SWIFT_RUNTIME_HOOKS_H

typedef void (*swift_runtime_hook_t)(const void *, void *);

void swift_runtime_set_swizzling_enabled(int enabled);
void swift_runtime_set_alloc_object_hook(swift_runtime_hook_t hook, void * context);
void swift_runtime_set_retain_hook(swift_runtime_hook_t hook, void * context);
void swift_runtime_set_release_hook(swift_runtime_hook_t hook, void * context);
void swift_runtime_install_counting_hooks(void);
void swift_runtime_remove_counting_hooks(void);
void swift_runtime_reset_counts(void);
long long swift_runtime_get_alloc_count(void);
long long swift_runtime_get_retain_count(void);
long long swift_runtime_get_release_count(void);

#endif
