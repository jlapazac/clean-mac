import Foundation

public enum SizeCalculator {
    static let fileKeys: [URLResourceKey] = [
        .isDirectoryKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
    ]

    /// Total space allocated on disk for `url` and everything below it. Symbolic links are not
    /// followed. Unreadable folders are skipped and counted in `unreadable`.
    public static func allocatedSize(of url: URL) -> (size: Int64, unreadable: Int) {
        var unreadable = 0
        let size = POSIXDirectory.totalSize(of: url.standardizedFileURL.path, unreadable: &unreadable)
        return (size, unreadable)
    }

    static func allocatedSize(_ values: URLResourceValues) -> Int64 {
        Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
    }
}
