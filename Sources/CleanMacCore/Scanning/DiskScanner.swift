import Foundation

/// Builds a size tree of one or more folders. Only children at or above `minimumItemSize`
/// are kept as nodes, which keeps the tree small even for millions of files. The first two
/// levels are scanned concurrently; the scan honours task cancellation.
public struct DiskScanner: Sendable {
    public let minimumItemSize: Int64
    public let excludedPaths: [URL]

    /// Folders under the home that are not walked: enumerating cloud-backed files can
    /// trigger downloads.
    public static func defaultExclusions(home: URL) -> [URL] {
        [
            home.appendingPathComponent("Library/CloudStorage"),
            home.appendingPathComponent("Library/Mobile Documents"),
            home.appendingPathComponent(".Trash"),
        ]
    }

    /// Depth up to which children are scanned in parallel.
    static let parallelDepth = 2

    private let excludedSet: Set<String>

    public init(minimumItemSize: Int64 = 1_000_000, excludedPaths: [URL] = []) {
        self.minimumItemSize = minimumItemSize
        self.excludedPaths = excludedPaths
        excludedSet = Set(excludedPaths.map(ProtectionPolicy.normalize))
    }

    public func scan(
        roots: [URL],
        progress: @escaping @Sendable (ScanProgress) -> Void
    ) async throws -> ScanSummary {
        try Task.checkCancellation()
        let start = ContinuousClock.now
        let counter = ScanCounter(report: progress)
        let nodes = try await withThrowingTaskGroup(of: (Int, DiskItem).self) { group in
            for (index, root) in roots.enumerated() {
                group.addTask { (index, try await node(at: root, depth: 0, counter: counter)) }
            }
            var result = [DiskItem?](repeating: nil, count: roots.count)
            for try await (index, item) in group { result[index] = item }
            return result.compactMap { $0 }
        }
        counter.flush()
        let snapshot = counter.snapshot()
        return ScanSummary(
            roots: nodes,
            unreadableCount: snapshot.unreadable,
            fileCount: snapshot.progress.filesScanned,
            duration: ContinuousClock.now - start)
    }

    public func scanItem(at url: URL) async throws -> DiskItem {
        try await node(at: url, depth: 0, counter: ScanCounter(report: { _ in }))
    }

    // MARK: - Tree building

    private static let keys: Set<URLResourceKey> = [
        .isDirectoryKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
    ]

    private func node(at url: URL, depth: Int, counter: ScanCounter) async throws -> DiskItem {
        try Task.checkCancellation()
        guard let values = try? url.resourceValues(forKeys: Self.keys) else {
            return DiskItem(url: url, size: 0, isDirectory: false, isSkipped: true)
        }
        if values.isDirectory != true || values.isSymbolicLink == true {
            let size = SizeCalculator.allocatedSize(values)
            counter.addFile(size: size, path: url.path)
            return DiskItem(url: url, size: size, isDirectory: false)
        }
        if isExcluded(url) {
            return DiskItem(url: url, size: 0, isDirectory: true, isSkipped: true)
        }
        guard let children = listChildren(of: url, counter: counter) else {
            return DiskItem(url: url, size: 0, isDirectory: true, isSkipped: true)
        }

        var childNodes: [DiskItem] = []
        if depth < Self.parallelDepth {
            childNodes = try await withThrowingTaskGroup(of: DiskItem.self) { group in
                for child in children {
                    group.addTask { try await node(at: child, depth: depth + 1, counter: counter) }
                }
                var collected: [DiskItem] = []
                for try await item in group { collected.append(item) }
                return collected
            }
        } else {
            childNodes.reserveCapacity(children.count)
            for child in children {
                childNodes.append(try await node(at: child, depth: depth + 1, counter: counter))
            }
        }
        return fold(url: url, children: childNodes)
    }

    private func fold(url: URL, children: [DiskItem]) -> DiskItem {
        var kept: [DiskItem] = []
        var smallSize: Int64 = 0
        var smallCount = 0
        var total: Int64 = 0
        for child in children {
            // Vanished files are dropped; skipped folders are kept so the user sees they were
            // not analysed.
            if child.isSkipped && !child.isDirectory { continue }
            total += child.size
            if child.size >= minimumItemSize || child.isSkipped {
                kept.append(child)
            } else {
                smallSize += child.size
                smallCount += 1
            }
        }
        kept.sort { $0.size != $1.size ? $0.size > $1.size : $0.name < $1.name }
        return DiskItem(
            url: url, size: total, isDirectory: true, children: kept,
            smallItemsSize: smallSize, smallItemsCount: smallCount)
    }

    private func listChildren(of url: URL, counter: ScanCounter) -> [URL]? {
        do {
            return try FileManager.default.contentsOfDirectory(
                at: url, includingPropertiesForKeys: Array(Self.keys), options: [])
        } catch {
            counter.addUnreadable()
            return nil
        }
    }

    private func isExcluded(_ url: URL) -> Bool {
        !excludedSet.isEmpty && excludedSet.contains(ProtectionPolicy.normalize(url))
    }
}

/// Thread-safe counters with throttled progress reporting (at most every 100 ms).
final class ScanCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var progress = ScanProgress()
    private var unreadable = 0
    private var lastReport = ContinuousClock.now
    private let report: @Sendable (ScanProgress) -> Void

    init(report: @escaping @Sendable (ScanProgress) -> Void) {
        self.report = report
    }

    func addFile(size: Int64, path: String) {
        var toReport: ScanProgress?
        lock.withLock {
            progress.filesScanned += 1
            progress.bytesScanned += size
            let now = ContinuousClock.now
            if now - lastReport >= .milliseconds(100) {
                lastReport = now
                progress.currentPath = path
                toReport = progress
            }
        }
        if let toReport { report(toReport) }
    }

    func addUnreadable() {
        lock.withLock { unreadable += 1 }
    }

    func flush() {
        report(lock.withLock { progress })
    }

    func snapshot() -> (progress: ScanProgress, unreadable: Int) {
        lock.withLock { (progress, unreadable) }
    }
}
