import Foundation
import MallocInterposerSwift
import MallocInterposerC

@main
enum TestClient {
    @_optimize(none)
    static func main() {
        print("=== MallocInterposerSwift Test ===" )
        // Reset statistics to start clean
        MallocInterposerSwift.hook()

        let ptr = malloc(1000)
        let ptr2 = malloc(500)

        free(ptr)
        free(ptr2)

        MallocInterposerSwift.unhook()

        // Print final statistics
        let stats = MallocInterposerSwift.getStatistics()

        print("Total malloc count: \(stats.mallocCount)")
        print("Total allocated memory: \(stats.mallocBytesCount) bytes")
        print("Total free count: \(stats.freeCount)")

        print("\n--- Test complete ---")
    }
}
