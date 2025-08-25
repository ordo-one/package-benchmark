//
//  Basic+SetupTeardown.swift
//
//
//  Created by Joakim Hassila on 2023-04-21.
//

import Benchmark

func sharedSetup() {}

// func sharedSetup() -> [Int] {
//    [1, 2, 3]
// }

func sharedTeardown() {
    //    print("Shared teardown hook")
}

func testSetUpTearDown() {
    //    Benchmark.setup = { print("Global setup hook")}
    //        Benchmark.setup = { 123 }
    //    Benchmark.teardown = { print("Global teardown hook") }

    Benchmark(
        "SetupTeardown",
        configuration: .init(setup: sharedSetup, teardown: sharedTeardown)
    ) { _ in
    } setup: {
        //        print("Local setup hook")
    } teardown: {
        //        print("Local teardown hook")
    }

    Benchmark(
        "SetupTeardown2",
        configuration: .init(setup: sharedSetup, teardown: sharedTeardown)
    ) { _ in
    }

    Benchmark(
        "SetupTeardown3",
        configuration: .init(setup: sharedSetup)
    ) { _ in
        //        let x = benchmark.setupState as! [Int]
        //        print("\(x)")
    } teardown: {
        //        print("Local teardown hook")
    }

    Benchmark(
        "SetupTeardown4",
        configuration: .init(setup: sharedSetup)
    ) { _ in
        //        print("\(benchmark.setupState)")
    } setup: {
        //      return 7
        //        print("Local setup hook")
    }

    Benchmark("SetupTeardown5") { _ in
        //              print("\(benchmark.setupState)")
    }

    Benchmark("SetupTeardown6") { _, _ in
        //        print("\(setupState)")
    } setup: {
        [1, 2, 3]
    }
}
