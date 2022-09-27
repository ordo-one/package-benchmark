//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

/// The memory allocation stats the the MallocStatsProducer can provide
public struct MallocStats {
    var mallocCountTotal: Int = 0 /// total number of mallocs done
    var mallocCountSmall: Int = 0 /// number of small mallocs (as defined by jemalloc)
    var mallocCountLarge: Int = 0 /// number of large mallocs (as defined by jemalloc)

    /// Maximum number of bytes in physically resident data pages mapped by the allocator,
    /// comprising all pages dedicated to allocator metadata, pages backing active allocations
    /// , and unused dirty pages. This is a maximum rather than precise because pages may
    /// not actually be physically resident if they correspond to demand-zeroed virtual memory
    /// that has not yet been touched. This is a multiple of the page size.
    var allocatedResidentMemory: Int = 0 // in bytes
}
