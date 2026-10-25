import Foundation
import Testing
@testable import CleanMacCore

@Suite struct CleanupCatalogTests {
    let sandbox: Sandbox
    let catalog: CleanupCatalog

    init() throws {
        sandbox = try Sandbox()
        catalog = CleanupCatalog(homeDirectory: sandbox.home)
    }

    func category(_ id: String) throws -> CleanupCategory {
        try #require(catalog.categories().first { $0.id == id })
    }

    @Test func providesTheExpectedCategories() {
        #expect(catalog.categories().map(\.id) == ["npm", "userCache", "libraryCaches", "xcodeDerived", "logs", "docker"])
        #expect(catalog.categories().allSatisfy { !$0.detail.isEmpty })
    }

    @Test func pathsAreRelativeToHome() throws {
        let npm = try category("npm")
        #expect(npm.paths.map(\.path) == [
            sandbox.home.appendingPathComponent(".npm/_cacache").path,
            sandbox.home.appendingPathComponent(".npm/_npx").path,
        ])
    }

    @Test func measuresSizeAndExistence() async throws {
        try sandbox.makeFile(".npm/_cacache/content/a", bytes: 40_960)
        try sandbox.makeFile(".npm/_npx/b", bytes: 8_192)
        let measured = await catalog.measure(try category("npm"))
        #expect(measured.exists)
        #expect(measured.size >= 49_152)
        #expect(measured.isCleanable)
    }

    @Test func missingCategoryIsNotFound() async throws {
        let measured = await catalog.measure(try category("xcodeDerived"))
        #expect(!measured.exists)
        #expect(measured.size == 0)
        #expect(!measured.isCleanable)
    }

    @Test func itemsToCleanAreChildrenNeverTheRoot() throws {
        try sandbox.makeFile(".cache/pip/x", bytes: 100)
        try sandbox.makeFile(".cache/.hidden", bytes: 100)
        let root = sandbox.home.appendingPathComponent(".cache")
        let items = catalog.itemsToClean(in: try category("userCache"))
        #expect(Set(items.map(\.lastPathComponent)) == ["pip", ".hidden"])
        #expect(!items.contains { $0.standardizedFileURL == root.standardizedFileURL })
    }

    @Test func dockerIsInformationalOnly() async throws {
        try sandbox.makeFile("Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw", bytes: 400_000)
        let docker = await catalog.measure(try category("docker"))
        #expect(docker.risk == .informational)
        #expect(docker.size >= 400_000)
        #expect(!docker.isCleanable)
        #expect(docker.instructions?.isEmpty == false)
        #expect(catalog.itemsToClean(in: docker).isEmpty)
    }

    @Test func everyItemToCleanPassesTheProtectionPolicy() throws {
        try sandbox.makeFile("Library/Caches/com.example/x", bytes: 100)
        try sandbox.makeFile("Library/Logs/app.log", bytes: 100)
        let policy = ProtectionPolicy(homeDirectory: sandbox.home, ownBundleURL: nil, applicationDirectories: [])
        for category in catalog.categories() {
            for item in catalog.itemsToClean(in: category) {
                #expect(policy.protectionReason(for: item) == nil, "\(item.path)")
            }
        }
    }
}
