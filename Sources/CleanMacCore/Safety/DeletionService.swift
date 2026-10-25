import Foundation

/// Moves an item to the Trash. Abstracted so tests never touch the real Trash.
public protocol Trasher: Sendable {
    func trashItem(at url: URL) throws
}

public struct FileManagerTrasher: Trasher {
    public init() {}

    public func trashItem(at url: URL) throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }
}

/// The only place in the app that removes files. Every item is checked against the
/// `ProtectionPolicy` and moved to the Trash; nothing is ever deleted permanently.
public struct DeletionService: Sendable {
    public let policy: ProtectionPolicy
    private let trasher: Trasher

    public init(policy: ProtectionPolicy, trasher: Trasher = FileManagerTrasher()) {
        self.policy = policy
        self.trasher = trasher
    }

    public func trash(_ urls: [URL]) async -> DeletionResult {
        var result = DeletionResult()
        var allowed: [URL] = []
        for url in urls {
            if let reason = policy.protectionReason(for: url) {
                result.failures.append(DeletionFailure(url: url, reason: reason))
            } else {
                allowed.append(url)
            }
        }
        for url in Self.removingNested(allowed) {
            if Task.isCancelled { break }
            guard (try? url.checkResourceIsReachable()) == true || Self.isSymlink(url) else {
                result.failures.append(DeletionFailure(url: url, reason: "Ya no existe"))
                continue
            }
            let size = SizeCalculator.allocatedSize(of: url).size
            do {
                try trasher.trashItem(at: url)
                result.trashed.append(url)
                result.bytesFreed += size
            } catch {
                result.failures.append(DeletionFailure(url: url, reason: error.localizedDescription))
            }
        }
        return result
    }

    /// Drops duplicates and items whose ancestor is also in the list, keeping the input order.
    static func removingNested(_ urls: [URL]) -> [URL] {
        let paths = urls.map { ProtectionPolicy.normalize($0) }
        var seen = Set<String>()
        var kept: [URL] = []
        for (url, path) in zip(urls, paths) {
            let hasAncestor = paths.contains { ProtectionPolicy.isDescendant(path, of: $0) }
            if hasAncestor || !seen.insert(path).inserted { continue }
            kept.append(url)
        }
        return kept
    }

    private static func isSymlink(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
    }
}
