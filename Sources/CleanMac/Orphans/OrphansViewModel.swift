import AppKit
import CleanMacCore
import Foundation
import Observation

@MainActor
@Observable
final class OrphansViewModel {
    private(set) var groups: [OrphanGroup] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    var selection: Set<String> = []
    var pendingDeletion: [PendingDeletion]?
    private(set) var lastResult: DeletionResult?
    private(set) var isDeleting = false

    private let deletionService = SystemServices.makeDeletionService()

    var selectedSize: Int64 {
        groups.filter { selection.contains($0.id) }.reduce(0) { $0 + $1.totalSize }
    }

    var totalSize: Int64 { groups.reduce(0) { $0 + $1.totalSize } }

    func loadIfNeeded() {
        if !hasLoaded && !isLoading { reload() }
    }

    func reload() {
        isLoading = true
        selection = []
        let home = SystemServices.homeDirectory
        let directories = SystemServices.applicationDirectories
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        Task {
            let found = await Task.detached(priority: .userInitiated) {
                let apps = await AppInventory(searchDirectories: directories).installedApps()
                let installed = running.union(apps.compactMap(\.bundleIdentifier))
                return await OrphanFinder(libraryDirectory: home.appendingPathComponent("Library"))
                    .orphans(installedBundleIDs: installed, isKnownApp: Self.isKnownToMacOS)
            }.value
            groups = found
            isLoading = false
            hasLoaded = true
        }
    }

    /// True when LaunchServices knows an app with this identifier outside the Trash.
    nonisolated static func isKnownToMacOS(_ identifier: String) -> Bool {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) else {
            return false
        }
        return !url.path.contains("/.Trash/")
    }

    func toggle(_ group: OrphanGroup) {
        if selection.contains(group.id) { selection.remove(group.id) } else { selection.insert(group.id) }
    }

    func selectHighConfidence() {
        selection = Set(groups.filter { $0.confidence == .high }.map(\.id))
    }

    func requestDeletion() {
        let items = groups.filter { selection.contains($0.id) }.flatMap(\.items)
        guard !items.isEmpty else { return }
        lastResult = nil
        pendingDeletion = items.map { PendingDeletion(url: $0.url, size: $0.size) }
    }

    func confirmDeletion() {
        guard let pending = pendingDeletion else { return }
        pendingDeletion = nil
        isDeleting = true
        Task {
            let result = await deletionService.trash(pending.map(\.url))
            lastResult = result
            let trashed = Set(result.trashed)
            groups = groups.compactMap { group in
                let remaining = group.items.filter { !trashed.contains($0.url) }
                if remaining.isEmpty { return nil }
                return OrphanGroup(id: group.id, confidence: group.confidence, items: remaining,
                                   lastModified: group.lastModified, note: group.note)
            }
            selection = selection.filter { id in groups.contains { $0.id == id } }
            isDeleting = false
            NotificationCenter.default.post(name: .cleanMacTrashChanged, object: nil)
        }
    }
}
