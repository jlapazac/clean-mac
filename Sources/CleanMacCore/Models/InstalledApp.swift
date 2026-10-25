import Foundation

/// An application bundle found on disk.
public struct InstalledApp: Sendable, Identifiable, Hashable {
    public let id: URL
    public let name: String
    public let bundleIdentifier: String?
    public let executableName: String?
    public let version: String?
    public let bundleSize: Int64
    public let isAppleApp: Bool
    public var isRunning: Bool
    public var isSelf: Bool
    public var leftovers: [Leftover]

    public var url: URL { id }
    /// Only high-confidence leftovers count towards the app's size; ambiguous matches may
    /// belong to another app (e.g. two apps from the same vendor).
    public var leftoversSize: Int64 {
        leftovers.filter { $0.confidence == .high }.reduce(0) { $0 + $1.size }
    }
    public var possibleLeftoversSize: Int64 {
        leftovers.filter { $0.confidence == .ambiguous }.reduce(0) { $0 + $1.size }
    }
    public var totalSize: Int64 { bundleSize + leftoversSize }
    public var canUninstall: Bool { !isAppleApp && !isRunning && !isSelf }

    public init(
        url: URL,
        name: String,
        bundleIdentifier: String?,
        executableName: String? = nil,
        version: String?,
        bundleSize: Int64,
        isAppleApp: Bool,
        isRunning: Bool = false,
        isSelf: Bool = false,
        leftovers: [Leftover] = []
    ) {
        self.id = url
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.executableName = executableName
        self.version = version
        self.bundleSize = bundleSize
        self.isAppleApp = isAppleApp
        self.isRunning = isRunning
        self.isSelf = isSelf
        self.leftovers = leftovers
    }
}
