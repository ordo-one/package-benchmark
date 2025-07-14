import Foundation

final class OutputSuppressor {
    private var originalStdout: Int32?
    private var originalStderr: Int32?
    private var nullFile: Int32?

    func suppressOutput() throws {
        // Save original file descriptors
        originalStdout = dup(FileHandle.standardOutput.fileDescriptor)
        originalStderr = dup(FileHandle.standardError.fileDescriptor)

        // Open /dev/null
        nullFile = open("/dev/null", O_WRONLY)
        guard nullFile != -1 else {
            throw NSError(
                domain: "OutputSuppressor",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to open /dev/null"]
            )
        }

        // Redirect stdout and stderr to /dev/null
        guard dup2(nullFile!, FileHandle.standardOutput.fileDescriptor) != -1,
            dup2(nullFile!, FileHandle.standardError.fileDescriptor) != -1
        else {
            throw NSError(
                domain: "OutputSuppressor",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to redirect output"]
            )
        }
    }

    func restoreOutput() throws {
        // Restore original stdout and stderr
        guard let stdout = originalStdout,
            let stderr = originalStderr
        else {
            throw NSError(
                domain: "OutputSuppressor",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Original file descriptors not found"]
            )
        }

        guard dup2(stdout, FileHandle.standardOutput.fileDescriptor) != -1,
            dup2(stderr, FileHandle.standardError.fileDescriptor) != -1
        else {
            throw NSError(
                domain: "OutputSuppressor",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Failed to restore output"]
            )
        }

        // Close file descriptors
        close(stdout)
        close(stderr)
        if let null = nullFile {
            close(null)
        }

        // Reset stored descriptors
        originalStdout = nil
        originalStderr = nil
        nullFile = nil
    }
}
