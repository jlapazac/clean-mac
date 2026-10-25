import Foundation
import Testing
@testable import CleanMacCore

/// Records calls instead of touching the real Trash.
final class RecordingTrasher: Trasher, @unchecked Sendable {
    private let lock = NSLock()
    private var _calls: [URL] = []
    var failing: Set<URL> = []

    var calls: [URL] { lock.withLock { _calls } }

    func trashItem(at url: URL) async throws {
        lock.withLock { _calls.append(url) }
        if failing.contains(url) {
            throw CocoaError(.fileWriteNoPermission)
        }
    }
}

@Suite struct DeletionServiceTests {
    let sandbox: Sandbox
    let trasher = RecordingTrasher()
    let service: DeletionService

    init() throws {
        sandbox = try Sandbox()
        let policy = ProtectionPolicy(
            homeDirectory: sandbox.home, ownBundleURL: nil,
            applicationDirectories: [sandbox.applications])
        service = DeletionService(policy: policy, trasher: trasher)
    }

    @Test func neverCallsTrasherForProtectedPaths() async throws {
        try sandbox.makeDirectory("Library/Caches")
        let result = await service.trash([
            sandbox.home,
            sandbox.library,
            sandbox.library.appendingPathComponent("Caches"),
            URL(fileURLWithPath: "/System"),
        ])
        #expect(trasher.calls.isEmpty)
        #expect(result.trashed.isEmpty)
        #expect(result.failures.count == 4)
    }

    @Test func trashesAllowedItemsAndReportsBytes() async throws {
        let a = try sandbox.makeFile("Library/Caches/com.a/data.bin", bytes: 40_960)
            .deletingLastPathComponent()
        let b = try sandbox.makeFile(".npm/_cacache/blob", bytes: 8_192)
        let result = await service.trash([a, b])
        #expect(trasher.calls == [a, b])
        #expect(result.trashed == [a, b])
        #expect(result.failures.isEmpty)
        #expect(result.bytesFreed >= 40_960 + 8_192)
    }

    @Test func continuesAfterAFailureAndReportsIt() async throws {
        let a = try sandbox.makeFile("one.bin", bytes: 4_096)
        let b = try sandbox.makeFile("two.bin", bytes: 4_096)
        trasher.failing = [a]
        let result = await service.trash([a, b])
        #expect(trasher.calls == [a, b])
        #expect(result.trashed == [b])
        #expect(result.failures.map(\.url) == [a])
        #expect(result.bytesFreed >= 4_096 && result.bytesFreed < 8_192 + 4_096)
    }

    @Test func permissionErrorsExplainWhatToDo() async throws {
        let a = try sandbox.makeFile("locked.bin", bytes: 4_096)
        trasher.failing = [a]
        let result = await service.trash([a])
        #expect(result.failures.first?.reason.contains("Gestión de apps") == true)
    }

    @Test func missingItemsAreReportedNotTrashed() async {
        let ghost = sandbox.home.appendingPathComponent("ghost.txt")
        let result = await service.trash([ghost])
        #expect(trasher.calls.isEmpty)
        #expect(result.failures.count == 1)
    }

    @Test func nestedSelectionIsTrashedOnce() async throws {
        let parent = try sandbox.makeDirectory("Projects/old")
        let child = try sandbox.makeFile("Projects/old/file.bin", bytes: 4_096)
        let result = await service.trash([child, parent])
        #expect(trasher.calls == [parent])
        #expect(result.trashed == [parent])
    }

    @Test func realTrasherMovesItemToTrash() async throws {
        // Uses the real Trash once to make sure the default implementation works; the item is
        // a throwaway file created by the test.
        let file = try sandbox.makeFile("trash-me-\(UUID().uuidString).txt", bytes: 16)
        let policy = ProtectionPolicy(homeDirectory: sandbox.home, ownBundleURL: nil,
                                      applicationDirectories: [])
        let real = DeletionService(policy: policy)
        let result = await real.trash([file])
        #expect(result.trashed == [file])
        #expect(!FileManager.default.fileExists(atPath: file.path))
        // Clean up the test's own file from the Trash.
        if let trash = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first {
            try? FileManager.default.removeItem(at: trash.appendingPathComponent(file.lastPathComponent))
        }
    }
}
