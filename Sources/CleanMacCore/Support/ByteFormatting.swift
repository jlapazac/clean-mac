import Foundation

public enum ByteFormatting {
    /// Human-readable size using decimal units, as Finder does (e.g. "35,2 GB").
    public static func string(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
