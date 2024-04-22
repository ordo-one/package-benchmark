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

struct performanceCounters {
    unsigned long long instructions;
} performanceCounters;

int CLinuxPerformanceCountersInit(); // returns the perf events fd that must be passed to the reset of the functions
void CLinuxPerformanceCountersDeinit(int fd); // stop monitoring and close the fd
void CLinuxPerformanceCountersCurrent(int fd, struct performanceCounters *performanceCounters); // return current counters

#endif /* CLinuxOperatingSystemStats_h */
