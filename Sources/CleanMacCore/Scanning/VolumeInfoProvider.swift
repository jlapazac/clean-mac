import Foundation

public enum VolumeInfoProvider {
    /// Capacity of the startup volume (the APFS container shared by System and Data).
    public static func startupVolume() throws -> VolumeInfo {
        try volume(at: URL(fileURLWithPath: "/"))
    }

    public static func volume(at url: URL) throws -> VolumeInfo {
        let values = try url.resourceValues(forKeys: [
            .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
        ])
        let total = Int64(values.volumeTotalCapacity ?? 0)
        let available = values.volumeAvailableCapacityForImportantUsage
            ?? Int64(values.volumeAvailableCapacity ?? 0)
        return VolumeInfo(totalCapacity: total, availableCapacity: available)
    }
}
