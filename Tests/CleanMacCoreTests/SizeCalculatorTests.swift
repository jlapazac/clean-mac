import Foundation
import Testing
@testable import CleanMacCore

@Suite struct SizeCalculatorTests {
    let sandbox: Sandbox

    init() throws { sandbox = try Sandbox() }

    @Test func sumsFilesRecursively() throws {
        try sandbox.makeFile("d/a.bin", bytes: 40_960)
        try sandbox.makeFile("d/sub/b.bin", bytes: 81_920)
        let (size, unreadable) = SizeCalculator.allocatedSize(of: sandbox.home.appendingPathComponent("d"))
        #expect(size >= 122_880)
        #expect(size < 122_880 + 64_000)
        #expect(unreadable == 0)
    }

    @Test func sizeOfSingleFile() throws {
        let f = try sandbox.makeFile("f.bin", bytes: 10_000)
        let (size, _) = SizeCalculator.allocatedSize(of: f)
        #expect(size >= 10_000 && size <= 16_384)
    }

    @Test func doesNotFollowSymlinks() throws {
        let target = try sandbox.makeFile("big/blob.bin", bytes: 400_000)
        let dir = try sandbox.makeDirectory("links")
        try FileManager.default.createSymbolicLink(
            at: dir.appendingPathComponent("toBig"), withDestinationURL: target.deletingLastPathComponent())
        let (size, _) = SizeCalculator.allocatedSize(of: dir)
        #expect(size < 100_000)
    }

    @Test func countsUnreadableFolders() throws {
        let locked = try sandbox.makeDirectory("x/locked")
        try sandbox.makeFile("x/locked/secret.bin", bytes: 4_096)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path) }
        let (_, unreadable) = SizeCalculator.allocatedSize(of: sandbox.home.appendingPathComponent("x"))
        #expect(unreadable >= 1)
    }

    @Test func missingPathIsZero() {
        let (size, _) = SizeCalculator.allocatedSize(of: sandbox.home.appendingPathComponent("nope"))
        #expect(size == 0)
    }
}
