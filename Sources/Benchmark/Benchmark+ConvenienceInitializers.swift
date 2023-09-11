extension Benchmark {
    /// Definition of a Benchmark
    /// - Parameters:
    ///   - name: The name used for display purposes of the benchmark (also used for
    ///   matching when comparing to baselines)
    ///   - configuration: Defines the settings that should be used for this benchmark
    ///   - closure: The actual benchmark closure that will be measured, this one takes one additional parameter
    ///   apart from the benchmark instance, which is the generic SetupResult type returned from the setup
    @discardableResult
    convenience public init?<SetupResult>(_ name: String,
                                          configuration: Benchmark.Configuration = Benchmark.defaultConfiguration,
                                          closure: @escaping (_ benchmark: Benchmark, SetupResult) -> Void,
                                          setup: @escaping (() async throws -> SetupResult),
                                          teardown: BenchmarkTeardownHook? = nil) {
        self.init(name, configuration: configuration) { benchmark in
            var setupResult = benchmark.setupState! as! SetupResult
            closure(benchmark, setupResult)
        } setup: {
            try await setup()
        } teardown: {
            try await teardown?()
        }
    }

    /// Definition of a Benchmark
    /// - Parameters:
    ///   - name: The name used for display purposes of the benchmark (also used for
    ///   matching when comparing to baselines)
    ///   - configuration: Defines the settings that should be used for this benchmark
    ///   - closure: The actual `async` benchmark closure that will be measured, this one takes one additional parameter
    ///   apart from the benchmark instance, which is the generic SetupResult type returned from the setup
    @discardableResult
    convenience public init?<SetupResult>(_ name: String,
                 configuration: Benchmark.Configuration = Benchmark.defaultConfiguration,
                 closure: @escaping (_ benchmark: Benchmark, SetupResult) async -> Void,
                 setup: @escaping (() async throws -> SetupResult),
                 teardown: BenchmarkTeardownHook? = nil) {
        self.init(name, configuration: configuration) { benchmark in
            var setupResult = benchmark.setupState! as! SetupResult
            await closure(benchmark, setupResult)
        } setup: {
            try await setup()
        } teardown: {
            try await teardown?()
        }
    }

    /// Definition of a throwing Benchmark
    /// - Parameters:
    ///   - name: The name used for display purposes of the benchmark (also used for
    ///   matching when comparing to baselines)
    ///   - configuration: Defines the settings that should be used for this benchmark
    ///   - closure: The actual throwing benchmark closure that will be measured, this one takes one additional parameter
    ///   apart from the benchmark instance, which is the generic SetupResult type returned from the setup
    @discardableResult
    convenience public init?<SetupResult>(_ name: String,
                                          configuration: Benchmark.Configuration = Benchmark.defaultConfiguration,
                                          closure: @escaping (_ benchmark: Benchmark, SetupResult) throws -> Void,
                                          setup: (() async throws -> SetupResult)? = nil,
                                          teardown: BenchmarkTeardownHook? = nil) {
        self.init(name, configuration: configuration, closure: { benchmark in
            do {
                var setupResult = benchmark.setupState! as! SetupResult
                try closure(benchmark, setupResult)
            } catch {
                benchmark.error("Benchmark \(name) failed with \(error)")
            }
        }, setup: setup, teardown: teardown)
    }

    /// Definition of an async throwing Benchmark
    /// - Parameters:
    ///   - name: The name used for display purposes of the benchmark (also used for
    ///   matching when comparing to baselines)
    ///   - configuration: Defines the settings that should be used for this benchmark
    ///   - closure: The actual async throwing benchmark closure that will be measured, this one takes one additional parameter
    ///   apart from the benchmark instance, which is the generic SetupResult type returned from the setup
    @discardableResult
    public convenience init?<SetupResult>(_ name: String,
                             configuration: Benchmark.Configuration = Benchmark.defaultConfiguration,
                             closure: @escaping (_ benchmark: Benchmark, SetupResult) async throws -> Void,
                             setup: (() async throws -> SetupResult)? = nil,
                             teardown: BenchmarkTeardownHook? = nil) {
        self.init(name, configuration: configuration, closure: { benchmark in
            do {
                var setupResult = benchmark.setupState! as! SetupResult
                try await closure(benchmark, setupResult)
            } catch {
                benchmark.error("Benchmark \(name) failed with \(error)")
            }
        }, setup: setup, teardown: teardown)
    }
}
