// ===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Collections open source project
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
// ===----------------------------------------------------------------------===//

// Borrowed from Swift Collections Benchmark, thanks!

/// Do nothing and immediately return.
///
/// Some compiler optimizations can eliminate operations whose results don't
/// get used, and this could potentially interfere with the accuracy of a
/// benchmark. To defeat these optimizations, pass such unused results to
/// this function so that the compiler considers them used.
@inline(never)
public func blackHole<T>(_: T) {}
