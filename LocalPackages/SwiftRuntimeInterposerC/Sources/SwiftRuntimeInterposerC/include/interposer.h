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

void *swift_allocObject(const void *metadata, size_t requiredSize, size_t requiredAlignmentMask);
void *swift_retain(void *object);
void *swift_nonatomic_retain(void *object);
void *swift_bridgeObjectRetain(void *object);
void *swift_retain_n(void *object, uint32_t n);
void *swift_nonatomic_retain_n(void *object, uint32_t n);
void *swift_bridgeObjectRetain_n(void *object, uint32_t n);
void swift_release(void *object);
void swift_nonatomic_release(void *object);
void swift_release_n(void *object, uint32_t n);
void swift_nonatomic_release_n(void *object, uint32_t n);
void swift_bridgeObjectRelease(void *object);
void swift_bridgeObjectRelease_n(void *object, uint32_t n);

#endif
