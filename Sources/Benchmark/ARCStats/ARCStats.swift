//
// Copyright (c) 2023 Ordo One AB
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

/// The ARC stats the ARCStatsProducer can provide
#if swift(>=5.8)
    @_documentation(visibility: internal)
#endif

struct ARCStats {
    var objectAllocCount: Int = 0 /// total number allocations, implicit retain
    var retainCount: Int = 0 /// total number retains
    var releaseCount: Int = 0 /// total number of releases
}
