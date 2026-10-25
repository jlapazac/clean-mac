import CleanMacCore
import Foundation
import Observation

@MainActor
@Observable
final class AppsViewModel {
    enum SortOrder: String, CaseIterable, Identifiable {
        case size, name
        var id: String { rawValue }
        var title: String { self == .size ? "Tamaño total" : "Nombre" }
    }

    private(set) var apps: [InstalledApp] = []
    private(set) var isLoading = false
    private(set) var leftoversPending: Set<URL> = []
    var search = ""
    var sortOrder: SortOrder = .size
    var selectedAppID: URL?
    /// Leftovers the user has ticked, per app.
    private(set) var selectedLeftovers: [URL: Set<URL>] = [:]
    var pendingDeletion: [PendingDeletion]?
    private(set) var lastResult: DeletionResult?
    private(set) var message: String?
    private(set) var isDeleting = false

    private let inventory = AppInventory(searchDirectories: SystemServices.applicationDirectories)
    private let finder = LeftoverFinder(
        libraryDirectory: SystemServices.homeDirectory.appendingPathComponent("Library"))
    private let deletionService = SystemServices.makeDeletionService()
    private var loadTask: Task<Void, Never>?

    var visibleApps: [InstalledApp] {
        let filtered = search.isEmpty
            ? apps
            : apps.filter { $0.name.localizedCaseInsensitiveContains(search)
                || ($0.bundleIdentifier?.localizedCaseInsensitiveContains(search) ?? false) }
        switch sortOrder {
        case .name: return filtered
        case .size: return filtered.sorted { $0.totalSize > $1.totalSize }
        }
    }

    var selectedApp: InstalledApp? {
        selectedAppID.flatMap { id in apps.first { $0.id == id } }
    }

    func loadIfNeeded() {
        if apps.isEmpty && !isLoading { reload() }
    }

    func reload() {
        loadTask?.cancel()
        isLoading = true
        message = nil
        let inventory = inventory
        let finder = finder
        loadTask = Task {
            var found = await Task.detached(priority: .userInitiated) {
                await inventory.installedApps()
            }.value
            let running = SystemServices.runningAppPaths()
            let own = SystemServices.ownBundleURL.map(ProtectionPolicy.normalize)
            for index in found.indices {
                let path = ProtectionPolicy.normalize(found[index].url)
                found[index].isRunning = running.contains(path)
                found[index].isSelf = path == own
            }
            apps = found
            isLoading = false
            leftoversPending = Set(found.filter { $0.bundleIdentifier != nil && !$0.isAppleApp }.map(\.id))

            let allIDs = Set(found.compactMap(\.bundleIdentifier))
            await withTaskGroup(of: (URL, [Leftover]).self) { group in
                for app in found where leftoversPending.contains(app.id) {
                    group.addTask {
                        (app.id, await finder.leftovers(for: app, otherBundleIDs: allIDs))
                    }
                }
                for await (id, leftovers) in group {
                    guard !Task.isCancelled else { return }
                    applyLeftovers(leftovers, to: id)
                }
            }
        }
    }

    private func applyLeftovers(_ leftovers: [Leftover], to id: URL) {
        guard let index = apps.firstIndex(where: { $0.id == id }) else { return }
        apps[index].leftovers = leftovers
        selectedLeftovers[id] = Set(leftovers.filter { $0.confidence == .high }.map(\.id))
        leftoversPending.remove(id)
    }

    // MARK: Selection

    func isLeftoverSelected(_ leftover: Leftover, in app: InstalledApp) -> Bool {
        selectedLeftovers[app.id]?.contains(leftover.id) ?? false
    }

    func toggleLeftover(_ leftover: Leftover, in app: InstalledApp) {
        var set = selectedLeftovers[app.id] ?? []
        if set.contains(leftover.id) { set.remove(leftover.id) } else { set.insert(leftover.id) }
        selectedLeftovers[app.id] = set
    }

    func removalSize(for app: InstalledApp) -> Int64 {
        let chosen = selectedLeftovers[app.id] ?? []
        return app.bundleSize + app.leftovers.filter { chosen.contains($0.id) }.reduce(0) { $0 + $1.size }
    }

    // MARK: Uninstall

    func requestUninstall(_ app: InstalledApp) {
        message = nil
        lastResult = nil
        let running = SystemServices.runningAppPaths().contains(ProtectionPolicy.normalize(app.url))
        if let index = apps.firstIndex(where: { $0.id == app.id }) {
            apps[index].isRunning = running
        }
        guard !running else {
            message = "\(app.name) está abierta. Ciérrala y vuelve a intentarlo."
            return
        }
        guard app.canUninstall else {
            message = "\(app.name) no se puede desinstalar."
            return
        }
        let chosen = selectedLeftovers[app.id] ?? []
        pendingDeletion = [PendingDeletion(url: app.url, size: app.bundleSize)]
            + app.leftovers.filter { chosen.contains($0.id) }.map { PendingDeletion(url: $0.url, size: $0.size) }
    }

    func confirmDeletion() {
        guard let pending = pendingDeletion, let appURL = pending.first?.url else { return }
        pendingDeletion = nil
        isDeleting = true
        Task {
            let result = await deletionService.trash(pending.map(\.url))
            lastResult = result
            isDeleting = false
            if result.trashed.contains(appURL) {
                apps.removeAll { $0.id == appURL }
                selectedLeftovers[appURL] = nil
                selectedAppID = nil
            } else if let index = apps.firstIndex(where: { $0.id == appURL }) {
                let trashed = Set(result.trashed)
                apps[index].leftovers.removeAll { trashed.contains($0.id) }
            }
        }
    }
}
