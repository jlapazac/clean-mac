import Foundation
import Testing
@testable import CleanMacCore

@Suite struct DiskScannerTests {
    let sandbox: Sandbox
    let scanner = DiskScanner(minimumItemSize: 100_000)

    init() throws { sandbox = try Sandbox() }

    @Test func keepsLargeChildrenAndFoldsSmallOnes() async throws {
        try sandbox.makeFile("big.bin", bytes: 300_000)
        try sandbox.makeFile("medium.bin", bytes: 150_000)
        try sandbox.makeFile("tiny1.txt", bytes: 4_096)
        try sandbox.makeFile("tiny2.txt", bytes: 4_096)

        let item = try await scanner.scanItem(at: sandbox.home)
        #expect(item.children.map(\.name) == ["big.bin", "medium.bin"])
        #expect(item.smallItemsCount == 2)
        #expect(item.smallItemsSize >= 8_192)
    }

    @Test func sizeIsSumOfChildrenAndSmallItems() async throws {
        try sandbox.makeFile("a/one.bin", bytes: 200_000)
        try sandbox.makeFile("a/b/two.bin", bytes: 250_000)
        try sandbox.makeFile("a/small.txt", bytes: 1_000)

        let item = try await scanner.scanItem(at: sandbox.home.appendingPathComponent("a"))
        let childSum = item.children.reduce(0) { $0 + $1.size }
        #expect(item.size == childSum + item.smallItemsSize)
        #expect(item.size == SizeCalculator.allocatedSize(of: item.url).size)
    }

    @Test func childrenAreSortedDescendingAndNested() async throws {
        try sandbox.makeFile("x/s.bin", bytes: 120_000)
        try sandbox.makeFile("y/l.bin", bytes: 500_000)
        try sandbox.makeFile("y/deep/m.bin", bytes: 200_000)

        let item = try await scanner.scanItem(at: sandbox.home)
        #expect(item.children.map(\.name) == ["y", "x"])
        let y = try #require(item.children.first)
        #expect(y.children.map(\.name) == ["l.bin", "deep"])
        #expect(y.isDirectory)
    }

    @Test func excludedPathsAreSkipped() async throws {
        try sandbox.makeFile("Library/CloudStorage/OneDrive/huge.bin", bytes: 400_000)
        try sandbox.makeFile("Library/Other/real.bin", bytes: 200_000)
        let cloud = sandbox.home.appendingPathComponent("Library/CloudStorage")
        let scanner = DiskScanner(minimumItemSize: 100_000, excludedPaths: [cloud])

        let summary = try await scanner.scan(roots: [sandbox.home]) { _ in }
        let library = try #require(summary.roots.first?.children.first { $0.name == "Library" })
        #expect(library.children.map(\.name) == ["Other", "CloudStorage"])
        let skipped = try #require(library.children.last)
        #expect(skipped.isSkipped && skipped.size == 0)
        #expect(library.size < 400_000)
    }

    @Test func unreadableFoldersAreCountedNotFatal() async throws {
        let locked = try sandbox.makeDirectory("locked")
        try sandbox.makeFile("locked/f.bin", bytes: 4_096)
        try sandbox.makeFile("open.bin", bytes: 200_000)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path) }

        let summary = try await scanner.scan(roots: [sandbox.home]) { _ in }
        #expect(summary.unreadableCount >= 1)
        #expect(summary.roots.first?.children.first?.name == "open.bin")
    }

    @Test func reportsProgressAndFileCount() async throws {
        for i in 0..<20 { try sandbox.makeFile("many/f\(i).txt", bytes: 100) }
        let box = ProgressBox()
        let summary = try await scanner.scan(roots: [sandbox.home]) { box.set($0) }
        #expect(summary.fileCount == 20)
        #expect(box.last?.filesScanned == 20)
    }

    @Test func cancellationStopsTheScan() async throws {
        for i in 0..<200 { try sandbox.makeFile("d\(i % 10)/f\(i).txt", bytes: 100) }
        let home = sandbox.home
        let scanner = self.scanner
        let task = Task { try await scanner.scan(roots: [home]) { _ in } }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test func filesVanishingDuringScanAreIgnored() async throws {
        // A dangling symlink behaves like a file that disappeared between listing and reading.
        try FileManager.default.createSymbolicLink(
            at: sandbox.home.appendingPathComponent("dangling"),
            withDestinationURL: sandbox.home.appendingPathComponent("gone"))
        try sandbox.makeFile("kept.bin", bytes: 200_000)
        let item = try await scanner.scanItem(at: sandbox.home)
        #expect(item.children.map(\.name) == ["kept.bin"])
    }
}

final class ProgressBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: ScanProgress?
    var last: ScanProgress? { lock.withLock { value } }
    func set(_ p: ScanProgress) { lock.withLock { value = p } }
}
