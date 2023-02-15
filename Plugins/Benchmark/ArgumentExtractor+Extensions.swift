//
// Copyright (c) 2023 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

import PackagePlugin

@available(macOS 13.0, *)
extension ArgumentExtractor {
    mutating func extractSpecifiedTargets(in package: Package,
                                          withOption option: String) throws -> [SwiftSourceModuleTarget] {
        let specifiedTargets = extractOption(named: option)
        var targets: [SwiftSourceModuleTarget] = []

        try package.targets.forEach { target in
            for specifiedTarget in specifiedTargets {
                let regex = try Regex(specifiedTarget)

                if target.name.contains(regex) {
                    if let swiftSourceModuleTarget = target as? SwiftSourceModuleTarget {
                        if swiftSourceModuleTarget.kind != .test {
                            targets.append(swiftSourceModuleTarget)
                            break
                        }
                    }
                }
            }
        }
        return targets
    }
}
