import CleanMacCore
import Foundation
import Observation

@MainActor
@Observable
final class CleanupViewModel {
    private(set) var categories: [CleanupCategory] = []
    private(set) var measuring: Set<String> = []
    var selection: Set<String> = []
    var pendingDeletion: [PendingDeletion]?
    private(set) var isPreparing = false
    private(set) var isDeleting = false
    private(set) var lastResult: DeletionResult?

    private let catalog = CleanupCatalog(homeDirectory: SystemServices.homeDirectory)
    private let deletionService = SystemServices.makeDeletionService()

    var selectedSize: Int64 {
        categories.filter { selection.contains($0.id) }.reduce(0) { $0 + $1.size }
    }

    var cleanableTotal: Int64 {
        categories.filter(\.isCleanable).reduce(0) { $0 + $1.size }
    }

    func loadIfNeeded() {
        if categories.isEmpty { measureAll() }
    }

    func measureAll() {
        if categories.isEmpty { categories = catalog.categories() }
        measuring = Set(categories.map(\.id))
        let catalog = catalog
        let snapshot = categories
        Task {
            await withTaskGroup(of: CleanupCategory.self) { group in
                for category in snapshot {
                    group.addTask { await catalog.measure(category) }
                }
                for await measured in group {
                    if let index = categories.firstIndex(where: { $0.id == measured.id }) {
                        categories[index] = measured
                    }
                    measuring.remove(measured.id)
                    if !measured.isCleanable { selection.remove(measured.id) }
                }
            }
        }
    }

    func toggle(_ category: CleanupCategory) {
        guard category.isCleanable else { return }
        if selection.contains(category.id) { selection.remove(category.id) } else { selection.insert(category.id) }
    }

    func requestCleanup() {
        let chosen = categories.filter { selection.contains($0.id) && $0.isCleanable }
        guard !chosen.isEmpty else { return }
        isPreparing = true
        lastResult = nil
        let catalog = catalog
        Task {
            let items = await Task.detached(priority: .userInitiated) {
                chosen.flatMap { catalog.itemsToClean(in: $0) }.map {
                    PendingDeletion(url: $0, size: SizeCalculator.allocatedSize(of: $0).size)
                }.sorted { $0.size > $1.size }
            }.value
            isPreparing = false
            pendingDeletion = items
        }
    }

    func confirmDeletion() {
        guard let pending = pendingDeletion else { return }
        pendingDeletion = nil
        isDeleting = true
        Task {
            lastResult = await deletionService.trash(pending.map(\.url))
            NotificationCenter.default.post(name: .cleanMacTrashChanged, object: nil)
            isDeleting = false
            selection = []
            measureAll()
        }
    }
}
