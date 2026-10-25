import Foundation

/// Builds a size tree of one or more folders. Only children at or above `minimumItemSize`
/// are kept as nodes, which keeps the tree small even for millions of files. The first levels
/// are scanned concurrently; the scan honours task cancellation.
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
        let nodes = try await withThrowingTaskGroup(of: (Int, DiskItem?).self) { group in
            for (index, root) in roots.enumerated() {
                let path = ProtectionPolicy.normalize(root)
                group.addTask { (index, try await node(at: path, depth: 0, counter: counter)) }
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
        let path = ProtectionPolicy.normalize(url)
        let counter = ScanCounter(report: { _ in })
        return try await node(at: path, depth: 0, counter: counter)
            ?? DiskItem(url: URL(fileURLWithPath: path), size: 0, isDirectory: false, isSkipped: true)
    }

    // MARK: - Tree building

    /// Node for `path`, or nil if it vanished.
    private func node(at path: String, depth: Int, counter: ScanCounter) async throws -> DiskItem? {
        try Task.checkCancellation()
        guard let info = POSIXDirectory.stat(path: path) else { return nil }
        guard info.kind == .directory else {
            counter.addFile(size: info.allocated, path: path)
            return item(path, size: info.allocated, isDirectory: false)
        }
        guard depth < Self.parallelDepth else {
            return try directoryNode(at: path, counter: counter)
        }
        guard let entries = try listing(of: path, counter: counter) else {
            return item(path, size: 0, isDirectory: true, skipped: true)
        }

        var builder = FolderBuilder(minimumItemSize: minimumItemSize)
        let folders = entries.filter { $0.kind == .directory }
        for entry in entries where entry.kind != .directory {
            let child = POSIXDirectory.join(path, entry.name)
            counter.addFile(size: entry.allocated, path: child)
            builder.add(file: child, size: entry.allocated)
        }
        let children = try await withThrowingTaskGroup(of: DiskItem?.self) { group in
            for entry in folders {
                let child = POSIXDirectory.join(path, entry.name)
                group.addTask { try await node(at: child, depth: depth + 1, counter: counter) }
            }
            var collected: [DiskItem] = []
            for try await child in group { if let child { collected.append(child) } }
            return collected
        }
        children.forEach { builder.add($0) }
        return builder.build(url: URL(fileURLWithPath: path, isDirectory: true))
    }

    /// Synchronous recursion used below the parallel levels.
    private func directoryNode(at path: String, counter: ScanCounter) throws -> DiskItem {
        guard let entries = try listing(of: path, counter: counter) else {
            return item(path, size: 0, isDirectory: true, skipped: true)
        }
        var builder = FolderBuilder(minimumItemSize: minimumItemSize)
        for entry in entries {
            let child = POSIXDirectory.join(path, entry.name)
            if entry.kind == .directory {
                builder.add(try directoryNode(at: child, counter: counter))
            } else {
                counter.addFile(size: entry.allocated, path: child)
                builder.add(file: child, size: entry.allocated)
            }
        }
        return builder.build(url: URL(fileURLWithPath: path, isDirectory: true))
    }

    /// Entries of a folder, or nil when it is excluded or unreadable.
    private func listing(of path: String, counter: ScanCounter) throws -> [POSIXDirectory.Entry]? {
        try Task.checkCancellation()
        if excludedSet.contains(path) { return nil }
        switch POSIXDirectory.entries(of: path) {
        case .success(let entries):
            return entries
        case .failure(let error):
            if error == .unreadable { counter.addUnreadable() }
            return nil
        }
    }

    private func item(_ path: String, size: Int64, isDirectory: Bool, skipped: Bool = false) -> DiskItem {
        DiskItem(url: URL(fileURLWithPath: path, isDirectory: isDirectory),
                 name: (path as NSString).lastPathComponent,
                 size: size, isDirectory: isDirectory, isSkipped: skipped)
    }
}

/// Accumulates a folder's children, keeping large ones as nodes and folding small ones.
private struct FolderBuilder {
    let minimumItemSize: Int64
    var kept: [DiskItem] = []
    var smallSize: Int64 = 0
    var smallCount = 0
    var total: Int64 = 0

    init(minimumItemSize: Int64) {
        self.minimumItemSize = minimumItemSize
    }

    /// Files only become nodes when large, so small files never allocate a URL.
    mutating func add(file path: String, size: Int64) {
        total += size
        if size >= minimumItemSize {
            kept.append(DiskItem(url: URL(fileURLWithPath: path, isDirectory: false),
                                 name: (path as NSString).lastPathComponent,
                                 size: size, isDirectory: false))
        } else {
            smallSize += size
            smallCount += 1
        }
    }

    /// Skipped folders are kept regardless of size so the user sees they were not analysed.
    mutating func add(_ child: DiskItem) {
        total += child.size
        if child.size >= minimumItemSize || child.isSkipped {
            kept.append(child)
        } else {
            smallSize += child.size
            smallCount += 1
        }
    }

    func build(url: URL) -> DiskItem {
        let sorted = kept.sorted { $0.size != $1.size ? $0.size > $1.size : $0.name < $1.name }
        return DiskItem(url: url, name: url.lastPathComponent, size: total, isDirectory: true,
                        children: sorted, smallItemsSize: smallSize, smallItemsCount: smallCount)
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
