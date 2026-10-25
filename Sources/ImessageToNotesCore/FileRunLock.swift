import Foundation

/// A run lock on a lock file, with `flock`. The lock belongs to the open file, so macOS releases it
/// when the run exits, also after a crash. A stale lock file never blocks a later run.
public final class FileRunLock: RunLock {
    private let path: String
    private var descriptor: Int32 = -1

    public init(path: String) {
        self.path = path
    }

    deinit {
        unlock()
    }

    public func tryLock() throws -> Bool {
        let directory = URL(filePath: path).deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let descriptor = open(path, O_RDWR | O_CREAT | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else {
            throw RunLockError(description: "Cannot open the lock file at \(path): \(String(cString: strerror(errno)))")
        }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            let error = errno
            close(descriptor)
            if error == EWOULDBLOCK {
                return false
            }
            throw RunLockError(description: "Cannot lock the lock file at \(path): \(String(cString: strerror(error)))")
        }
        self.descriptor = descriptor
        return true
    }

    public func unlock() {
        guard descriptor >= 0 else { return }
        close(descriptor)
        descriptor = -1
    }
}

/// A failure to open or lock the lock file. Another run that holds the lock is not a failure.
public struct RunLockError: Error, CustomStringConvertible {
    public var description: String
}
