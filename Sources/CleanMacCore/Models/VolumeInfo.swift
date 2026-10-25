import Foundation

/// Capacity figures for a volume, in bytes.
public struct VolumeInfo: Sendable, Equatable {
    public let totalCapacity: Int64
    public let availableCapacity: Int64

    public var usedCapacity: Int64 { max(0, totalCapacity - availableCapacity) }

    public var usedFraction: Double {
        totalCapacity > 0 ? Double(usedCapacity) / Double(totalCapacity) : 0
    }

    public init(totalCapacity: Int64, availableCapacity: Int64) {
        self.totalCapacity = totalCapacity
        self.availableCapacity = availableCapacity
    }
}
