import Foundation

public enum CleanupRisk: Sendable, Equatable {
    /// Regenerable data; safe to remove.
    case low
    /// Shown for information only; the app never deletes it.
    case informational

    public var title: String {
        switch self {
        case .low: "Riesgo bajo"
        case .informational: "Solo informativo"
        }
    }
}

/// A predefined group of regenerable data the user can clean.
public struct CleanupCategory: Sendable, Identifiable, Hashable {
    public let id: String
    public let title: String
    public let detail: String
    public let paths: [URL]
    public let risk: CleanupRisk
    public var size: Int64
    public var exists: Bool
    public let instructions: String?

    public var isCleanable: Bool { risk != .informational && exists && size > 0 }

    public init(
        id: String,
        title: String,
        detail: String,
        paths: [URL],
        risk: CleanupRisk,
        size: Int64 = 0,
        exists: Bool = false,
        instructions: String? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.paths = paths
        self.risk = risk
        self.size = size
        self.exists = exists
        self.instructions = instructions
    }
}
