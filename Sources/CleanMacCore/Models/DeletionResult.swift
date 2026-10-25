import Foundation

public struct DeletionFailure: Sendable, Equatable {
    public let url: URL
    public let reason: String

    public init(url: URL, reason: String) {
        self.url = url
        self.reason = reason
    }
}

/// Outcome of moving items to the Trash.
public struct DeletionResult: Sendable, Equatable {
    public var trashed: [URL]
    public var failures: [DeletionFailure]
    public var bytesFreed: Int64

    public init(trashed: [URL] = [], failures: [DeletionFailure] = [], bytesFreed: Int64 = 0) {
        self.trashed = trashed
        self.failures = failures
        self.bytesFreed = bytesFreed
    }
}
