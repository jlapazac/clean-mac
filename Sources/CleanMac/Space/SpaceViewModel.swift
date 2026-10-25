import CleanMacCore
import Foundation
import Observation

@MainActor
@Observable
final class SpaceViewModel {
    enum State: Equatable {
        case idle, scanning, done, cancelled
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var volume: VolumeInfo?
    private(set) var progress = ScanProgress()
    private(set) var summary: ScanSummary?
    /// Drill-down path; empty means the list of roots.
    private(set) var path: [URL] = []
    var selection: Set<URL> = []
    var pendingDeletion: [PendingDeletion]?
    private(set) var lastResult: DeletionResult?
    private(set) var isDeleting = false

    let policy = SystemServices.makePolicy()
    private let deletionService = SystemServices.makeDeletionService()
    private let scanner: DiskScanner
    private let roots: [URL]
    private var scanTask: Task<Void, Never>?

    init() {
        let home = SystemServices.homeDirectory
        // Home and Applications can be cleaned; the system folders are listed read-only (the
        // protection policy blocks them) so the user sees where the rest of the disk goes.
        roots = [home.path, "/Applications", "/Library", "/opt", "/usr/local", "/private/var"]
            .filter { FileManager.default.fileExists(atPath: $0) }
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
        scanner = DiskScanner(excludedPaths: DiskScanner.defaultExclusions(home: home))
        refreshVolume()
    }

    // MARK: Scanning

    func startScan() {
        scanTask?.cancel()
        state = .scanning
        progress = ScanProgress()
        selection = []
        lastResult = nil
        let scanner = scanner
        let roots = roots
        scanTask = Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try await scanner.scan(roots: roots) { p in
                        Task { @MainActor [weak self] in self?.progress = p }
                    }
                }.value
                try Task.checkCancellation()
                summary = result
                path = path.filter { find($0) != nil }
                state = .done
            } catch is CancellationError {
                state = summary == nil ? .cancelled : .done
            } catch {
                state = .failed(error.localizedDescription)
            }
            refreshVolume()
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        state = summary == nil ? .cancelled : .done
    }

    func refreshVolume() {
        volume = try? VolumeInfoProvider.startupVolume()
    }

    /// Used space that the scan could not see: the macOS system volume, protected data, local
    /// snapshots and purgeable space.
    var unaccountedSize: Int64? {
        guard let summary, let volume else { return nil }
        let scanned = summary.roots.reduce(0) { $0 + $1.size }
        return max(0, volume.usedCapacity - scanned)
    }

    var scannedSize: Int64 {
        summary?.roots.reduce(0) { $0 + $1.size } ?? 0
    }

    // MARK: Navigation

    var currentNode: DiskItem? { path.last.flatMap(find) }

    /// Items listed at the current level.
    var currentItems: [DiskItem] {
        if let node = currentNode { return node.children }
        return summary?.roots ?? []
    }

    /// Total used for the relative size bars.
    var currentTotal: Int64 {
        currentNode?.size ?? currentItems.reduce(0) { $0 + $1.size }
    }

    var breadcrumbs: [(url: URL, name: String)] {
        path.map { ($0, find($0)?.name ?? $0.lastPathComponent) }
    }

    func open(_ item: DiskItem) {
        guard item.isDirectory, !item.isSkipped else { return }
        path.append(item.url)
        selection = []
    }

    /// Goes back to `index` in the breadcrumb (-1 = roots).
    func goBack(to index: Int) {
        path = Array(path.prefix(index + 1))
        selection = []
    }

    // MARK: Selection & deletion

    func isProtected(_ item: DiskItem) -> Bool {
        policy.protectionReason(for: item.url) != nil
    }

    func protectionReason(_ item: DiskItem) -> String? {
        policy.protectionReason(for: item.url)
    }

    func toggle(_ item: DiskItem) {
        guard !isProtected(item) else { return }
        if selection.contains(item.url) { selection.remove(item.url) } else { selection.insert(item.url) }
    }

    var selectedSize: Int64 {
        currentItems.filter { selection.contains($0.url) }.reduce(0) { $0 + $1.size }
    }

    func requestDeletion() {
        let items = currentItems.filter { selection.contains($0.url) && !isProtected($0) }
        guard !items.isEmpty else { return }
        pendingDeletion = items.map { PendingDeletion(url: $0.url, size: $0.size) }
    }

    func confirmDeletion() {
        guard let pending = pendingDeletion else { return }
        pendingDeletion = nil
        isDeleting = true
        let urls = pending.map(\.url)
        let parent = path.last
        Task {
            let result = await deletionService.trash(urls)
            lastResult = result
            selection = []
            if let parent { await rescan(parent) }
            isDeleting = false
            refreshVolume()
        }
    }

    /// Re-scans one folder after a deletion and patches it (and its ancestors' sizes) into the tree.
    private func rescan(_ url: URL) async {
        let scanner = scanner
        guard var summary,
              let fresh = try? await Task.detached(priority: .userInitiated, operation: {
                  try await scanner.scanItem(at: url)
              }).value
        else { return }
        summary.roots = summary.roots.map { Self.replacing(url, with: fresh, in: $0).item }
        self.summary = summary
    }

    // MARK: Tree helpers

    private func find(_ url: URL) -> DiskItem? {
        for root in summary?.roots ?? [] {
            if let hit = Self.find(url, in: root) { return hit }
        }
        return nil
    }

    private static func find(_ url: URL, in item: DiskItem) -> DiskItem? {
        if item.url == url { return item }
        let target = url.path
        guard target.hasPrefix(item.url.path.hasSuffix("/") ? item.url.path : item.url.path + "/") else {
            return nil
        }
        for child in item.children {
            if let hit = find(url, in: child) { return hit }
        }
        return nil
    }

    /// Returns the tree with `url` replaced and the size difference applied to every ancestor.
    private static func replacing(_ url: URL, with fresh: DiskItem, in item: DiskItem)
        -> (item: DiskItem, delta: Int64, found: Bool)
    {
        if item.url == url { return (fresh, fresh.size - item.size, true) }
        var copy = item
        for index in copy.children.indices {
            let (child, delta, found) = replacing(url, with: fresh, in: copy.children[index])
            if found {
                copy.children[index] = child
                copy.size += delta
                copy.children.sort { $0.size > $1.size }
                return (copy, delta, true)
            }
        }
        return (item, 0, false)
    }
}
