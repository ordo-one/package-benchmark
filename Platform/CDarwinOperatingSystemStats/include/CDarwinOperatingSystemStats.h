//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

// We need this to get at the libproc header

#ifndef CDarwinOperatingSystemStats_h
#define CDarwinOperatingSystemStats_h

#if defined(__APPLE__)
#include "TargetConditionals.h"
#if !TARGET_OS_IPHONE
#include <libproc.h>
#endif
#else
#include <libproc.h>
#endif

#endif /* CDarwinOperatingSystemStats_h */
