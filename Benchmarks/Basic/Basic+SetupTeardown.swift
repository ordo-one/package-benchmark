//
//  File.swift
//
//
//  Created by Joakim Hassila on 2023-04-21.
//

import Benchmark

func sharedSetup() {
//    print("Shared setup hook")
}

func sharedTeardown() {
//    print("Shared teardown hook")
}

func testSetUpTearDown() {
//    Benchmark.setup = { print("Global setup hook") }
//    Benchmark.teardown = { print("Global teardown hook") }

    Benchmark("SetupTeardown",
              configuration: .init(setup: sharedSetup, teardown: sharedTeardown)) { _ in
    } setup: {
//        print("Local setup hook")
    } teardown: {
//        print("Local teardown hook")
    }

    Benchmark("SetupTeardown2",
              configuration: .init(setup: sharedSetup, teardown: sharedTeardown)) { _ in
    }

    Benchmark("SetupTeardown3",
              configuration: .init(setup: sharedSetup)) { _ in
    } teardown: {
//        print("Local teardown hook")
    }

    Benchmark("SetupTeardown4",
              configuration: .init(setup: sharedSetup)) { _ in
    } setup: {
//        print("Local setup hook")
    }
}
