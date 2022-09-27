// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for Swift project authors

// Extracted and adopted/modified from Swift-DocC, thank you!
import PackagePlugin

enum ArgumentParsingError: Error, CustomStringConvertible {
    case unknownTarget(_ targetName: String)
    case productDoesNotContainSwiftSourceModuleTargets(String)
    case packageDoesNotContainSwiftSourceModuleTargets
    case targetIsNotSwiftSourceModule(String)
    case testTarget(String)

    var description: String {
        switch self {
        case let .unknownTarget(targetName):
            return """
            no target named '\(targetName)'

            """
        case let .productDoesNotContainSwiftSourceModuleTargets(string):
            return "product '\(string)' does not contain any Swift source modules"
        case let .targetIsNotSwiftSourceModule(string):
            return "target '\(string)' is not a Swift source module"
        case let .testTarget(string):
            return "target '\(string)' is a test target; only library and executable targets are supported by Swift-DocC"
        case .packageDoesNotContainSwiftSourceModuleTargets:
            return "the current package does not contain any compatible Swift source modules"
        }
    }

    var errorDescription: String? {
        description
    }
}

extension ArgumentExtractor {
    mutating func extractSpecifiedTargets(in package: Package, withOption option: String) throws -> [SwiftSourceModuleTarget] {
        let specifiedTargets = extractOption(named: option)

        let targets = try specifiedTargets.map { specifiedTarget -> SwiftSourceModuleTarget in
            let target = package.targets.first { target in
                target.name == specifiedTarget
            }

            guard let target = target else {
                throw ArgumentParsingError.unknownTarget(specifiedTarget)
            }

            guard let swiftSourceModuleTarget = target as? SwiftSourceModuleTarget else {
                throw ArgumentParsingError.targetIsNotSwiftSourceModule(specifiedTarget)
            }

            guard swiftSourceModuleTarget.kind != .test else {
                throw ArgumentParsingError.testTarget(specifiedTarget)
            }

            return swiftSourceModuleTarget
        }

        return targets
    }
}
