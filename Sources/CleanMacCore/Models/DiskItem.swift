import Foundation

/// A node of the space-analysis tree. Only children at or above the scanner's
/// minimum size are kept; smaller ones are folded into `smallItemsSize`.
public struct DiskItem: Sendable, Identifiable, Hashable {
    public let id: URL
    public let name: String
    public var size: Int64
    public let isDirectory: Bool
    public var children: [DiskItem]
    public var smallItemsSize: Int64
    public var smallItemsCount: Int
    /// True when the folder was excluded (cloud storage) or could not be read.
    public var isSkipped: Bool
    /// True when `size` was measured afterwards with administrator rights (read-only); the
    /// folder's contents are still not browsable.
    public var isPrivilegedMeasurement: Bool = false

    public var url: URL { id }

    public init(
        url: URL,
        name: String? = nil,
        size: Int64,
        isDirectory: Bool,
        children: [DiskItem] = [],
        smallItemsSize: Int64 = 0,
        smallItemsCount: Int = 0,
        isSkipped: Bool = false
    ) {
        self.id = url
        self.name = name ?? FileManager.default.displayName(atPath: url.path)
        self.size = size
        self.isDirectory = isDirectory
        self.children = children
        self.smallItemsSize = smallItemsSize
        self.smallItemsCount = smallItemsCount
        self.isSkipped = isSkipped
    }
}

/// Live progress reported while scanning.
public struct ScanProgress: Sendable, Equatable {
    public var filesScanned: Int
    public var bytesScanned: Int64
    public var currentPath: String

    public init(filesScanned: Int = 0, bytesScanned: Int64 = 0, currentPath: String = "") {
        self.filesScanned = filesScanned
        self.bytesScanned = bytesScanned
        self.currentPath = currentPath
    }
}

/// Result of a full scan.
public struct ScanSummary: Sendable {
    public var roots: [DiskItem]
    public var unreadableCount: Int
    /// Folders that could not be read (no permission), so they can be measured later.
    public var unreadablePaths: [String]
    public var fileCount: Int
    public var duration: Duration

    public init(roots: [DiskItem], unreadableCount: Int, unreadablePaths: [String] = [],
                fileCount: Int, duration: Duration) {
        self.roots = roots
        self.unreadableCount = unreadableCount
        self.unreadablePaths = unreadablePaths
        self.fileCount = fileCount
        self.duration = duration
    }
}
