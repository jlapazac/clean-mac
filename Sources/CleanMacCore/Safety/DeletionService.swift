import Foundation

/// Moves an item to the Trash. Abstracted so tests never touch the real Trash.
public protocol Trasher: Sendable {
    func trashItem(at url: URL) async throws
}

public struct FileManagerTrasher: Trasher {
    public init() {}

    public func trashItem(at url: URL) async throws {
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
                try await trasher.trashItem(at: url)
                result.trashed.append(url)
                result.bytesFreed += size
            } catch {
                result.failures.append(DeletionFailure(url: url, reason: Self.describe(error)))
            }
        }
        return result
    }

    /// User-facing reason for a failed move, with a hint when macOS denied permission.
    static func describe(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain && nsError.code == CocoaError.userCancelled.rawValue {
            return "Cancelaste la autorización"
        }
        let posix = (nsError.userInfo[NSUnderlyingErrorKey] as? NSError)
            .flatMap { $0.domain == NSPOSIXErrorDomain ? Int32($0.code) : nil }
        let denied = [CocoaError.fileWriteNoPermission.rawValue, CocoaError.fileReadNoPermission.rawValue]
            .contains(nsError.code) || posix == EPERM || posix == EACCES
        if denied {
            return "macOS no lo permitió. Si es una app, activa «Gestión de apps» para CleanMac en "
                + "Ajustes del Sistema → Privacidad y seguridad, o autoriza con tu contraseña."
        }
        return nsError.localizedDescription
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
