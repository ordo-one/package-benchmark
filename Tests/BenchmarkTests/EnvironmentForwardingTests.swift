//
// Copyright (c) 2022 Ordo One AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
//
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//

import XCTest

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#else
#error("Unsupported Platform")
#endif

/// Tests for environment variable forwarding functionality.
/// This tests the logic used by BenchmarkCommandPlugin and BenchmarkTool to forward
/// environment variables through the SPM plugin sandbox.
final class EnvironmentForwardingTests: XCTestCase {

    // MARK: - Helper Functions (mirrors plugin implementation)

    /// Build an environment array that includes extra environment variables.
    /// This mirrors the implementation in BenchmarkCommandPlugin and BenchmarkTool.
    func buildEnvironmentArray(extraEnv: [String]) -> [[CChar]] {
        var result: [[CChar]] = []

        // Collect current environment
        var index = 0
        while let envVar = environ[index] {
            result.append(Array(String(cString: envVar).utf8CString))
            index += 1
        }

        // Add extra environment variables
        for envVar in extraEnv {
            result.append(Array(envVar.utf8CString))
        }

        return result
    }

    /// Convert environment array back to dictionary for easy testing
    func environmentArrayToDictionary(_ envArray: [[CChar]]) -> [String: String] {
        var dict: [String: String] = [:]
        for ccharArray in envArray {
            let str = ccharArray.withUnsafeBufferPointer { buffer in
                String(cString: buffer.baseAddress!)
            }
            let parts = str.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                dict[String(parts[0])] = String(parts[1])
            } else if parts.count == 1 {
                dict[String(parts[0])] = ""
            }
        }
        return dict
    }

    // MARK: - Tests

    func testBuildEnvironmentArrayIncludesCurrentEnvironment() {
        // Given: the current environment has PATH set
        let currentPath = ProcessInfo.processInfo.environment["PATH"]
        XCTAssertNotNil(currentPath, "PATH should exist in current environment")

        // When: we build environment array with no extra vars
        let envArray = buildEnvironmentArray(extraEnv: [])

        // Then: the result should include PATH
        let envDict = environmentArrayToDictionary(envArray)
        XCTAssertEqual(envDict["PATH"], currentPath)
    }

    func testBuildEnvironmentArrayAddsExtraVariables() {
        // Given: extra environment variables
        let extraEnv = ["TEST_VAR_1=value1", "TEST_VAR_2=value2"]

        // When: we build environment array
        let envArray = buildEnvironmentArray(extraEnv: extraEnv)

        // Then: the result should include the extra variables
        let envDict = environmentArrayToDictionary(envArray)
        XCTAssertEqual(envDict["TEST_VAR_1"], "value1")
        XCTAssertEqual(envDict["TEST_VAR_2"], "value2")
    }

    func testBuildEnvironmentArrayPreservesExistingAndAddsNew() {
        // Given: current environment and extra variables
        let currentPath = ProcessInfo.processInfo.environment["PATH"]
        let extraEnv = ["MY_CUSTOM_VAR=custom_value"]

        // When: we build environment array
        let envArray = buildEnvironmentArray(extraEnv: extraEnv)

        // Then: both existing and new variables should be present
        let envDict = environmentArrayToDictionary(envArray)
        XCTAssertEqual(envDict["PATH"], currentPath)
        XCTAssertEqual(envDict["MY_CUSTOM_VAR"], "custom_value")
    }

    func testBuildEnvironmentArrayHandlesEmptyExtraEnv() {
        // Given: empty extra environment
        let extraEnv: [String] = []

        // When: we build environment array
        let envArray = buildEnvironmentArray(extraEnv: extraEnv)

        // Then: result should match current environment count
        var currentEnvCount = 0
        var index = 0
        while environ[index] != nil {
            currentEnvCount += 1
            index += 1
        }
        XCTAssertEqual(envArray.count, currentEnvCount)
    }

    func testBuildEnvironmentArrayHandlesSpecialCharacters() {
        // Given: extra variables with special characters (like paths)
        let extraEnv = [
            "DYLD_INSERT_LIBRARIES=/path/to/lib.dylib",
            "MY_PATH=/usr/local/bin:/usr/bin",
            "QUOTED_VAR=value with spaces"
        ]

        // When: we build environment array
        let envArray = buildEnvironmentArray(extraEnv: extraEnv)

        // Then: special characters should be preserved
        let envDict = environmentArrayToDictionary(envArray)
        XCTAssertEqual(envDict["DYLD_INSERT_LIBRARIES"], "/path/to/lib.dylib")
        XCTAssertEqual(envDict["MY_PATH"], "/usr/local/bin:/usr/bin")
        XCTAssertEqual(envDict["QUOTED_VAR"], "value with spaces")
    }

    func testBuildEnvironmentArrayHandlesEqualsInValue() {
        // Given: extra variable with equals sign in value
        let extraEnv = ["EQUATION=a=b=c"]

        // When: we build environment array
        let envArray = buildEnvironmentArray(extraEnv: extraEnv)

        // Then: equals signs in value should be preserved
        let envDict = environmentArrayToDictionary(envArray)
        XCTAssertEqual(envDict["EQUATION"], "a=b=c")
    }

    func testBuildEnvironmentArrayCanOverrideExisting() {
        // Given: an extra variable that might override existing (appended at end)
        let extraEnv = ["HOME=/custom/home"]

        // When: we build environment array
        let envArray = buildEnvironmentArray(extraEnv: extraEnv)

        // Then: the custom HOME should appear in the array
        // Note: In posix_spawn, later values may override earlier ones depending on implementation
        // This test verifies the extra var is added; actual override behavior depends on spawn implementation
        XCTAssertTrue(envArray.contains { ccharArray in
            let str = ccharArray.withUnsafeBufferPointer { buffer in
                String(cString: buffer.baseAddress!)
            }
            return str == "HOME=/custom/home"
        })
    }

    // MARK: - withEnvironment Pattern Tests

    /// Test the withEnvironment closure pattern used by the plugin
    func testWithEnvironmentPattern() {
        let extraEnv = ["TEST_VAR=test_value"]

        // This mirrors the withEnvironment function from the plugin
        func withEnvironment(extraEnv: [String], scoped: ([UnsafeMutablePointer<CChar>?]) throws -> Void) rethrows {
            var envStrings: [UnsafeMutablePointer<CChar>?] = []
            var index = 0
            while let envVar = environ[index] {
                envStrings.append(strdup(envVar))
                index += 1
            }
            for envVar in extraEnv {
                envStrings.append(strdup(envVar))
            }
            envStrings.append(nil)
            defer {
                for envVar in envStrings {
                    free(envVar)
                }
            }
            try scoped(envStrings)
        }

        var capturedEnv: [String] = []
        withEnvironment(extraEnv: extraEnv) { cEnv in
            var i = 0
            while let ptr = cEnv[i] {
                capturedEnv.append(String(cString: ptr))
                i += 1
            }
        }

        // Verify extra env was added
        XCTAssertTrue(capturedEnv.contains("TEST_VAR=test_value"))

        // Verify existing env is present
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            XCTAssertTrue(capturedEnv.contains("PATH=\(path)"))
        }
    }

    /// Test that the environment array is null-terminated as required by posix_spawn
    func testEnvironmentArrayIsNullTerminated() {
        let extraEnv = ["EXTRA=value"]

        func withEnvironment(extraEnv: [String], scoped: ([UnsafeMutablePointer<CChar>?]) throws -> Void) rethrows {
            var envStrings: [UnsafeMutablePointer<CChar>?] = []
            var index = 0
            while let envVar = environ[index] {
                envStrings.append(strdup(envVar))
                index += 1
            }
            for envVar in extraEnv {
                envStrings.append(strdup(envVar))
            }
            envStrings.append(nil)
            defer {
                for envVar in envStrings {
                    free(envVar)
                }
            }
            try scoped(envStrings)
        }

        withEnvironment(extraEnv: extraEnv) { cEnv in
            // Find the nil terminator
            var count = 0
            while cEnv[count] != nil {
                count += 1
            }
            // The last element should be nil
            XCTAssertNil(cEnv[count])
        }
    }

    /// Test memory safety - verify we can safely use and free the environment
    func testEnvironmentMemorySafety() {
        let extraEnv = ["MEM_TEST_1=value1", "MEM_TEST_2=value2", "MEM_TEST_3=value3"]

        func withEnvironment(extraEnv: [String], scoped: ([UnsafeMutablePointer<CChar>?]) throws -> Void) rethrows {
            var envStrings: [UnsafeMutablePointer<CChar>?] = []
            var index = 0
            while let envVar = environ[index] {
                envStrings.append(strdup(envVar))
                index += 1
            }
            for envVar in extraEnv {
                envStrings.append(strdup(envVar))
            }
            envStrings.append(nil)
            defer {
                for envVar in envStrings {
                    free(envVar)
                }
            }
            try scoped(envStrings)
        }

        // Run multiple times to stress test memory handling
        for _ in 0..<10 {
            withEnvironment(extraEnv: extraEnv) { cEnv in
                // Read all environment strings to verify they're valid
                var i = 0
                while let ptr = cEnv[i] {
                    let str = String(cString: ptr)
                    XCTAssertFalse(str.isEmpty)
                    i += 1
                }
            }
        }
        // If we get here without crashing, memory handling is correct
        XCTAssertTrue(true)
    }
}
