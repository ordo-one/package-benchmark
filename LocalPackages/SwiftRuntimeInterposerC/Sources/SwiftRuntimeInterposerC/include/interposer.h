//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef SWIFT_RUNTIME_INTERPOSER_H
#define SWIFT_RUNTIME_INTERPOSER_H

#include <stdint.h>
#include <stdlib.h>

void swift_runtime_interposer_enable(void);
void swift_runtime_interposer_disable(void);
void swift_runtime_interposer_reset(void);
void swift_runtime_interposer_get_stats(
    int64_t *alloc_count,
    int64_t *retain_count,
    int64_t *release_count
);

#if __APPLE__
extern void *swift_allocObject(const void *metadata, size_t requiredSize, size_t requiredAlignmentMask)
    __attribute__((weak_import));
extern void *swift_retain(void *object) __attribute__((weak_import));
extern void swift_release(void *object) __attribute__((weak_import));
#else
void *swift_allocObject(const void *metadata, size_t requiredSize, size_t requiredAlignmentMask);
void *swift_retain(void *object);
void swift_release(void *object);
#endif

#endif
