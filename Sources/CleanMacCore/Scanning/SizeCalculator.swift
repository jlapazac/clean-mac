import Foundation

public enum SizeCalculator {
    static let fileKeys: [URLResourceKey] = [
        .isDirectoryKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
    ]

    /// Total space allocated on disk for `url` and everything below it. Symbolic links are not
    /// followed. Unreadable folders are skipped and counted in `unreadable`.
    public static func allocatedSize(of url: URL) -> (size: Int64, unreadable: Int) {
        guard let values = try? url.resourceValues(forKeys: Set(fileKeys)) else {
            return (0, 0)
        }
        if values.isSymbolicLink == true || values.isDirectory != true {
            return (allocatedSize(values), 0)
        }

        var unreadable = 0
        var total: Int64 = 0
        let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: fileKeys, options: [],
            errorHandler: { _, _ in
                unreadable += 1
                return true
            })
        while let child = enumerator?.nextObject() as? URL {
            guard let childValues = try? child.resourceValues(forKeys: Set(fileKeys)) else { continue }
            if childValues.isDirectory != true || childValues.isSymbolicLink == true {
                total += allocatedSize(childValues)
            }
        }
        return (total, unreadable)
    }

    static func allocatedSize(_ values: URLResourceValues) -> Int64 {
        Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
    }
}
