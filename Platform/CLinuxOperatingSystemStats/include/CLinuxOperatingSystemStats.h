//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef CLinuxOperatingSystemStats_h
#define CLinuxOperatingSystemStats_h

struct ioStats {
    long long readSyscalls;
    long long writeSyscalls;
    long long readBytesLogical;
    long long writeBytesLogical;
    long long readBytesPhysical;
    long long writeBytesPhysical;
} ioStats;

void CLinuxIOStats(const char *s, struct ioStats *ioStats);

struct processStats {
    long cpuUser;
    long cpuSystem;
    long cpuTotal;
    long threads;
    long peakMemoryVirtual;
    long peakMemoryResident;
} processStats;

void CLinuxProcessStats(const char *s, struct processStats *processStats);

#endif /* CLinuxOperatingSystemStats_h */
