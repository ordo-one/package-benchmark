//import Testing
//@testable import MallocInterposer
//import Darwin
//
//final class Foo {
//    var bar: Int = 0
//
//    init() {}
//}
//
//@Test func example() async throws {
//    var hookCalled = false
//    var allocSize = 0
//
//    MallocHooks.setMallocHook { size, originalResult in
//        hookCalled = true
//        allocSize = size
//        return originalResult
//    }
//
//    let foo = Foo()
//    print(foo.bar)
//
//    #expect(hookCalled == true)
//    #expect(allocSize == 1024)
//
//    let stats = MallocInterposer.shared.getStatistics()
//    #expect(stats.mallocCount == 1)
//}
