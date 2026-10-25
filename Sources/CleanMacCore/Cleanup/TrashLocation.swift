import Foundation

public enum TrashLocation {
    public static func url(home: URL) -> URL {
        home.appendingPathComponent(".Trash", isDirectory: true)
    }

    /// Allocated size of the user's Trash, or nil when it cannot be read (no Full Disk Access).
    public static func size(home: URL) -> Int64? {
        let (size, unreadable) = SizeCalculator.allocatedSize(of: url(home: home))
        return unreadable > 0 && size == 0 ? nil : size
    }
}
